# git.md — Versioning & commit notes for ARXOS (for CLAUDE and maintainers)

This file documents the ARXOS versioning policy and commit conventions for use by CLAUDE/Codex and humans when making changes to ARXOS repositories. It mirrors the short note added in COMMIT_NOTES.md and must be preserved as the authoritative quick reference when editing arxupd or related repos.

## Version pinning during build phase
- While ARXOS is in the build/QA phase, `arxupd` intentionally pins every shipped ARXOS tool to `0.0.1`.
- Rationale: provide a reproducible, redistributable pre-ship baseline so that the ISO and golden VM images contain a consistent set of versions for QA and auditing.
- Do NOT change `ARXOS_VERSION` in `arxupd` away from `0.0.1` until the release (GA) is declared.

## Post-release versioning policy
- After the official ARXOS release (ISO published to archive.org), individual tools will increment from `0.0.1` as patches land (e.g., `0.0.2`, `0.0.3`, ...).
- Each tool must expose a `VERSION` constant surfaced by `--version` and in any UI footer.
- The unified updater pipeline will deliver those version bumps to installs; coordinate version bumps via a documented release workflow and changelog entries.

## Commit identity & PR conventions
- Author commits using the project identity (override):
  - Name: `0xb0rn3 | スティングレイ`
  - Email: `154826956+0xb0rn3@users.noreply.github.com`
  - Use: `git -c user.name="0xb0rn3 | スティングレイ" -c user.email="154826956+0xb0rn3@users.noreply.github.com" commit ...`
- Strip any AI session trailers/co-author lines from commits; the canonical author identity above must be used for commits pushing to `thearxos` org.

## Notes for CLAUDE (automation)
- When reviewing or changing arxupd, read `CLAUDE.md`, `prioritize.md`, and `ArxOS_kernel.md` first. These are the canonical doctrine files.
- Do not propose changing `ARXOS_VERSION` to anything other than `0.0.1` while the project is in the build/QA phase.
- When the project enters GA, update this file and COMMIT_NOTES.md, then perform coordinated version bumps and record the release in the repo changelogs.

## Where this appears
- This file is added to the `arxupd` repository on branch `feature/sigkey-verification` and will be included in the PR describing the sigkey/tag verification changes.

## Change recorded
- 2026-07-01 — Versioning guidance added to `git.md` on `feature/sigkey-verification` to ensure CLAUDE/Codex sessions and reviewers know the `0.0.1` pinning rationale and post-release plan.
