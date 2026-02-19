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
    
    # Base directories to search
    bases = [
        os.path.join(home, ".config"),
        os.path.join(home, ".mozilla"),
        os.path.join(home, "snap"),
        os.path.join(home, ".var/app")
    ]
    
    for base in bases:
        if not os.path.exists(base):
            continue
            
        # log(f"Scanning base dir: {base}")
        # We use a limited walk to find databases without melting the CPU
        for root, dirs, files in os.walk(base):
            # Chromium
            if "History" in files:
                p = os.path.join(root, "History")
                # Ensure it's actually a browser history file by checking parent path
                parent = root.lower()
                if any(x in parent for x in ["chrome", "brave", "chromium", "edge", "vivaldi", "thorium", "opera", "yandex"]):
                    # log(f"  Found Chromium history: {p}")
                    paths.append(("chromium", p))
            
            # Firefox
            if "places.sqlite" in files:
                p = os.path.join(root, "places.sqlite")
                parent = root.lower()
                if any(x in parent for x in ["firefox", "mozilla", "zen", "floorp", "waterfox", "librewolf"]):
                    # log(f"  Found Firefox history: {p}")
                    paths.append(("firefox", p))
                    
            # Optimization: don't go too deep into non-browser folders
            if len(root.split(os.sep)) - len(base.split(os.sep)) > 5:
                del dirs[:]

    return list(set(paths))

# Browser suffix pattern — must match FaviconService.qml cleanTitle()
BROWSER_SUFFIX = re.compile(
    r"\s*[-|—|·]\s*(Mozilla Firefox|Brave|Google Chrome|Chromium|Vivaldi|Edge|"
    r"Zen|Floorp|LibreWolf|Thorium|Waterfox|Mullvad|Tor Browser|"
    r"Chrome|Firefox|Web Browser|Browser|Quickshell|Antigravity)\s*$",
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
    # Print a few samples
    for i, (title, url) in enumerate(list(mappings.items())[:5]):
        # log(f"  Sample: \"{title}\" -> {url}")
        pass
    
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
