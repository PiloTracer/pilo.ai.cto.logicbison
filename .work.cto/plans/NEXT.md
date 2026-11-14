# NEXT — CTO training

**Status:** Active — 2026-11-14 · **Needs:** nothing
**Updated:** 2026-11-14

## Next action

In the thin-client target `/mnt/work/Projects/future-strategy` — apply the approved one-cell competency edit (approved 2026-11-14, confirmed **not yet run** at session close):

```
cd /mnt/work/Projects/future-strategy && perl -i -pe 's{^(\| Role & leverage \|.*)\| no \|$}{$1| yes |}' .work.cto/progress/COMPETENCY.md
```

Then `git diff --numstat .work.cto/progress/COMPETENCY.md` → expect `1  1  .work.cto/progress/COMPETENCY.md` (line 13 only; the other five areas stay `no`). No Movement log row — the cap lifted, the score did not move. Finish with `@cto-session close commit` **in that repo** so the applied schema merge plus this cell land together; its 8 unrelated `.work.biz/` edits stay out of a `.work.cto/`-scoped commit.

## Source repo (framework-dev)

| Priority | Action | Skill |
|----------|--------|-------|
| 1 | Classify `deploy-basic.sh update` merge candidates (`keep` / `review` / `MERGE` / `DRIFT`) + 5 verifier checks — done 2026-11-14, released **v0.6.3** | `@cto-deploy-basic` |
| 2 | ~~Cut release v0.6.1 (sister discovery + Agent OS anchor checks + clarity contracts)~~ — done 2026-08-19 | manual / `@cto-director` |
| 3 | ~~Decide + apply audit fixes F1/F2 (`agent.os.framework.md` protected-surface drift)~~ — done 2026-08-14 | manual |
| 4 | ~~Align `cto-session` with `session-control` (verbs, protocols, repo-mode commit scope)~~ — done 2026-08-14 | `@cto-session` |
| 5 | ~~Adopt clarity contracts (operator handoff + document clarity) + audit~~ — done 2026-08-14 | `.work.cto/prompts/adopt-framework-improvements.md` |
| 6 | ~~Sister-discovery + Agent OS anchor checks (`docs/integration/homogenization/cto.md`)~~ — done 2026-08-19 | `@cto-deploy-basic` / `@cto-deploy-files` |

## Queue (thin-client target `future-strategy`)

| Priority | Action | Skill |
|----------|--------|-------|
| 1 | Apply the approved `Cap lifted?` = yes cell + commit `.work.cto/` (see Next action) | `@cto-session` (in target) |
| 2 | `plans/NEXT.md` schema merge — lacks `## Blocked`, `## Next action`, `Skill` column (v0.6.1 rename never reached it); preserve all 33 learner lines. **Needs operator approval** | `@cto-deploy-basic - <target> update` |
| 3 | Competency map is stale vs the session log (`Streak: 1`, `Last review: (none)`, while M2a sessions + an M1 redo prep exist). Plain `status` will not fix it — its single source is the program `progress.md` ledger | `@cto-review status --full`, then `certify` with evidence |

## Blocked

- (none)
