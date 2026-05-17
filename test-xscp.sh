#!/usr/bin/env bash
# Automated tests for xscp using a real SSH target
# Usage: ./test-xscp.sh [user@host] [port]
#
# Runs non-interactive tests (passthrough mode, direct args) to verify
# single file, multi-file, and directory transfers in both directions.

set -uo pipefail

XSCP="$(cd "$(dirname "$0")" && pwd)/xscp"
TARGET="${1:-user@example.com}"
PORT="${2:-22}"

RED='\033[0;31m'
GREEN='\033[0;32m'
BOLD='\033[1m'
NC='\033[0m'

PASS=0
FAIL=0
TMPDIR_LOCAL=""
TMPDIR_REMOTE=""

cleanup() {
    [[ -n "$TMPDIR_LOCAL" ]] && rm -rf "$TMPDIR_LOCAL"
    if [[ -n "$TMPDIR_REMOTE" ]]; then
        ssh -p "$PORT" "$TARGET" "rm -rf '$TMPDIR_REMOTE'" 2>/dev/null || true
    fi
}
trap cleanup EXIT

setup() {
    TMPDIR_LOCAL=$(mktemp -d /tmp/xscp-test-XXXXXX)
    TMPDIR_REMOTE=$(ssh -p "$PORT" "$TARGET" "mktemp -d /tmp/xscp-test-XXXXXX")

    # Create test fixtures locally
    echo "hello single" > "$TMPDIR_LOCAL/single.txt"
    echo "file alpha" > "$TMPDIR_LOCAL/alpha.txt"
    echo "file beta" > "$TMPDIR_LOCAL/beta.txt"
    echo "file gamma" > "$TMPDIR_LOCAL/gamma.txt"
    mkdir -p "$TMPDIR_LOCAL/testdir/sub"
    echo "nested" > "$TMPDIR_LOCAL/testdir/sub/deep.txt"
    echo "top" > "$TMPDIR_LOCAL/testdir/top.txt"

    # Create test fixtures on remote
    ssh -p "$PORT" "$TARGET" "
        echo 'remote single' > '$TMPDIR_REMOTE/remote.txt'
        echo 'remote A' > '$TMPDIR_REMOTE/rA.txt'
        echo 'remote B' > '$TMPDIR_REMOTE/rB.txt'
        mkdir -p '$TMPDIR_REMOTE/rdir/rsub'
        echo 'remote nested' > '$TMPDIR_REMOTE/rdir/rsub/rdeep.txt'
        echo 'remote top' > '$TMPDIR_REMOTE/rdir/rtop.txt'
    "
}

assert_local_file() {
    local path="$1" expected="$2" label="$3"
    if [[ -f "$path" ]] && [[ "$(cat "$path")" == "$expected" ]]; then
        echo -e "  ${GREEN}PASS${NC} $label"
        ((PASS++))
    else
        echo -e "  ${RED}FAIL${NC} $label"
        [[ -f "$path" ]] && echo "    got: $(cat "$path")" || echo "    file not found: $path"
        ((FAIL++))
    fi
}

assert_remote_file() {
    local path="$1" expected="$2" label="$3"
    local content
    content=$(ssh -p "$PORT" "$TARGET" "cat '$path'" 2>/dev/null) || content=""
    if [[ "$content" == "$expected" ]]; then
        echo -e "  ${GREEN}PASS${NC} $label"
        ((PASS++))
    else
        echo -e "  ${RED}FAIL${NC} $label"
        echo "    expected: $expected"
        echo "    got: $content"
        ((FAIL++))
    fi
}

# --- Tests ---

test_send_single() {
    echo -e "${BOLD}Test: send single file (passthrough)${NC}"
    local port_args=()
    [[ "$PORT" != "22" ]] && port_args=(-P "$PORT")
    "$XSCP" "${port_args[@]}" "$TMPDIR_LOCAL/single.txt" "${TARGET}:${TMPDIR_REMOTE}/recv_single.txt"
    assert_remote_file "$TMPDIR_REMOTE/recv_single.txt" "hello single" "remote has file"
}

