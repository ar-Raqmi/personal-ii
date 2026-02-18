pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick
import QtCore

Singleton {
    id: root
    
    readonly property string homeDir: StandardPaths.writableLocation(StandardPaths.HomeLocation).toString().replace("file://", "").replace(/\/$/, "")
    readonly property string rawCacheDir: homeDir + "/.cache/quickshell/favicons"
    readonly property string shellDir: Quickshell.shellDir.toString().replace("file://", "").replace(/\/$/, "")
    readonly property string bridgePath: rawCacheDir + "/title_to_domain.json"
    
    Component.onCompleted: {
        // console.log(`[FaviconService] rawCacheDir: ${rawCacheDir}`);
        // console.log(`[FaviconService] shellDir: ${shellDir}`);
        loadBridge();
        startupScan();
        triggerBridge();
        
        // Auto-refresh bridge every 30 seconds to pick up new history
        bridgeRefreshTimer.running = true;
    }
    
    Timer {
        id: bridgeRefreshTimer
        interval: 30000
        repeat: true
        onTriggered: {
            // console.log(`[FaviconService] Auto-refreshing bridge...`);
            triggerBridge();
        }
    }
    
    property var readyDomains: ({})  // Domains with downloaded favicons
    property var titleMap: ({})      // Title -> Domain (from bridge)
    property var downloading: ({})   // Track domains currently being downloaded
    property var searching: ({})     // Track titles currently being searched
    property var foundTitles: ({})   // Cache for Title -> Domain (from search)
    property var failedTitles: ({})  // Cache for failed searches
    property int cacheCounter: 0

    // ─── STATIC KNOWLEDGE BASE (Overrides History Bias) ───────────
    property var staticTitleMap: ({
        "youtube": "youtube.com",
        "github": "github.com",
        "spotify": "spotify.com",
        "netflix": "netflix.com",
        "whatsapp": "whatsapp.com",
        "telegram": "web.telegram.org",
        "discord": "discord.com",
        "reddit": "reddit.com",
        "twitch": "twitch.tv",
        "amazon": "amazon.com",
        "twitter": "twitter.com",
        "x": "twitter.com",
        "facebook": "facebook.com",
        "instagram": "instagram.com",
        "chatgpt": "chatgpt.com",
        "openai": "openai.com",
        "notion": "notion.so",
        "figma": "figma.com",
        "linear": "linear.app",
        "slack": "slack.com",
        "gmail": "mail.google.com"
    })
    
    signal faviconDownloaded(string domain)

    function getFavicon(window) {
        if (!window || !window.title) return "";
        
        const title = window.title;
        let domain = resolveDomain(title);
        if (!domain) return "";

        // BRAND NORMALIZATION: Map variants to official assets (only Google for now)
        if (domain === "gmail.com") domain = "mail.google.com";
        if (domain === "gemini.ai") domain = "gemini.google.com";
        
        const _trigger = root.readyDomains; 
        const _path = "file://" + rawCacheDir + "/" + domain + ".png";
        
        // TIER 0: Official Assets (Highest Priority)
        const officialPath = "file://" + shellDir + "/assets/google/" + domain + ".png";
        if (readyDomains[domain + "_official"]) {
             return officialPath;
        }

        if (readyDomains[domain]) {
            return _path;
        }
        
        if (!downloading[domain]) {
            downloadFavicon(domain);
        }

        // BRAND FALLBACK
        const parts = domain.split(".");
        if (parts.length > 2) {
            const parent = parts.slice(-2).join(".");
            if (parent !== domain && (readyDomains[parent] || readyDomains[parent + "_official"])) {
                if (readyDomains[parent + "_official"]) return "file://" + shellDir + "/assets/google/" + parent + ".png";
                return "file://" + rawCacheDir + "/" + parent + ".png";
            }
        }
        
        return "";
    }

    function resolveDomain(title) {
        if (!title) return "";
        
        // DLC pack xD, basically check cache from previous searches
        if (foundTitles[title]) {
            return foundTitles[title];
        }
        
        let cleanTitle = title.replace(/\s*[-|—|·]\s*(Mozilla Firefox|Brave|Google Chrome|Chromium|Vivaldi|Edge|Zen|Floorp|LibreWolf|Thorium|Waterfox|Mullvad|Tor Browser|Quickshell|Antigravity)\s*$/i, "").trim();
        const lower = cleanTitle.toLowerCase();
        
        if (lower === "new tab" || lower === "new private tab" || lower === "private browsing" || lower === "about:blank" || lower === "zen" || lower === "history") {
            return "";
        }

        // TIER 1: MULTI-MATCH SCORING SYSTEM
        // Instead of stopping at the first match, we collect ALL candidates and score them
        // 1. History Match: +100
        // 2. Specificity: +50 per dot (drive.google.com > google.com)
        // 3. Position: +50 for start of title, decaying to 0
        // 4. Exact Keyword Match: +200 (if keyword is in subdomain)
        
        // Blacklist words
        const genericWords = [
            "web", "player", "app", "site", "page", "tab", "window", "browser", "view", "panel",
            "home", "index", "dashboard", "portal", "hub", "center", "console", "manager",
            "login", "sign", "register", "signup", "signin", "logout", "account", "profile",
            "welcome", "about", "contact", "help", "support", "faq", "wiki", "docs", "documentation",
            "search", "settings", "preferences", "options", "config", "configuration", "admin",
            "music", "video", "movies", "shows", "watch", "listen", "play", "stream", "live",
            "read", "write", "edit", "create", "new", "open", "free", "premium", "pro",
            "online", "offline", "download", "upload", "share", "save", "export", "import",
            "everyone", "official", "best", "top", "latest", "popular", "trending", "featured",
            "all", "the", "for", "and", "with", "your", "our", "this", "that", "from",
            "error", "loading", "redirect", "submit", "confirm", "verify", "update", "install", "history"
        ];

        const parts = cleanTitle.split(/[\s:|·|—|\||\[|\]|\(|\)|\-]/).filter(p => p.trim().length >= 2);
        let bestDomain = "";
        let maxScore = -1;

        if (parts.length > 0) {
            for (let i = 0; i < parts.length; i++) {
                const kw = parts[i].trim().toLowerCase();
                if (genericWords.includes(kw)) continue;

                // Priority: Static Knowledge Base > History Map
                // This ensures "youtube" -> youtube.com even if history says google.com
                const dom = root.staticTitleMap[kw] || root.titleMap[kw];

                if (dom) {
                    let score = 100; // Base score for history match

                    // Specificity Bonus: More dots = more specific (e.g. drive.google.com vs google.com)
                    score += (dom.split('.').length - 1) * 50;

                    // Position Bonus: Earlier in title = more likely the brand
                    // Decay from 50 down to 0 based on index
                    score += Math.max(0, 50 - (i * 10));

                    // Keyword in Subdomain Bonus: "drive" in "drive.google.com"
                    if (dom.includes(kw + ".")) score += 200;

                    // Penalize "root" domains if a more specific one exists
                    if (dom === "google.com" || dom === "microsoft.com") score -= 20;

                    if (validateDomain(cleanTitle, dom, kw)) {
                        // console.log(`[FaviconService] Candidate: "${kw}" -> ${dom} (Score: ${score})`);
                        if (score > maxScore) {
                            maxScore = score;
                            bestDomain = dom;
                        }
                    }
                }
            }
        }

        if (bestDomain !== "") {
            // console.log(`[FaviconService] Winner: ${bestDomain} (Score: ${maxScore})`);
            return bestDomain;
        }

        // Search cache AFTER scoring — so scoring always wins over stale search results
        if (foundTitles[title]) return foundTitles[title];

        // TIER 2: Explicit Domains in Title (e.g. hypr.land)
        const domainMatch = cleanTitle.match(/([a-z0-9-]+)\.([a-z]{2,3}(\.[a-z]{2})?|land|nz|ai|io|ly|so|me|dev|app|info|xyz|icu|top|site|online)/i);
        if (domainMatch) {
            const dom = domainMatch[0].toLowerCase().replace("www.", "");
            if (validateDomain(cleanTitle, dom)) {
                return dom;
            }
        }

        // TIER 3: Smart .com Fallback (Disabled since we using the TIER 4)
        // This was too aggressive on lookups
        // I'm keeping this here if I want to enable it in the future which likely won't happen :3
        /*
        if (parts.length > 0) {
            const genericWords = ["home", "index", "page", "login", "sign", "welcome", "about", "contact", "search", "settings"];
            for (let i = parts.length - 1; i >= 0; i--) {
                const p = parts[i].trim().toLowerCase();
                if (p.length >= 3 && !genericWords.includes(p) && /^[a-z0-9-]+$/.test(p)) {
                    const dom = p + ".com";
                    console.log(`[FaviconService] Smart Fallback: "${p}" -> ${dom}`);
                    return dom;
                }
            }
        }
        */
        
        // TIER 4: Search Engine Fallback (DuckDuckGo Lite)
        // Only trigger if we haven't failed before and aren't currently searching
        if (!failedTitles[title] && !searching[title]) {
             searchFallback(title);
        }
        
        return "";
    }

    function validateDomain(title, domain, kw) {
        if (!domain) return false;
        const lowTitle = title.toLowerCase();
        const mainPart = domain.split('.')[0].toLowerCase();

        // 1. Literal Keyword Match (Highest Confidence)
        // If we matched 'gmail' and domain is 'mail.google.com', it's valid if title contains 'gmail'
        // This has to hardcoded, I have no idea how to make it dynamic
        if (kw && domain.includes(kw) || (kw === "gmail" && domain === "mail.google.com")) return true;

        // 2. Main Domain Part Match
        if (mainPart.length >= 2) {
            const regex = new RegExp("(^|[^a-zA-Z0-9])" + mainPart, "i");
            if (regex.test(title)) return true;
            if (lowTitle.includes(mainPart)) return true; // Fallback for joined words
        }
        
        return false;
    }

    function downloadFavicon(domain) {
        if (downloading[domain]) return;
        downloading[domain] = true;
        
        const path = `${rawCacheDir}/${domain}.png`;
        
        // Multi-source favicon download:
        // 1. vemetric API (fast, high-res, works for popular sites)
        // 2. Direct /favicon.ico from the website (accurate for personal/uncommon sites)
        // 3. Google S2 API (reliable last resort)
        // For this we'll be using vemetric.com API to find favicons
        const download = downloadProcess.createObject(null, {
            command: ["bash", "-c", `mkdir -p "${rawCacheDir}" && ( [ -f "${path}" ] || curl -f -L -s --max-time 10 "https://favicon.vemetric.com/${domain}?size=128" -o "${path}" || curl -f -L -s --max-time 10 "https://${domain}/favicon.ico" -o "${path}" || curl -f -L -s --max-time 10 "https://www.google.com/s2/favicons?domain=${domain}&sz=128" -o "${path}" )`]
        });
        
        download.onExited.connect((exitCode, exitStatus) => {
            if (exitCode === 0) {
                updateReady(domain);
            } else {
                // console.log(`[FaviconService] Failed to download ${domain} (Exit: ${exitCode})`);
                delete downloading[domain];
            }
        });
        download.running = true;
    }

    function updateReady(domain) {
        let newReady = Object.assign({}, root.readyDomains);
        newReady[domain] = true;
        root.readyDomains = newReady;
        
        delete downloading[domain];
        root.cacheCounter++;
        root.faviconDownloaded(domain);
    }

    function loadBridge() {
        if (bridgePath === "") return;
        const reader = readFileProcess.createObject(null, {
            path: bridgePath
        });
        reader.onTextChanged.connect(() => {
            try {
                root.titleMap = JSON.parse(reader.text());
                // console.log(`[FaviconService] Bridge loaded with ${Object.keys(root.titleMap).length} mappings.`);
            } catch(e) {}
        });
    }

    function startupScan() {
        // Scan BOTH raw cache and official assets
        const scan = scanProcess.createObject(null, {
            command: ["bash", "-c", `ls "${rawCacheDir}" 2>/dev/null; echo "---OFFICIAL---"; ls "${shellDir}/assets/google" 2>/dev/null`]
        });
        
        scan.stdout.onStreamFinished.connect(() => {
            const output = scan.stdout.text.trim();
            if (!output) return;
            
            const lines = output.split("\n");
            let temp = {};
            let isOfficial = false;
            let offCount = 0;
            for (const line of lines) {
                const f = line.trim();
                if (!f) continue;
                if (f === "---OFFICIAL---") {
                    isOfficial = true;
                    continue;
                }
                if (f.endsWith(".png") && f.length > 4) {
                    const domain = f.replace(".png", "");
                    temp[isOfficial ? domain + "_official" : domain] = true;
                    if (isOfficial) offCount++;
                }
            }
            root.readyDomains = temp;
            root.cacheCounter++;
            // console.log(`[FaviconService] Startup scan: ${Object.keys(temp).length} items found (${offCount} official).`);
        });
        scan.running = true;
    }

    function triggerBridge() {
        const bridge = bridgeProcess.createObject(null, {
            command: ["python3", shellDir + "/scripts/favicons/favicon_bridge.py"]
        });
        bridge.onExited.connect(() => {
            loadBridge();
        });
        bridge.running = true;
    }

    function searchFallback(title) {
        if (searching[title] || failedTitles[title]) return;
        
        // Double check against basic blacklist
        const lower = title.toLowerCase();
        if (lower.length < 3 || lower.includes("new tab")) return;
        
        searching[title] = true;
        
        const proc = searchProcess.createObject(null, {
            command: ["python3", shellDir + "/scripts/favicons/search_fallback.py", title]
        });
        
        proc.onExited.connect((code) => {
            searching[title] = false; // clear searching flag
            if (code === 0) {
                const domain = proc.stdout.text.trim();
                if (domain && domain.length > 3) {
                    // console.log(`[FaviconService] Search Success: "${title}" -> ${domain}`);
                    let newFound = Object.assign({}, foundTitles);
                    newFound[title] = domain;
                    foundTitles = newFound;
                    
                    // Trigger download for this new domain
                    downloadFavicon(domain);
                    
                    // Emit signal to force refresh of getting favicon
                    // Since downloadFavicon emits faviconDownloaded, that might be enough if listeners are set up correctly.
                    // But foundTitles update changes resolveDomain result immediately.
                }
            } else {
                // console.log(`[FaviconService] Search Failed for "${title}"`);
                failedTitles[title] = true;
            }
            proc.destroy();
        });
        proc.running = true;
    }

    Component { id: downloadProcess; Process { stdout: StdioCollector {} } }
    Component { id: searchProcess; Process { stdout: StdioCollector {} } }
    Component { id: scanProcess; Process { stdout: StdioCollector {} } }
    Component { id: bridgeProcess; Process {} }
    Component { id: readFileProcess; FileView {} }
}
