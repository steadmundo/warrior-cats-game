// Serves the Godot web build as a Cloudflare Worker with static assets.
//
// Almost every request is handed straight to the ASSETS binding. The exception
// is index.wasm: Godot's engine file is about 36 MiB and Cloudflare refuses to
// store or serve any single static asset bigger than 25 MiB.
//
// The build therefore cuts the engine into parts smaller than that limit
// (index.wasm.0, index.wasm.1, ...) and writes index.wasm.json listing them.
// This Worker streams the parts back to back as one response, so the browser
// still sees a single ordinary /index.wasm download.
//
// Two approaches that do NOT work, for the record:
//   - Storing index.wasm.gz and setting "Content-Encoding: gzip" from a Pages
//     _headers file: Cloudflare strips Content-Encoding from _headers.
//   - Setting the same header from a Worker: Cloudflare compresses the body a
//     second time, so the browser receives gzip-of-gzip and the engine fails to
//     start. Leaving the bytes uncompressed avoids the whole problem.

const WASM_PATH = "/index.wasm";
const MANIFEST = "/index.wasm.json";

// Read the part list once per isolate, not on every download. The manifest has
// to come from the ASSETS binding: a Worker cannot fetch its own public URL.
let manifestPromise = null;

function partNames(env, origin) {
  if (!manifestPromise) {
    manifestPromise = env.ASSETS.fetch(new URL(MANIFEST, origin))
      .then((response) => (response.ok ? response.json() : { parts: [] }))
      .then((manifest) => (Array.isArray(manifest.parts) ? manifest.parts : []))
      .catch(() => []);
  }
  return manifestPromise;
}

async function wasmResponse(request, env) {
  const parts = await partNames(env, request.url);
  const headers = {
    "Content-Type": "application/wasm",
    "Cache-Control": "public, max-age=31536000, immutable",
  };

  if (request.method === "HEAD") {
    return new Response(null, { status: 200, headers });
  }
  if (parts.length === 0) {
    return new Response("The engine file is missing from this build.", { status: 500, headers });
  }

  let next = 0;
  const body = new ReadableStream({
    async pull(controller) {
      while (next < parts.length) {
        const part = parts[next++];
        const response = await env.ASSETS.fetch(new URL(`/${part}`, request.url));
        if (!response.ok) {
          controller.error(new Error(`Missing build file ${part}`));
          return;
        }
        const bytes = new Uint8Array(await response.arrayBuffer());
        if (bytes.byteLength > 0) {
          controller.enqueue(bytes);
          return;
        }
      }
      controller.close();
    },
  });

  return new Response(body, { status: 200, headers });
}

export default {
  async fetch(request, env) {
    const url = new URL(request.url);
    if (url.pathname === WASM_PATH && (request.method === "GET" || request.method === "HEAD")) {
      return wasmResponse(request, env);
    }
    return env.ASSETS.fetch(request);
  },
};
