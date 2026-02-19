#!/bin/bash
# Favicon downloader script
# Usage: download_favicon.sh <domain> <cache_dir> <scrape_url>
# Exit 0 on success, 1 on failure

DOMAIN="$1"
CACHE_DIR="$2"
SCRAPE_URL="$3"

FINAL_PATH="${CACHE_DIR}/${DOMAIN}.png"
FINAL_SVG="${CACHE_DIR}/${DOMAIN}.svg"
TMP_PATH="${CACHE_DIR}/.tmp_${DOMAIN}"

mkdir -p "$CACHE_DIR"

# Already cached (either format)
[ -f "$FINAL_PATH" ] && exit 0
[ -f "$FINAL_SVG" ] && exit 0

validate_png() {
    local f="${TMP_PATH}.png"
    [ ! -f "$f" ] && return 1
    # Reject tiny files (< 400 bytes = likely error page)
    fsize=$(stat -c%s "$f" 2>/dev/null || echo 0)
    [ "$fsize" -le 400 ] && rm -f "$f" && return 1
    # Reject HTML/text error pages
    head -c 15 "$f" | grep -qiE "(^<!|^<html|^HTTP)" && rm -f "$f" && return 1
    return 0
}

validate_svg() {
    local f="${TMP_PATH}.svg"
    [ ! -f "$f" ] && return 1
    fsize=$(stat -c%s "$f" 2>/dev/null || echo 0)
    [ "$fsize" -le 50 ] && rm -f "$f" && return 1
    # Must actually be SVG content
    head -c 10 "$f" | grep -qiE "^(<svg|<\?xml)" || { rm -f "$f"; return 1; }
    return 0
}

# Source 1: vemetric API — may return SVG or PNG
curl -f -L -s --max-time 10 "https://favicon.vemetric.com/${DOMAIN}?size=128" -o "${TMP_PATH}.raw" 2>/dev/null
if [ -f "${TMP_PATH}.raw" ]; then
    if head -c 10 "${TMP_PATH}.raw" | grep -qiE "^(<svg|<\?xml)"; then
        # It's an SVG — check if it's a vemetric generic placeholder
        # They use 'icon-tabler-world-question' or 'icon-tabler-world' as fallback
        if grep -qE "(world-question|icon-tabler-world|icon-tabler-globe)" "${TMP_PATH}.raw" 2>/dev/null; then
            # Generic placeholder — skip it
            rm -f "${TMP_PATH}.raw"
        else
            # Looks like a real SVG favicon
            mv "${TMP_PATH}.raw" "${TMP_PATH}.svg"
            validate_svg && mv "${TMP_PATH}.svg" "$FINAL_SVG" && exit 0
            rm -f "${TMP_PATH}.svg"
        fi
    else
        mv "${TMP_PATH}.raw" "${TMP_PATH}.png"
        validate_png && mv "${TMP_PATH}.png" "$FINAL_PATH" && exit 0
        rm -f "${TMP_PATH}.png"
    fi
fi

# Source 2: HTML scraping (use scrape URL if given, otherwise domain root)
TARGET_URL="${SCRAPE_URL:-https://${DOMAIN}}"
html_icon=$(curl -f -L -s --max-time 10 "$TARGET_URL" 2>/dev/null | python3 -c "
import sys, re
h = sys.stdin.read()
# Try rel=icon or rel='shortcut icon'
m = re.search(r'<link[^>]+rel=[\"'\''\\s]?([^\"'\''\\s>]*(?:icon|shortcut icon)[^\"'\''\\s>]*)[\"'\''\\s]?[^>]*href=[\"'\'']?([^\"'\''\\s>]+)', h, re.I)
if not m:
    m = re.search(r'<link[^>]+href=[\"'\'']?([^\"'\''\\s>]+)[^>]+rel=[\"'\'\'']?([^\"'\''\\s>]*(?:icon)[^\"'\''\\s>]*)', h, re.I)
    icon = m.group(1).strip() if m else None
else:
    icon = m.group(2).strip() if m else None
if icon:
    print(icon)
else:
    sys.exit(1)
" 2>/dev/null)

if [ -n "$html_icon" ]; then
    case "$html_icon" in
        http*) icon_url="$html_icon" ;;
        //*) icon_url="https:$html_icon" ;;
        /*) icon_url="https://${DOMAIN}$html_icon" ;;
        *) icon_url="https://${DOMAIN}/$html_icon" ;;
    esac
    curl -f -L -s --max-time 10 "$icon_url" -o "${TMP_PATH}.raw" 2>/dev/null
    if [ -f "${TMP_PATH}.raw" ]; then
        if head -c 10 "${TMP_PATH}.raw" | grep -qiE "^(<svg|<\?xml)"; then
            mv "${TMP_PATH}.raw" "${TMP_PATH}.svg"
            validate_svg && mv "${TMP_PATH}.svg" "$FINAL_SVG" && exit 0
        else
            mv "${TMP_PATH}.raw" "${TMP_PATH}.png"
            validate_png && mv "${TMP_PATH}.png" "$FINAL_PATH" && exit 0
        fi
    fi
fi

# Source 3: Direct /favicon.ico
curl -f -L -s --max-time 10 "https://${DOMAIN}/favicon.ico" -o "${TMP_PATH}.png" 2>/dev/null && validate_png && mv "${TMP_PATH}.png" "$FINAL_PATH" && exit 0

# Source 4: Google S2
curl -f -L -s --max-time 10 "https://www.google.com/s2/favicons?domain=${DOMAIN}&sz=128" -o "${TMP_PATH}.png" 2>/dev/null && validate_png && mv "${TMP_PATH}.png" "$FINAL_PATH" && exit 0

# Source 5: DuckDuckGo icons
curl -f -L -s --max-time 10 "https://icons.duckduckgo.com/ip3/${DOMAIN}.ico" -o "${TMP_PATH}.png" 2>/dev/null && validate_png && mv "${TMP_PATH}.png" "$FINAL_PATH" && exit 0

# Cleanup any leftover tmp files
rm -f "${TMP_PATH}.raw" "${TMP_PATH}.png" "${TMP_PATH}.svg"

exit 1