test_send_multi() {
    echo -e "${BOLD}Test: send multiple files (passthrough)${NC}"
    local port_args=()
    [[ "$PORT" != "22" ]] && port_args=(-P "$PORT")
    "$XSCP" "${port_args[@]}" "$TMPDIR_LOCAL/alpha.txt" "$TMPDIR_LOCAL/beta.txt" "$TMPDIR_LOCAL/gamma.txt" "${TARGET}:${TMPDIR_REMOTE}/"
    assert_remote_file "$TMPDIR_REMOTE/alpha.txt" "file alpha" "remote has alpha"
    assert_remote_file "$TMPDIR_REMOTE/beta.txt" "file beta" "remote has beta"
    assert_remote_file "$TMPDIR_REMOTE/gamma.txt" "file gamma" "remote has gamma"
}

test_send_dir() {
    echo -e "${BOLD}Test: send directory (passthrough)${NC}"
    local port_args=()
    [[ "$PORT" != "22" ]] && port_args=(-P "$PORT")
    "$XSCP" "${port_args[@]}" -r "$TMPDIR_LOCAL/testdir" "${TARGET}:${TMPDIR_REMOTE}/recv_dir"
    assert_remote_file "$TMPDIR_REMOTE/recv_dir/top.txt" "top" "remote has top.txt"
    assert_remote_file "$TMPDIR_REMOTE/recv_dir/sub/deep.txt" "nested" "remote has sub/deep.txt"
}

test_recv_single() {
    echo -e "${BOLD}Test: receive single file (passthrough)${NC}"
    local port_args=()
    [[ "$PORT" != "22" ]] && port_args=(-P "$PORT")
    "$XSCP" "${port_args[@]}" "${TARGET}:${TMPDIR_REMOTE}/remote.txt" "$TMPDIR_LOCAL/got_remote.txt"
    assert_local_file "$TMPDIR_LOCAL/got_remote.txt" "remote single" "local has file"
}

test_recv_multi() {
    echo -e "${BOLD}Test: receive multiple files (passthrough)${NC}"
    local port_args=()
    [[ "$PORT" != "22" ]] && port_args=(-P "$PORT")
    mkdir -p "$TMPDIR_LOCAL/got_multi"
    "$XSCP" "${port_args[@]}" "${TARGET}:${TMPDIR_REMOTE}/rA.txt" "${TARGET}:${TMPDIR_REMOTE}/rB.txt" "$TMPDIR_LOCAL/got_multi/"
    assert_local_file "$TMPDIR_LOCAL/got_multi/rA.txt" "remote A" "local has rA"
    assert_local_file "$TMPDIR_LOCAL/got_multi/rB.txt" "remote B" "local has rB"
}

test_recv_dir() {
    echo -e "${BOLD}Test: receive directory (passthrough)${NC}"
    local port_args=()
    [[ "$PORT" != "22" ]] && port_args=(-P "$PORT")
    "$XSCP" "${port_args[@]}" -r "${TARGET}:${TMPDIR_REMOTE}/rdir" "$TMPDIR_LOCAL/got_rdir"
    assert_local_file "$TMPDIR_LOCAL/got_rdir/rtop.txt" "remote top" "local has rtop.txt"
    assert_local_file "$TMPDIR_LOCAL/got_rdir/rsub/rdeep.txt" "remote nested" "local has rsub/rdeep.txt"
}

test_history_logged() {
    echo -e "${BOLD}Test: transfers logged to history${NC}"
    local count
    count=$(grep -c "$TMPDIR_REMOTE" "$HOME/.xscp_history" 2>/dev/null || echo 0)
    if [[ "$count" -ge 2 ]]; then
        echo -e "  ${GREEN}PASS${NC} history has $count entries"
        ((PASS++))
    else
        echo -e "  ${RED}FAIL${NC} expected >=2 history entries, got $count"
        ((FAIL++))
    fi
}

# --- Run ---

echo -e "${BOLD}xscp test suite${NC} — target: ${TARGET}:${PORT}"
echo ""

setup

test_send_single
test_send_multi
test_send_dir
test_recv_single
test_recv_multi
test_recv_dir
test_history_logged

echo ""
echo -e "${BOLD}Results:${NC} ${GREEN}${PASS} passed${NC}, ${RED}${FAIL} failed${NC}"
[[ "$FAIL" -eq 0 ]] || exit 1
