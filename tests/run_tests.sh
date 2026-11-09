#!/usr/bin/env bash
# arxupd tests — STATIC. They never run arxupd, arx, or any install.sh, and never touch the system.
#
# Why static: arxupd is now `exec arx tools`, which installs every tool in the live R2 index as
# root. The old version of this script redirected XDG_CACHE_HOME to a temp dir and ran arxupd,
# expecting a git-manifest dry run. With the R2 model that empty cache made arx treat nothing as
# installed and reinstall all nine published tools onto the real host (2026-11-09). The git
# commit/tag/signature checks it was written for no longer exist in arxupd, so it tested nothing
# and was destructive. This version checks what arxupd actually ships and does.
#
# Usage: tests/run_tests.sh            (from the repo root)
#        TOOLS_JSON=path/to/tools.json tests/run_tests.sh   (default: ../arxos-kernels/tools.json,
#                                                            else the live public index)
set -uo pipefail
cd "$(dirname "$0")/.."
fail=0; pass=0
ok(){  printf '  PASS  %s\n' "$*"; pass=$((pass+1)); }
bad(){ printf '  FAIL  %s\n' "$*"; fail=$((fail+1)); }

echo "== arxupd delegates to arx tools (checked statically, never executed) =="
grep -qE '^exec arx tools "\$@"$' arxupd && ok "arxupd execs 'arx tools'" || bad "arxupd no longer execs 'arx tools' — re-read this test"
bash -n arxupd && ok "arxupd parses" || bad "arxupd has a syntax error"

echo "== install.sh =="
bash -n install.sh && ok "install.sh parses" || bad "install.sh has a syntax error"
grep -qE 'repos\.list"? /etc/arxos/repos\.list' install.sh && ok "install.sh installs repos.list to /etc/arxos/repos.list" || bad "install.sh no longer delivers /etc/arxos/repos.list"
grep -qE 'disable --now arxupd\.timer' install.sh && ok "install.sh keeps the retired auto-update timer disabled" || bad "install.sh no longer disables arxupd.timer"

echo "== repos.list structure =="
entries=$(grep -vE '^\s*(#|$)' repos.list)
bad_rows=$(printf '%s\n' "$entries" | awk 'NF<3 || $2 !~ /^https:\/\//' )
[ -z "$bad_rows" ] && ok "every entry has name, https url, branch" || bad "malformed entries: $bad_rows"
dups=$(printf '%s\n' "$entries" | awk '{print $1}' | sort | uniq -d)
[ -z "$dups" ] && ok "no duplicate names" || bad "duplicate names: $dups"

echo "== registry vs update index (mirrors arx-core ops::registry_drift) =="
TJ="${TOOLS_JSON:-../arxos-kernels/tools.json}"
if [ -f "$TJ" ]; then src="$TJ"; idx=$(cat "$TJ")
else src="live public index"; idx=$(curl -fsSL --max-time 20 https://raw.githubusercontent.com/thearxos/arxos-kernels/main/tools.json) || idx=""; fi
if [ -z "$idx" ]; then bad "could not read the update index ($src)"
else
  drift=$(printf '%s' "$idx" | python3 -I -c '
import json, sys
delivered = set(json.load(sys.stdin).get("tools", {}))
reg, bundled = [], {}
for line in open("repos.list"):
    c = line.split()
    if not c or c[0].startswith("#"): continue
    if len(c) > 3 and c[3].startswith("bundled:"): bundled[c[0]] = c[3][8:]
    reg.append(c[0])
OTHER_ROUTE = {"linux-arxos", "arxburn"}   # same exceptions as ops.rs
print(" ".join(n for n in reg if n not in delivered and n not in OTHER_ROUTE
               and not (n in bundled and bundled[n] in delivered)))')
  [ -z "$drift" ] && ok "no registered tool is undeliverable ($src)" \
                  || bad "registered but not in the index, so they can never update: $drift"
fi

echo
echo "$pass passed, $fail failed"
[ "$fail" -eq 0 ]
