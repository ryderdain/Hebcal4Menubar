#!/usr/bin/env bash
#
# verify.sh — check the local davening calendar against Hebcal, and write the
# test table for DAVENING_RULES.md.
#
#   bash tools/verify.sh             # Hebrew years 5784-5788
#   bash tools/verify.sh 5790 5794   # other years
#
# Read-only check script: it runs directly (no preview step) and reports on
# stdout. Exit code: 0 = no differences, 1 = differences found, 2 = the check
# could not run (download or compile failed, bad arguments).
#
# Its only writes are its own working files in build/verify (git-ignored):
# the downloaded Hebcal data, the two compiled check programs, and the table.
#
# Needs bash >= 4 (macOS /bin/bash is 3.2: `brew install bash`).

if (( BASH_VERSINFO[0] < 4 )); then
    printf 'verify.sh: needs bash >= 4, this is %s. Install it: brew install bash\n' "$BASH_VERSION" >&2
    exit 2
fi

fail() {
    printf 'verify.sh: %s\n' "$*" >&2
    exit 2
}

script_dir=${BASH_SOURCE[0]%/*}
[[ "$script_dir" == "${BASH_SOURCE[0]}" ]] && script_dir=.
repo_root=$(cd "$script_dir/.." && pwd -P) || fail "cannot find the repository root"
cd "$repo_root" || fail "cannot cd to $repo_root"

first=${1:-5784}
last=${2:-5788}
if ! [[ "$first" =~ ^[0-9]{4}$ && "$last" =~ ^[0-9]{4}$ ]] || (( first > last )); then
    fail "usage: bash tools/verify.sh [first-year last-year], for example 5784 5788"
fi

out=build/verify
mkdir -p "$out" || fail "cannot create $out"

# 1. Hebcal holiday data, diaspora (i=off) and Israel (i=on), with minor fasts.
for (( y = first; y <= last; y++ )); do
    for i in off on; do
        curl -sS --fail --retry 3 -o "$out/hol_${y}_${i}.json" \
            "https://www.hebcal.com/hebcal?v=1&cfg=json&year=${y}&yt=H&maj=on&min=on&nx=on&mf=on&mod=off&ss=off&s=off&c=off&i=${i}" \
            || fail "download failed for year $y (Israel=$i)"
    done
done

# 2. Compile the two check programs against the app's own rules code.
src=(Hebcal4Menubar/HebrewDay.swift Hebcal4Menubar/DaveningRules.swift)
swiftc "${src[@]}" tools/verify_calendar/main.swift -o "$out/verify_calendar" \
    || fail "compile failed: tools/verify_calendar"
swiftc "${src[@]}" tools/davening_table/main.swift -o "$out/davening_table" \
    || fail "compile failed: tools/davening_table"

# 3. Day-by-day comparison. Its exit code is this script's result.
"$out/verify_calendar" "$out" "$first" "$last"
result=$?

# 4. The test table (diaspora, Europe/Berlin time).
TZ=Europe/Berlin "$out/davening_table" > "$out/davening_table.md" \
    || fail "table generation failed"
printf 'Test table written to %s/davening_table.md\n' "$out"

exit "$result"
