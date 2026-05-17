# Agent Instruction Location

- Store Codex, agent, and LLM instructions, guardrails, directives, project memories, and related notes in this `.agents/` directory.
- When looking for project guidance, check `.agents/` first, including `.agents/AGENTS.md`, `.agents/AGENT.md`, and any directive, guardrail, or memory files stored here.
- Keep root-level `AGENTS.md`, `AGENT.md`, `CLAUDE.md`, `GEMINI.md`, memory files, or other agent-specific instruction files as compatibility entry points only. New or expanded guidance belongs in `.agents/`; create the directory if it does not exist.
- If a project still has guidance outside `.agents/`, treat it as legacy context and migrate or mirror future additions into `.agents/`.
