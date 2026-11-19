---
name: prototype
description: >-
  Antigravity Game Studio 4-step rapid game prototyping workflow (/prototype).
  Use when the user types /prototype or asks to design and build a new playable game prototype,
  chapter vertical slice, or gameplay feature from an idea.
---

# Game Studio `/prototype` Workflow Skill

Follow the four mandatory phases defined in [prototype.md](../../workflows/prototype.md):

1. **Phase 1 — Clarify Core Loop & Art Pillars**: Ask 3–4 high-impact questions on core mechanic, historical/biblical visual motifs (strictly de-Arabicized, 2.5-head-tall commercial Q-version), and scope.
2. **Phase 2 — One-Page Brief & Concept Plate**: Write `design/game-brief.md` (and invoke Codex `imagegen` if new concept/character art is needed) and wait for user sign-off.
3. **Phase 3 — Data-Driven Implementation**: Extract all tunables/levels into `src/config.ts`, implement pure state logic in `src/game.ts` and rendering in `src/World.tsx` / `src/App.tsx`, and verify `npm run build`.
4. **Phase 4 — Visual Self-Check & Acceptance Report**: Launch the local dev server, inspect and screenshot the live game in the browser to verify zero UI overlap or clipping, and deliver the structured verification report.
