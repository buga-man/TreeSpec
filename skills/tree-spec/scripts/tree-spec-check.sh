#!/usr/bin/env bash
# ════════════════════════════════════════════════════════════════
# tree-spec-check.sh — fast per-area pre-flight for the TreeSpec kit.
#
# Ships inside the kit (skills/tree-spec/scripts/); runs the consumer
# repo's assert groups in tests/<area>/. Run only the group matching the
# area you just edited so a single-area check returns fast (REQ-VALID-004
# / EPIC-008). Same asserts as tests/, same exit-code semantics as
# `bash tests/run-all.sh`, so the two runners never disagree.
#
# Pure stdlib — no installs, no network, no compiled binary dependency.
# ════════════════════════════════════════════════════════════════
set -u

# Resolve the target repo root by walking up to the nearest tree-spec.toml.
# The script lives inside the kit but checks the consumer repo, so find the
# root this way — correct no matter where the kit is installed / invoked.
cd "$(dirname "$0")" || exit 2
root="$(pwd)"
while [ "$root" != "/" ] && [ ! -f "$root/tree-spec.toml" ]; do
    root="$(cd "$root/.." && pwd)"
done
cd "$root" || exit 2

# mode -> test script. --all is handled separately so its exit code stays
# identical to `bash tests/run-all.sh` (AC-3), including the
# backward-compat group run-all.sh adds beyond the three areas.
declare -A MODE=(
  [manifest]="tests/manifest/test-rules.sh"
  [spec]="tests/spec/test-rules.sh"
  [router]="tests/router/test-rules.sh"
)

usage() {
    cat >&2 <<EOF
Usage: tree-spec-check.sh [--mode] [--all]
  (no flag) or --all   run every group + backward-compat (== tests/run-all.sh)
  --manifest           run tests/manifest/ asserts only
  --spec               run tests/spec/ asserts only
  --router             run tests/router/ asserts only
Exit: 0 ok, 1 an assert failed, 2 bad usage
EOF
    exit 2
}

# --- usage / arg parsing -------------------------------------------------
# Accept both `--manifest` and `manifest`; normalize to the bare key the
# MODE table is keyed on, so lookups below stay simple.
mode="${1:-all}"
[ "$#" -gt 1 ] && usage
mode="${mode#--}"; mode="${mode#-}"
case "$mode" in
  -h|--help|help) usage ;;
esac

# --- target: --all delegates to the authoritative runner (AC-3) ----------
if [ "$mode" = "all" ]; then
    bash "tests/run-all.sh"
    exit $?
fi

# --- unknown mode --------------------------------------------------------
script="${MODE[$mode]:-}"
if [ -z "$script" ]; then
    echo "tree-spec-check.sh: unknown mode '$mode'" >&2
    echo "Try: --manifest | --spec | --router | --all" >&2
    exit 2
fi

# --- run -----------------------------------------------------------------
if [ ! -f "$script" ]; then
    echo "tree-spec-check.sh: missing $script" >&2
    exit 2
fi

if bash "$script"; then
    echo "tree-spec-check.sh: OK — $mode asserts passed"
    exit 0
else
    echo "tree-spec-check.sh: FAIL — $mode asserts failed (see output above)" >&2
    exit 1
fi
