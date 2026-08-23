#!/usr/bin/env bash
# Verifies app_en.arb and app_hu.arb are consistent.
# Run from anywhere; paths are resolved relative to the repo root.
# Exit 0 = clean, 1 = problems found (each printed).
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)"
EN="$ROOT/mobile/lib/l10n/app_en.arb"
HU="$ROOT/mobile/lib/l10n/app_hu.arb"
fail=0

for f in "$EN" "$HU"; do
  [ -f "$f" ] || { echo "MISSING FILE: $f"; exit 1; }
done

keys() { grep -oE '^  "[a-zA-Z][a-zA-Z0-9_]*"' "$1" | tr -d ' "' | sort; }

# 1. key sets must match
missing_hu=$(comm -23 <(keys "$EN") <(keys "$HU"))
missing_en=$(comm -13 <(keys "$EN") <(keys "$HU"))
if [ -n "$missing_hu" ]; then
  echo "MISSING FROM app_hu.arb:"; echo "$missing_hu" | sed 's/^/  - /'; fail=1
fi
if [ -n "$missing_en" ]; then
  echo "MISSING FROM app_en.arb (or HU-only leftover):"; echo "$missing_en" | sed 's/^/  - /'; fail=1
fi

# 2. no @-metadata blocks in the Hungarian file
stray=$(grep -oE '^  "@[a-zA-Z][a-zA-Z0-9_]*"' "$HU" | tr -d ' "')
if [ -n "$stray" ]; then
  echo "@-BLOCKS IN app_hu.arb (metadata belongs in the EN template only):"
  echo "$stray" | sed 's/^/  - /'; fail=1
fi

# 3. placeholders used in a value must match between EN and HU,
#    and must be declared in the EN @-block
value_of() { # file, key -> raw value
  grep -m1 -E "^  \"$2\": " "$1" | sed -E 's/^  "[^"]*": "(.*)",?$/\1/'
}
phs_in_value() { grep -oE '\{[a-zA-Z][a-zA-Z0-9_]*[},]' <<<"$1" | tr -d '{},' | sort -u; }

while read -r key; do
  en_val=$(value_of "$EN" "$key")
  hu_val=$(value_of "$HU" "$key")
  en_ph=$(phs_in_value "$en_val")
  hu_ph=$(phs_in_value "$hu_val")
  # ICU plural branch keywords are not placeholders
  en_ph=$(grep -vxE 'plural|select|one|other|few|many|zero|two' <<<"$en_ph" || true)
  hu_ph=$(grep -vxE 'plural|select|one|other|few|many|zero|two' <<<"$hu_ph" || true)
  if [ "$en_ph" != "$hu_ph" ]; then
    echo "PLACEHOLDER MISMATCH: $key"
    echo "    en: $(tr '\n' ' ' <<<"$en_ph")"
    echo "    hu: $(tr '\n' ' ' <<<"$hu_ph")"
    fail=1
  fi
  if [ -n "$en_ph" ]; then
    block=$(awk -v k="\"@$key\":" 'index($0,k){f=1} f{print; if(/^  \},?$/) exit}' "$EN")
    while read -r ph; do
      [ -z "$ph" ] && continue
      grep -q "\"$ph\"" <<<"$block" || {
        echo "UNDECLARED PLACEHOLDER: $key uses {$ph} but the @-block does not declare it"; fail=1; }
    done <<<"$en_ph"
  fi
done < <(comm -12 <(keys "$EN") <(keys "$HU"))

if [ "$fail" -eq 0 ]; then
  echo "OK — $(keys "$EN" | wc -l | tr -d ' ') keys, EN/HU in sync."
fi
exit $fail
