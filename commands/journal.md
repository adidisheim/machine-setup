# /journal — Project Journal

Maintains four living documents in `journal/` at the project root that persist across Claude sessions:

| File | Purpose | Update frequency |
|------|---------|-----------------|
| `experiments.md` | Log of every experiment with sequential keys (E01, E02…) | When an experiment completes |
| `insights.md` | What we learned, with narrative of how understanding evolved | When a non-obvious finding emerges or an existing insight changes |
| `goals.md` | Project objectives, target exhibits, priority list | When goals are achieved, added, or re-prioritized |
| `working.md` | Current work-in-progress snapshot for crash recovery | Every ~10-15 exchanges, before long ops, on any state change |

Arguments passed: $ARGUMENTS

---

## Dispatch

Parse `$ARGUMENTS`. If empty, show status.

### No args or `status`

1. Read all 4 journal files (handle missing gracefully).
2. Print a compact summary: current focus (from working.md), open experiments, top 3 goals by priority, latest insight.
3. Show when working.md was last updated and warn if it looks stale.

### `init`

Initialize the journal for the current project:

1. Create `journal/` directory if it doesn't exist.
2. For each of the 4 files, create it from the templates below ONLY if it doesn't already exist. Never overwrite.
3. If `experiments/INDEX.md` exists at project root, ask whether to migrate entries into `journal/experiments.md` (preserving the original).
4. Check if the project's CLAUDE.md exists. If yes, check whether it already has a `## Project Journal` section. If not, offer to append the auto-update snippet (see "CLAUDE.md snippet" section below).
5. Print what was created and what the user should do next (fill in goals.md).

### `update [file]`

If `[file]` is specified (`experiments`, `insights`, `goals`, `working`), update just that file.
If no file is specified, review the conversation context and update ALL files that need it.

**For each file:**
1. Read the current contents first — never write blind.
2. Append new entries or modify existing ones. Never delete previous entries unless correcting an error.
3. Use cross-reference keys (E01, I01, G01) when linking between files.
4. Keep entries concise: 1-3 lines each unless genuinely complex.

### `archive <name>`

Create a full experiment archive:

1. Create `experiments/YYYY-MM-DD_<name>/` with `code/` and `slurm/` subdirectories.
2. Identify relevant Python scripts from the current work and copy them to `code/`.
3. Identify relevant SLURM scripts and copy them to `slurm/`.
4. Generate `README.md` using the experiment template (Motivation, Setup, Results, Findings, Next Steps, Code Files).
5. Generate `results.json` with key metrics as structured data.
6. Add an entry to `journal/experiments.md` with the next sequential key.
7. If `experiments/INDEX.md` exists, update it too for backward compatibility.

### `backfill`

Populate journal files from existing project state:
1. Read `experiments/INDEX.md` if it exists and create entries in `journal/experiments.md`.
2. Read memory files in `.claude/projects/*/memory/` and extract insights for `journal/insights.md`.
3. Ask the user about current goals for `journal/goals.md`.

---

## File Formats

### experiments.md

```markdown
# Experiment Log

| Key | Date | Experiment | Key Finding | Key Metric |
|-----|------|-----------|-------------|------------|
| E01 | 2026-03-23 | [Article training](../experiments/2026-03-23_article_training/) | One-line finding | Best number |
```

Rules:
- Sequential keys: E01, E02, E03… Never reuse or skip keys.
- One line per experiment batch.
- "Key Finding" = the ONE thing worth remembering.
- "Key Metric" = the single most important number (project-specific units).
- Link to archive folder if one exists.
- Append only — never reorder or renumber.

### insights.md

```markdown
# Project Insights

## I01: [Insight title] {E03, E05}
**Current understanding**: What we believe now.
**Evolution**: First we thought X (before E03). Then E03 showed Y. E05 confirmed Z.
**Evidence**: Key numbers or results supporting this.
**Confidence**: [high / medium / low / speculative]

## I02: [Superseded] Original title {E03} → see I05
_Superseded on YYYY-MM-DD. Originally stated: "..."_
```

Rules:
- Each insight has a sequential key (I01, I02…) and references experiment keys in `{}`.
- The **Evolution** section tells a story: what we thought before, what changed, why.
- UPDATE existing insights in-place when new evidence arrives — add a dated addendum rather than a new insight for the same topic.
- Only create a NEW insight for a genuinely different topic.
- Mark superseded insights clearly but don't delete them.
- Confidence levels are honest: "speculative" is fine for early-stage ideas.

### goals.md

```markdown
# Project Goals

## Big Picture
One paragraph: what is this project ultimately trying to achieve?

## Target Exhibits / Results

### G01: [Goal title] — [STATUS]
**What**: The specific result, exhibit, or deliverable.
**Why**: Why this matters for the project.
**Status**: not started / in progress / achieved / blocked / uncertain
**Linked**: {I01, E03}
**Notes**: Blockers, caveats, alternatives.

### G02: [Goal title] — [STATUS]
...
```

Rules:
- Goals ordered by priority (G01 = highest).
- STATUS in the heading for quick scanning: `— NOT STARTED`, `— IN PROGRESS`, `— ACHIEVED`, `— BLOCKED`, `— UNCERTAIN`.
- Aspirational/uncertain goals are welcome — mark honestly.
- Update status as work progresses; note the date of status changes.
- Link to insights and experiments that inform the goal.

### working.md

```markdown
# Working Status

**Last updated**: YYYY-MM-DD HH:MM

## Current Focus
1-3 sentences: what are we doing right now?

## Active Experiments
- [ ] E15: Description — submitted, waiting for results
- [x] E14: Description — done, results analyzed

## Recent Decisions
- Decided X because Y {I03}
- Pivoted from A to B after E12 showed C

## Next Steps
1. Immediate next action
2. After that
3. Further out

## Open Questions
- Unresolved question 1
- Unresolved question 2
```

Rules:
- Always update "Last updated" timestamp.
- Keep it SHORT — this is a snapshot, not a narrative.
- Write it as a briefing for a colleague who knows nothing about this conversation.
- "Active Experiments" uses checkboxes for at-a-glance status.
- "Next Steps" should be concrete and actionable.
- OK to completely rewrite sections — this file reflects NOW, not history.

---

## CLAUDE.md Snippet

When `/journal init` offers to update CLAUDE.md, append this section:

```markdown
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
```

---

## Cross-referencing Convention

All keys are project-scoped and sequential:
- **E01, E02…** — Experiments (in `experiments.md`)
- **I01, I02…** — Insights (in `insights.md`)
- **G01, G02…** — Goals (in `goals.md`)

Use `{E01, I03}` notation in any file to reference entries in other files. This creates a web of linked knowledge across the journal.
