#!/usr/bin/env bash
set -u
ARCHTEST=~/compliance_test/riscv-arch-test
SIM=~/compliance_test/sim/obj_dir/Vtb_top
OUTDIR=~/compliance_test/sim/results
EXTS="I M Zicsr"
mkdir -p "$OUTDIR"

PASS=0
FAIL=0

for ext in $EXTS; do
  for elf in "$ARCHTEST"/work/advaita-RVI20U32/build/rv32i/$ext/*.sig.elf; do
    [ -f "$elf" ] || continue
    name=$(basename "$elf" .sig.elf)
    sail_sig="$ARCHTEST/work/advaita-RVI20U32/build/rv32i/$ext/${name}.sig"
    [ -f "$sail_sig" ] || { echo "SKIP (no sail sig): $name"; continue; }

    addrs=$(riscv-none-elf-nm "$elf" | grep -E "begin_signature|end_signature|^[0-9a-f]+ D tohost")
    begin=$(echo "$addrs" | awk '/begin_signature/{print $1}')
    end=$(echo "$addrs"   | awk '/end_signature/{print $1}')
    tohost=$(echo "$addrs" | awk '/tohost/{print $1}')

    my_sig="$OUTDIR/${ext}_${name}.sig"
    "$SIM" "$elf" "$my_sig" "$begin" "$end" "$tohost" 2000000 2> "$OUTDIR/${ext}_${name}.log"

    if diff -q "$sail_sig" "$my_sig" > /dev/null 2>&1; then
      echo "PASS: $ext/$name"
      PASS=$((PASS+1))
    else
      echo "FAIL: $ext/$name  (see $OUTDIR/${ext}_${name}.log)"
      FAIL=$((FAIL+1))
    fi
  done
done

echo
echo "=== $PASS passed, $FAIL failed ==="