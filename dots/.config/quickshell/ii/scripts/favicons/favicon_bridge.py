import sqlite3
import os
import json
import shutil
import tempfile
from pathlib import Path
import re
from collections import Counter

def get_browser_history_paths():
    home = str(Path.home())
    paths = []
    
    search_dirs = [
        f"{home}/.config/BraveSoftware/Brave-Browser",
        f"{home}/.config/google-chrome",
        f"{home}/.config/chromium",
        f"{home}/.config/microsoft-edge",
        f"{home}/.config/thorium",
        f"{home}/.config/vivaldi",
        f"{home}/.mozilla/firefox",
        f"{home}/.zen",
        f"{home}/.floorp",
        f"{home}/.waterfox",
        f"{home}/.librewolf"
    ]
    
    for base in search_dirs:
        if not os.path.exists(base):
            continue
        for root, dirs, files in os.walk(base):
            if "History" in files:
                paths.append(("chromium", os.path.join(root, "History")))
            if "places.sqlite" in files:
                paths.append(("firefox", os.path.join(root, "places.sqlite")))
    
    return list(set(paths))

def extract_mappings():
    raw_mappings = []
    history_paths = get_browser_history_paths()
    
    # Blacklist generic terms that shouldn't be used as keywords
    blacklist = {
        "new", "tab", "private", "browsing", "about", "untitled", "loading", "index", "home",
        "http", "https", "www", "com", "net", "org", "gov", "edu", "io", "ai", "me", "dev", "app",
        "google", "bing", "yahoo", "search", "engine", "browser", "window", "page", "history"
    }

    def clean_keywords(title):
        if not title: return []
        # Remove common browser suffixes
        clean = re.sub(r"\s*[-|—|·]\s*(Mozilla Firefox|Brave|Google Chrome|Chromium|Vivaldi|Edge|Zen|Floorp|LibreWolf|Thorium|Waterfox|Mullvad|Tor Browser|Quickshell|Antigravity)\s*$", "", title, flags=re.IGNORECASE).strip()
        
        # Split by common separators
        parts = re.split(r"[:|·|—|\||\[|\]|\(|\)|\s|\-|,|\.|\/|\?|&|=]", clean)
        keywords = []
        for p in parts:
            p = p.strip().lower()
            # Allow 2-char words but exclude blacklist/TLDs
            if len(p) >= 2 and p not in blacklist:
                # Avoid purely numeric or single-symbol keywords
                if not p.isdigit() and re.search('[a-z]', p):
                    keywords.append(p)
        return keywords

    def get_domain(url):
        match = re.search(r"https?://(?:www\.)?([^/]+)", url)
        return match.group(1).lower() if match else None

    for type, path in history_paths:
        try:
            with tempfile.NamedTemporaryFile(delete=False) as tmp:
                shutil.copy2(path, tmp.name)
                conn = sqlite3.connect(tmp.name)
                cursor = conn.cursor()
                
                if type == "chromium":
                    cursor.execute("SELECT title, url FROM urls ORDER BY last_visit_time DESC LIMIT 10000")
                else:
                    cursor.execute("SELECT title, url FROM moz_places WHERE title IS NOT NULL ORDER BY last_visit_date DESC LIMIT 10000")
                
                for title, url in cursor.fetchall():
                    domain = get_domain(url)
                    if domain:
                        for kw in clean_keywords(title):
                            raw_mappings.append((kw, domain))
                
                conn.close()
                os.unlink(tmp.name)
        except Exception:
            pass

    kw_to_domains = {}
    for kw, domain in raw_mappings:
        if kw not in kw_to_domains:
            kw_to_domains[kw] = Counter()
        kw_to_domains[kw][domain] += 1

    final_map = {}
    for kw, domains in kw_to_domains.items():
        # TIER 3: Weighted Resolution
        weighted_scores = Counter()
        for dom, count in domains.items():
            weight = count
            norm_dom = dom.replace(".", "")
            
            # Massive bonus for exact subdomain mapping
            # (e.g. "drive" in "drive.google.com")
            if kw in norm_dom:
                weight *= 200
            
            # Special case for Gmail (often appears as 'gmail' but domain is 'mail.google.com')
            if kw == "gmail" and dom == "mail.google.com":
                weight *= 200

            # De-prioritize giants when they are just the container
            if dom in ["github.com", "gitlab.com", "google.com", "youtube.com", "stackoverflow.com", "duckduckgo.com"]:
                weight *= 0.01
                
            weighted_scores[dom] = weight

        most_common = weighted_scores.most_common(2)
        if len(most_common) == 1:
            final_map[kw] = most_common[0][0]
        elif len(most_common) > 1:
            top_domain, top_score = most_common[0]
            second_domain, second_score = most_common[1]
            
            # If the top domain is a project domain (weight bonus triggered)
            # and the second is also a project domain, just pick the top one (tie break)
            # But ensure we are significantly better than the first NON-project domain
            if top_score > second_score:
                if top_score > second_score * 1.5 or (kw in top_domain.replace(".","") and kw in second_domain.replace(".","")):
                    final_map[kw] = top_domain
            else:
                # Actual tie (score == second_score)
                # Pick the shorter domain (likely the main site)
                if len(top_domain) <= len(second_domain):
                    final_map[kw] = top_domain
                else:
                    final_map[kw] = second_domain

    return final_map

if __name__ == "__main__":
    mappings = extract_mappings()
    
    # Use standard cache directory based on the user's home
    cache_dir = os.path.expanduser("~/.cache/quickshell/favicons")
    os.makedirs(cache_dir, exist_ok=True)
    
    with open(os.path.join(cache_dir, "title_to_domain.json"), "w") as f:
        json.dump(mappings, f, indent=2)
