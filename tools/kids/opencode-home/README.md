# Isolated opencode config for Kids Vibe Code

`kids-vibe-code-opencode` points `XDG_CONFIG_HOME` here, so a kid session never loads the
grown-up's own opencode setup:

| Lives in the real `~/.config/opencode/` | Skipped because... |
|---|---|
| `opencode.json` (MCP servers, providers, global agents) | `XDG_CONFIG_HOME` points here instead |
| `agent/`, `command/`, `plugin/`, `skills/` | same |

The wrapper also sets `OPENCODE_DISABLE_EXTERNAL_SKILLS=1` and
`OPENCODE_DISABLE_CLAUDE_CODE_SKILLS=1`, so `~/.claude/skills` and `~/.agents/skills` are skipped
too.

`XDG_DATA_HOME` is deliberately **not** changed, so login, sessions and history stay where they
are and the kid doesn't have to sign in again.

`share` is off here so a child's conversation can't be published by accident.