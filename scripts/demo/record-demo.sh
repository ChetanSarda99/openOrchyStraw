#!/usr/bin/env bash
# ============================================
# OrchyStraw — Demo Recorder
# ============================================
#
# Wrapper that records the demo script as a terminal session
# for conversion to GIF/SVG.
#
# Supports:
#   - asciinema (preferred) — records to .cast file
#   - script (fallback) — records to typescript file
#
# Usage:
#   ./scripts/demo/record-demo.sh
#   ./scripts/demo/record-demo.sh --output demo.cast
#   ./scripts/demo/record-demo.sh --tool script --output demo.log
#
# To convert to GIF:
#   # Option 1: asciinema + agg
#   agg demo.cast demo.gif
#
#   # Option 2: asciinema + svg-term
#   npx svg-term-cli --in demo.cast --out demo.svg
#
#   # Option 3: terminalizer
#   terminalizer render demo.cast -o demo.gif

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
DEMO_SCRIPT="$SCRIPT_DIR/run-demo.sh"

OUTPUT=""
TOOL=""
TITLE="OrchyStraw Demo"

_log() { printf '[record] %s  %s\n' "$(date +%H:%M:%S)" "$*"; }
_err() { _log "ERROR: $*" >&2; }
_die() { _err "$*"; exit 1; }

_usage() {
    cat <<'EOF'
Usage: record-demo.sh [OPTIONS]

Records the OrchyStraw demo as a terminal session.

Options:
  --output <file>    Output file (default: demo-<timestamp>.cast or .log)
  --tool <name>      Recording tool: asciinema, script (default: auto-detect)
  --title <text>     Recording title (default: "OrchyStraw Demo")
  --cycles <N>       Number of demo cycles (passed to run-demo.sh)
  --help             Show this help

Requirements (one of):
  - asciinema (https://asciinema.org) — preferred
  - script (built into most Unix systems) — fallback

To convert .cast to GIF:
  agg demo.cast demo.gif               # using agg
  npx svg-term-cli --in demo.cast      # using svg-term (SVG output)
EOF
}

_detect_tool() {
    if command -v asciinema >/dev/null 2>&1; then
        printf 'asciinema'
    elif command -v script >/dev/null 2>&1; then
        printf 'script'
    else
        _die "No recording tool found. Install asciinema: https://asciinema.org"
    fi
}

main() {
    local cycles=""

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --output) OUTPUT="$2"; shift 2 ;;
            --tool)   TOOL="$2"; shift 2 ;;
            --title)  TITLE="$2"; shift 2 ;;
            --cycles) cycles="$2"; shift 2 ;;
            --help|-h) _usage; exit 0 ;;
            *)        _die "unknown arg: $1" ;;
        esac
    done

    [[ -f "$DEMO_SCRIPT" ]] || _die "demo script not found: $DEMO_SCRIPT"

    # Auto-detect tool
    if [[ -z "$TOOL" ]]; then
        TOOL="$(_detect_tool)"
    fi

    local timestamp
    timestamp="$(date +%Y%m%d-%H%M%S)"

    # Build demo command
    local demo_cmd="bash $DEMO_SCRIPT"
    [[ -n "$cycles" ]] && demo_cmd="$demo_cmd --cycles $cycles"

    case "$TOOL" in
        asciinema)
            [[ -z "$OUTPUT" ]] && OUTPUT="$SCRIPT_DIR/demo-${timestamp}.cast"
            _log "Recording with asciinema -> $OUTPUT"
            _log "Press Ctrl+D or exit when done"

            asciinema rec \
                --title "$TITLE" \
                --command "$demo_cmd" \
                --cols 100 \
                --rows 30 \
                --idle-time-limit 2 \
                "$OUTPUT"

            _log "Recording saved: $OUTPUT"
            _log "Convert to GIF: agg $OUTPUT demo.gif"
            _log "Convert to SVG: npx svg-term-cli --in $OUTPUT --out demo.svg"
            ;;

        script)
            [[ -z "$OUTPUT" ]] && OUTPUT="$SCRIPT_DIR/demo-${timestamp}.log"
            _log "Recording with script -> $OUTPUT"

            if [[ "$(uname)" == "Darwin" ]]; then
                # macOS script syntax
                script "$OUTPUT" bash -c "$demo_cmd"
            else
                # Linux script syntax
                script -c "$demo_cmd" "$OUTPUT"
            fi

            _log "Recording saved: $OUTPUT"
            _log "Note: script output includes raw terminal codes. Use asciinema for cleaner output."
            ;;

        *)
            _die "unknown tool: $TOOL (use: asciinema, script)"
            ;;
    esac
}

main "$@"
