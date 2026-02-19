import sqlite3
import os
import json
import shutil
import tempfile
from pathlib import Path
import re
import sys
import traceback

def log(msg):
    """Print diagnostic info to stderr so QML can see it in terminal."""
    print(f"[favicon_bridge] {msg}", file=sys.stderr)

def get_browser_history_paths():
    home = str(Path.home())
    paths = []
    
    # Chromium-based browsers
    chromium_dirs = [
        f"{home}/.config/BraveSoftware/Brave-Browser",
        f"{home}/.config/google-chrome",
        f"{home}/.config/chromium",
        f"{home}/.config/microsoft-edge",
        f"{home}/.config/thorium",
        f"{home}/.config/vivaldi",
    ]
    
    # Firefox-based browsers
    firefox_dirs = [
        f"{home}/.mozilla/firefox",
        f"{home}/.zen",
        f"{home}/.floorp",
        f"{home}/.waterfox",
        f"{home}/.librewolf",
    ]
    
    for base in chromium_dirs:
        if not os.path.exists(base):
            continue
        # log(f"Scanning chromium dir: {base}")
        for root, dirs, files in os.walk(base):
            if "History" in files:
                p = os.path.join(root, "History")
                # log(f"  Found: {p}")
                paths.append(("chromium", p))
    
    for base in firefox_dirs:
        if not os.path.exists(base):
            continue
        # log(f"Scanning firefox dir: {base}")
        for root, dirs, files in os.walk(base):
            if "places.sqlite" in files:
                p = os.path.join(root, "places.sqlite")
                # log(f"  Found: {p}")
                paths.append(("firefox", p))
    
    return list(set(paths))

# Browser suffix pattern — must match FaviconService.qml cleanTitle()
BROWSER_SUFFIX = re.compile(
    r"\s*[-|—|·]\s*(Mozilla Firefox|Brave|Google Chrome|Chromium|Vivaldi|Edge|"
    r"Zen|Floorp|LibreWolf|Thorium|Waterfox|Mullvad|Tor Browser|"
    r"Quickshell|Antigravity)\s*$",
    re.IGNORECASE
)

def clean_title(raw_title):
    if not raw_title:
        return None
    clean = BROWSER_SUFFIX.sub("", raw_title).strip()
    return clean if clean else None

def extract_exact_mappings():
    title_to_url = {}
    history_paths = get_browser_history_paths()
    
    if not history_paths:
        # log("WARNING: No browser history files found!")
        return title_to_url

    for db_type, path in history_paths:
        tmp_path = None
        try:
            # Copy to temp file to avoid locking issues
            with tempfile.NamedTemporaryFile(delete=False, suffix=".db") as tmp:
                tmp_path = tmp.name
            shutil.copy2(path, tmp_path)
            
            conn = sqlite3.connect(f"file:{tmp_path}?mode=ro", uri=True)
            cursor = conn.cursor()
            
            if db_type == "chromium":
                cursor.execute("SELECT title, url FROM urls ORDER BY last_visit_time DESC LIMIT 5000")
            else:
                cursor.execute("SELECT title, url FROM moz_places WHERE title IS NOT NULL ORDER BY last_visit_date DESC LIMIT 5000")
            
            rows = cursor.fetchall()
            # log(f"  Read {len(rows)} rows from {path}")
            
            count = 0
            for title, url in rows:
                cleaned = clean_title(title)
                if cleaned and cleaned not in title_to_url:
                    title_to_url[cleaned] = url
                    count += 1
            
            # log(f"  Added {count} unique title->url mappings")
            conn.close()
            
        except Exception as e:
            # log(f"ERROR reading {path}: {e}")
            traceback.print_exc(file=sys.stderr)
        finally:
            if tmp_path and os.path.exists(tmp_path):
                try:
                    os.unlink(tmp_path)
                except:
                    pass

    return title_to_url

if __name__ == "__main__":
    # log("Starting...")
    mappings = extract_exact_mappings()
    # log(f"Total mappings: {len(mappings)}")
    
    # Print a few samples
    for i, (title, url) in enumerate(list(mappings.items())[:5]):
        # log(f"  Sample: \"{title}\" -> {url}")
    
    cache_dir = os.path.expanduser("~/.cache/quickshell/favicons")
    os.makedirs(cache_dir, exist_ok=True)
    
    out_path = os.path.join(cache_dir, "exact_title_to_url.json")
    with open(out_path, "w") as f:
        json.dump(mappings, f, indent=2)
    # log(f"Wrote {len(mappings)} entries to {out_path}")
    
    # Clean up legacy map
    legacy_path = os.path.join(cache_dir, "title_to_domain.json")
    if os.path.exists(legacy_path):
        try:
            os.remove(legacy_path)
            # log(f"Removed legacy {legacy_path}")
        except:
            pass
    
    # log("Done.")
