# Development Workflow

This repo uses a simple rule after any meaningful implementation change:

## Picky Review Rule

After any significant code change, the agent should automatically run a dedicated review pass in the same session before moving on.

The preferred review pattern is:
1. implement the change
2. run runtime validation
3. run an independent reviewer subagent
4. fix findings
5. re-run validation
6. if the fixes are substantial, run another independent review pass

Do not treat a same-context self-check as the primary picky review when an independent subagent reviewer is available.

Significant code change includes:
- gameplay logic changes
- AI behavior changes
- combat changes
- economy/balance logic changes
- scene-structure changes
- data model or config-schema changes
- collision, movement, or interaction changes
- refactors that change runtime behavior

Non-significant change examples:
- typo fixes in docs
- comment-only edits
- small text/UI copy tweaks with no logic change

## Independent Review Requirement

The picky review should be independent whenever possible:
- use a separate reviewer subagent with no implementation role
- ask for findings only, not a rewrite or summary
- have the reviewer focus on bugs, regressions, exploits, reset/state issues, config drift, and scene/runtime fragility
- treat the implementation as suspect by default; the reviewer should try to prove it wrong, not confirm it

If independent delegation is unavailable, fall back to a clearly separated self-review pass and say that confidence is lower.

## Review Prompt

Default automatic review prompt after significant code changes:

```text
review code
```

If the change is risky, use:

```text
review code carefully
```

The review should be picky and focus on:
- bugs
- regressions
- invalid edge-case behavior
- config/data drift
- missing validation
- state-reset issues
- gameplay exploits
- scene/config fragility
- cross-file interaction bugs
- timing/state-machine bugs

Reviews should prioritize findings over summaries.
Reviews should not praise the implementation or default to agreement.

Preferred reviewer framing:

```text
Assume this change is wrong. Find gameplay regressions, state-machine bugs, reset-order issues, config drift, scene fragility, and cross-file behavior breaks. Report findings only.
```

For this repo, reviewers should explicitly think through:
- restart/reset flow
- spawn/respawn flow
- prep-wave-wave transitions
- attack prep vs strike state
- enemy detection vs facing
- collision/body-pressure behavior
- config-driven content validation

## Runtime Probe Requirement

For gameplay, AI, combat, collision, spawn, reset, or phase/state-machine changes, the review should include a targeted runtime probe when feasible, not just static code reading.

Good probe examples for this repo:
- headless scripted wave-start probes
- targeted attack/HP probes against walls, doors, player, or exploration enemies
- restart/reset probes that inspect spawned nodes and state after `R`
- prep/wave transition probes that verify enemy suspension, respawn, and resume behavior

If a runtime probe is not used, the review result should explicitly say that confidence is lower and that behavior was not runtime-verified.

## Expected Follow-Up

After the review:
1. fix all actionable findings
2. re-run validation
3. if the fixes are substantial, run another review pass

## Commit Checklist

Before commit or push, confirm:
- significant code change: runtime validation was run first
- significant code change: an independent picky review pass was run when available
- significant gameplay/state-machine change: a targeted runtime probe was run when feasible
- actionable findings were fixed or consciously deferred
- runtime validation was re-run after the fixes
- if the fixes were substantial, another review pass was run

## Validation

For runtime-safe checks, use:

```bash
godot --headless --path . --quit
```
