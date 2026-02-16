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
    }
    
    property var readyDomains: ({})
    property var titleMap: ({})
    property var downloading: ({})
    property int cacheCounter: 0
    
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
        
        let cleanTitle = title.replace(/\s*[-|—|·]\s*(Mozilla Firefox|Brave|Google Chrome|Chromium|Vivaldi|Edge|Zen|Floorp|LibreWolf|Thorium|Waterfox|Mullvad|Tor Browser|Quickshell|Antigravity)\s*$/i, "").trim();
        const lower = cleanTitle.toLowerCase();
        
        if (lower === "new tab" || lower === "new private tab" || lower === "private browsing" || lower === "about:blank" || lower === "zen") {
            return "";
        }

        // TIER 1: Smart Bridge (History Match) - HIGHEST CONFIDENCE
        const parts = cleanTitle.split(/[\s:|·|—|\||\[|\]|\(|\)|\-]/).filter(p => p.trim().length >= 2);
        if (parts.length > 0) {
            for (let i = parts.length - 1; i >= 0; i--) {
                const kw = parts[i].trim().toLowerCase();
                if (titleMap[kw]) {
                    const dom = titleMap[kw];
                    if (validateDomain(cleanTitle, dom, kw)) {
                        // console.log(`[FaviconService] History Match: "${kw}" -> ${dom}`);
                        return dom;
                    }
                }
            }
        }

        // TIER 2: Explicit Domains in Title (e.g. hypr.land)
        const domainMatch = cleanTitle.match(/([a-z0-9-]+)\.([a-z]{2,3}(\.[a-z]{2})?|land|nz|ai|io|ly|so|me|dev|app|info|xyz|icu|top|site|online)/i);
        if (domainMatch) {
            const dom = domainMatch[0].toLowerCase().replace("www.", "");
            if (validateDomain(cleanTitle, dom)) {
                return dom;
            }
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
        
        // curl -f: Fail on 404 (don't save empty file)
        // curl -L: Follow redirects
        // curl -s: Silent
        // For this we'll be using vemetric.com API to find favicons
        const download = downloadProcess.createObject(null, {
            command: ["bash", "-c", `mkdir -p "${rawCacheDir}" && ( [ -f "${path}" ] || curl -f -L -s --max-time 15 "https://favicon.vemetric.com/${domain}?size=128" -o "${path}" )`]
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
            command: ["bash", "-c", `ls "${rawCacheDir}" 2>/dev/null && echo "---OFFICIAL---" && ls "${shellDir}/assets/google" 2>/dev/null`]
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

    Component { id: downloadProcess; Process { stdout: StdioCollector {} } }
    Component { id: scanProcess; Process { stdout: StdioCollector {} } }
    Component { id: bridgeProcess; Process {} }
    Component { id: readFileProcess; FileView {} }
}
