# Journal CLAUDE.md Snippet

Add this section to a project's CLAUDE.md to enable proactive journal updates.

---

## Project Journal

This project uses `journal/` to track experiments, insights, goals, and working status across sessions. Run `/journal status` for an overview.

### Auto-update rules
- **working.md**: Update after every significant milestone (experiment submitted, results analyzed, major decision made). If ~10-15 exchanges pass without an update, update proactively. ALWAYS update before deploying to cluster, before any long wait, and when wrapping up.
- **experiments.md**: Add entry when an experiment completes and results are known.
- **insights.md**: Update when a non-obvious finding emerges or when new evidence changes an existing insight. Tell the evolution story.
- **goals.md**: Update when goals are achieved, priorities shift, or new goals emerge from findings.

### On session start
Read `journal/working.md` and `journal/goals.md`. Briefly mention what you see so the user can confirm or correct. This is your handoff from the previous session.

### Crash safety
`working.md` is your crash recovery document. Write it as if the next Claude session will start cold with ONLY this file and CLAUDE.md for context. Include enough detail to resume work without re-exploring.

### Update discipline
Do NOT interrupt complex multi-step operations to update the journal. Batch updates at natural pause points. The goal is ~3-6 journal writes per hour of active work — enough for crash safety, not so many that it slows you down.
