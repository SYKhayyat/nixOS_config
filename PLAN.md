# PLAN — nixOS_config (daily driver — careful, declarative, no risky rewrites)

Worker loop: top unchecked item only, `nixos-rebuild dry-build` or `nix flake check` before commit, check off, stop.
Done: #1 (closed).

## Phase 1 — Safety first (do these before any cleanup)
- [ ] #15 destructive auto-GC `-d` wipes rollback generations. (Critical)
- [ ] #16 SSH internet-exposed with defaults → hardening (PasswordAuth, fail2ban/keys, firewall). (High)
- [ ] #10 secret shape (sops/agenix) before touching #5 — public repo + gh/onedrive/ssh declared. (High)
- [ ] #18 hardware-configuration committed + double-imported → unportable. (High)
- [ ] #13 no backup for the seforim/org library. (High)
- [ ] #17 global allowUnfree → scoped predicate. (High)
- [ ] #19 otzaria service races (net ordering, atomic swap, tmpfs). (High)

## Phase 2 — Structure (after safety)
- [ ] #11 checks/formatter/CI + restore modular layout from archived branches. (Low — unblocks everything)
- [ ] #12 home-manager adoption (replaces hand-rolled activationScripts). (Medium)
- [ ] #9 or-fallback shims + PATH hack. (Medium)
- [ ] #4 chown -R + double emacs, #2 recoll/plocate dup, #3 boilerplate/shaul/dups.

## Phase 3 — Hygiene/features
- [ ] #20 texlive-full 4-5GB, #21 nix-ld/steam bloat, #22 Lix double-eval, #24 boot bloat, #23 dead seforim.nix, #7 six finders, #8 scripts/ duplication, #6 Hebrew kbd declaration, #5 OneDrive (needs #10 first), #14 aliases.

## Routing rule for new issues
Daily-driver repo: any AI issue MUST go through Phase 1 safety screen first — secret/SSH/GC/backup items jump the queue; cleanups never outrank them. See AI_ISSUE_ROUTING.md.
