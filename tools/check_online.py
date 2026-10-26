#!/usr/bin/env python3
"""
Check that online play really works, end to end.

This starts the little Cloudflare room server (the Worker + Durable Object in `online/`)
on a free local port, then runs `game/tests/online_smoke.tscn`. That test uses the real
game code to make a room, opens the real online world, connects a second player over a
WebSocket, and checks that their cat appears and moves.

Usage:
    python3 tools/check_online.py                 # start a worker, run the test, stop it
    python3 tools/check_online.py --keep          # leave the worker running afterwards
    python3 tools/check_online.py --server http://127.0.0.1:8787
                                                  # use a worker that is already running
    python3 tools/check_online.py --port 8787     # choose the local port yourself
    python3 tools/check_online.py --verbose       # print all of Godot's output

Exit code 0 = online play works, 1 = the test failed, 2 = could not start Godot or Wrangler.
"""

import argparse
import os
import shutil
import signal
import socket
import subprocess
import sys
import tempfile
import time
import urllib.error
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
GAME_DIR = ROOT / "game"
ONLINE_DIR = ROOT / "online"
SCENE = "res://tests/online_smoke.tscn"
TMP_ROOT = Path("/tmp/opencode") if Path("/tmp/opencode").is_dir() else Path(tempfile.gettempdir())


def find_godot():
    candidates = [os.environ.get("GODOT"), shutil.which("godot"), shutil.which("godot4"),
                  "/Applications/Godot.app/Contents/MacOS/Godot",
                  str(Path.home() / "Applications/Godot.app/Contents/MacOS/Godot")]
    for c in candidates:
        if c and Path(c).exists():
            return c
    return None


def find_wrangler():
    if os.environ.get("WRANGLER"):
        return [os.environ["WRANGLER"]]
    binary = shutil.which("wrangler")
    if binary:
        return [binary]
    npx = shutil.which("npx")
    if npx:
        return [npx, "--yes", "wrangler"]
    return None


def free_port():
    with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as sock:
        sock.bind(("127.0.0.1", 0))
        return sock.getsockname()[1]


def healthy(server, timeout=1.0):
    try:
        with urllib.request.urlopen(server + "/health", timeout=timeout) as answer:
            return b"ok" in answer.read()
    except (urllib.error.URLError, OSError):
        return False


def wait_for_server(server, process, seconds=45.0):
    deadline = time.time() + seconds
    while time.time() < deadline:
        if process.poll() is not None:
            return False
        if healthy(server):
            return True
        time.sleep(0.25)
    return False


def stop(process):
    if process is None or process.poll() is not None:
        return
    try:
        os.killpg(os.getpgid(process.pid), signal.SIGTERM)
    except (ProcessLookupError, PermissionError):
        return
    try:
        process.wait(timeout=10)
    except subprocess.TimeoutExpired:
        try:
            os.killpg(os.getpgid(process.pid), signal.SIGKILL)
        except ProcessLookupError:
            pass


def tail(path, lines=40):
    try:
        text = Path(path).read_text(errors="replace").splitlines()
    except OSError:
        return ""
    return "\n".join(text[-lines:])


def main():
    parser = argparse.ArgumentParser(description="Check that online play works end to end")
    parser.add_argument("--server", help="Use a room server that is already running")
    parser.add_argument("--port", type=int, default=0, help="Local port for the worker (default: any free port)")
    parser.add_argument("--keep", action="store_true", help="Leave the worker running when the check finishes")
    parser.add_argument("--seconds", type=float, default=45.0, help="How long to allow the test to run (default: 45)")
    parser.add_argument("--verbose", action="store_true", help="Print all of Godot's output")
    args = parser.parse_args()

    godot = find_godot()
    if not godot:
        print("Could not find Godot. Install it, or set the GODOT environment variable to its path.")
        return 2
    if not (GAME_DIR / "project.godot").exists():
        print(f"No Godot project found at {GAME_DIR}")
        return 2

    started_worker = False
    worker = None
    server = (args.server or "").rstrip("/")
    log_path = TMP_ROOT / "check_online_worker.log"

    if server:
        if not healthy(server):
            print(f"No room server is answering at {server}. Start one with `cd online && wrangler dev`, or leave --server off.")
            return 2
        print(f"Using the room server already running at {server}")
    else:
        if not (ONLINE_DIR / "wrangler.jsonc").exists():
            print(f"No room server found in {ONLINE_DIR}")
            return 2
        wrangler = find_wrangler()
        if not wrangler:
            print("Could not find Wrangler. Install it with `npm install -g wrangler`, or set the WRANGLER variable.")
            return 2

        port = args.port or free_port()
        server = f"http://127.0.0.1:{port}"
        command = wrangler + ["dev", "--port", str(port), "--ip", "127.0.0.1"]
        print(f"Starting the room server at {server} (log: {log_path})")
        env = dict(os.environ, WRANGLER_SEND_METRICS="false", CI="1")
        log = open(log_path, "w")
        try:
            worker = subprocess.Popen(command, cwd=ONLINE_DIR, stdout=log, stderr=subprocess.STDOUT,
                                      env=env, start_new_session=True)
        except OSError as error:
            print(f"Could not start Wrangler: {error}")
            return 2
        started_worker = True

        if not wait_for_server(server, worker):
            print("The room server did not start in time.")
            print(tail(log_path))
            stop(worker)
            return 2
        print("Room server is ready.")

    # Import new/changed assets the same way tools/check_game.py does.
    subprocess.run([godot, "--headless", "--path", str(GAME_DIR), "--import"],
                   capture_output=True, text=True, timeout=300)

    # Give the test its own save folder so it never touches a real player's cats.
    data_home = Path(tempfile.mkdtemp(prefix="warrior-online-", dir=str(TMP_ROOT)))
    env = dict(os.environ, XDG_DATA_HOME=str(data_home))
    command = [godot, "--headless", "--path", str(GAME_DIR), SCENE, "--", f"--server={server}"]
    print("Running the online smoke test...")
    try:
        result = subprocess.run(command, capture_output=True, text=True, env=env, timeout=args.seconds)
        output = result.stdout + result.stderr
    except subprocess.TimeoutExpired as error:
        output = error.stdout or ""
        if isinstance(output, bytes):
            output = output.decode(errors="replace")
        output += f"\nTEST TIME LIMIT: the test did not finish in {args.seconds}s."
        result = None

    if args.verbose:
        print(output)
    else:
        for line in output.splitlines():
            if "ONLINE SMOKE" in line:
                print(line.strip())

    passed = result is not None and result.returncode == 0 and "ONLINE SMOKE OK" in output
    shutil.rmtree(data_home, ignore_errors=True)
    if not passed:
        print("FAILED: online play did not work.")
        if not args.verbose:
            print(tail_text(output))
        stop(worker)
        return 1

    print("OK: online rooms, joining and movement all work.")

    if args.keep and started_worker:
        print(f"Room server left running at {server} (stop it with Ctrl+C).")
        worker = None
    stop(worker)
    return 0


def tail_text(text, lines=40):
    return "\n".join(text.rstrip().splitlines()[-lines:])


if __name__ == "__main__":
    sys.exit(main())
