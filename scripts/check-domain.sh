#!/usr/bin/env bash
# check-domain.sh — Check domain availability for a list of names
# Usage: ./scripts/check-domain.sh "name1" "name2" "name3"
#   or:  echo "name1 name2 name3" | ./scripts/check-domain.sh
#
# Checks .com, .io, .app, .dev, .co, .ai TLDs
# Requires: whois (apt install whois)
# Zero external dependencies — bash + whois only

set -euo pipefail

TLDS=("com" "io" "app" "dev" "co" "ai")
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color
BOLD='\033[1m'

# Rate limit: 1 second between whois queries to avoid bans
DELAY=1

check_domain() {
    local domain="$1"
    local result
    result=$(whois "$domain" 2>&1)

    # Different registrars use different "not found" messages
    if echo "$result" | grep -qiE "no match|not found|no data found|no entries found|domain not found|status: free|status: available|^% No matching record|DOMAIN NOT FOUND|is available for registration"; then
        echo "available"
    elif echo "$result" | grep -qiE "error|timed out|connection refused|quota exceeded"; then
        echo "error"
    else
        echo "taken"
    fi
}

check_social() {
    local name="$1"
    # Check if Twitter/X handle might be available (basic heuristic via HTTP status)
    local x_status
    x_status=$(curl -s -o /dev/null -w "%{http_code}" "https://x.com/$name" 2>/dev/null || echo "000")

    local gh_status
    gh_status=$(curl -s -o /dev/null -w "%{http_code}" "https://github.com/$name" 2>/dev/null || echo "000")

    echo "x:$x_status gh:$gh_status"
}

print_header() {
    echo ""
    echo -e "${BOLD}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BOLD}║  Domain & Social Handle Availability Check                  ║${NC}"
    echo -e "${BOLD}╚══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

# Collect names from args or stdin
names=()
if [ $# -gt 0 ]; then
    names=("$@")
else
    while IFS= read -r line; do
        for word in $line; do
            names+=("$word")
        done
    done
fi

if [ ${#names[@]} -eq 0 ]; then
    echo "Usage: $0 <name1> [name2] [name3] ..."
    echo "  e.g.: $0 orchystraw stormweave nexushub"
    exit 1
fi

# Check for whois
if ! command -v whois &>/dev/null; then
    echo "Error: 'whois' not installed. Run: sudo apt install whois"
    exit 1
fi

print_header

for name in "${names[@]}"; do
    name_lower=$(echo "$name" | tr '[:upper:]' '[:lower:]' | tr -cd 'a-z0-9-')

    echo -e "${BOLD}${CYAN}── $name ──${NC}"
    echo ""

    # Check domains
    echo -e "  ${BOLD}Domains:${NC}"
    for tld in "${TLDS[@]}"; do
        domain="${name_lower}.${tld}"
        printf "    %-25s " "$domain"
        status=$(check_domain "$domain")
        case "$status" in
            available)
                echo -e "${GREEN}✓ AVAILABLE${NC}"
                ;;
            taken)
                echo -e "${RED}✗ taken${NC}"
                ;;
            error)
                echo -e "${YELLOW}? error/timeout${NC}"
                ;;
        esac
        sleep "$DELAY"
    done

    # Check social handles
    echo ""
    echo -e "  ${BOLD}Social (HTTP probe — not definitive):${NC}"
    social=$(check_social "$name_lower")
    x_code=$(echo "$social" | grep -oP 'x:\K[0-9]+')
    gh_code=$(echo "$social" | grep -oP 'gh:\K[0-9]+')

    printf "    %-25s " "x.com/$name_lower"
    if [ "$x_code" = "404" ]; then
        echo -e "${GREEN}✓ possibly available${NC}"
    elif [ "$x_code" = "200" ]; then
        echo -e "${RED}✗ taken${NC}"
    else
        echo -e "${YELLOW}? status: $x_code${NC}"
    fi

    printf "    %-25s " "github.com/$name_lower"
    if [ "$gh_code" = "404" ]; then
        echo -e "${GREEN}✓ available${NC}"
    elif [ "$gh_code" = "200" ]; then
        echo -e "${RED}✗ taken${NC}"
    else
        echo -e "${YELLOW}? status: $gh_code${NC}"
    fi

    echo ""
done

echo -e "${BOLD}Notes:${NC}"
echo "  - Domain results from whois (authoritative)"
echo "  - Social checks are HTTP probes only (may have false positives)"
echo "  - For trademark search: https://www.ic.gc.ca/app/opic-cipo/trdmrks/srch/home"
echo "  - For US trademark: https://tmsearch.uspto.gov/"
echo ""
