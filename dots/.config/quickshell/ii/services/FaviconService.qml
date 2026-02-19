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
    readonly property string bridgePath: rawCacheDir + "/exact_title_to_url.json"
    
    Component.onCompleted: {
        loadBridge();
        startupScan();
        triggerBridge();
        
        // Auto-refresh bridge every 5 seconds to pick up new history
        bridgeRefreshTimer.running = true;
    }
    
    Timer {
        id: bridgeRefreshTimer
        interval: 5000
        repeat: true
        onTriggered: {
            triggerBridge();
            // Evict stale downloading flags (> 40s old) to self-heal from crashed processes
            const now = Date.now();
            let newDown = Object.assign({}, root.downloading);
            let changed = false;
            for (const d in newDown) {
                if (now - newDown[d] > 40000) { delete newDown[d]; changed = true; }
            }
            if (changed) root.downloading = newDown;
            // Clear failed domains older than 60s to allow retries
            let newFailed = Object.assign({}, root.failedDomains);
            let failChanged = false;
            for (const d in newFailed) {
                if (now - newFailed[d] > 30000) { delete newFailed[d]; failChanged = true; }
            }
            if (failChanged) root.failedDomains = newFailed;
        }
    }
    
    property var readyDomains: ({})  // Domains with downloaded favicons
    property var urlMap: ({})        // CleanTitle -> FullURL (from bridge)
    property var downloading: ({})   // Track domains currently being downloaded
    property var failedDomains: ({}) // Domains that failed download (prevent infinite retries)
    property int cacheCounter: 0

    signal faviconDownloaded(string domain)

    function getFavicon(window) {
        if (!window || !window.title) return "";
        
        const title = window.title;
        const cleanRef = cleanTitle(title);
        // console.log(`[FaviconService] Checking: "${title}" -> Clean: "${cleanRef}" | urlMap size: ${Object.keys(root.urlMap).length}`);
        
        // 1. History Lookup (Highest Accuracy)
        let fullUrl = root.urlMap[cleanRef];
        let domain = "";
        
        if (fullUrl) {
            // console.log(`[FaviconService] History HIT: "${cleanRef}" -> ${fullUrl}`);
            domain = extractDomain(fullUrl);
        } else {
            // 2. Regex Fallback (New Tabs/Incognito)
            domain = extractDomainFromTitle(cleanRef);
            if (domain) {
                // console.log(`[FaviconService] Regex Fallback: "${cleanRef}" -> ${domain}`);
            } else {
                // console.log(`[FaviconService] FAILED to resolve: "${cleanRef}"`);
            }
        }

        if (!domain) return "";

        // BRAND NORMALIZATION: Map variants to official assets
        if (domain === "gmail.com") domain = "mail.google.com";
        if (domain === "gemini.ai") domain = "gemini.google.com";
        
        const _trigger = root.readyDomains; 
        const _path = "file://" + rawCacheDir + "/" + domain + ".png";
        
        // TIER 0: Official Assets (Highest Priority)
        const officialPath = "file://" + shellDir + "/assets/google/" + domain + ".png";
        if (readyDomains[domain + "_official"]) {
             // console.log(`[FaviconService] -> OFFICIAL: ${domain}`);
             return officialPath;
        }

        if (readyDomains[domain]) {
            const ext = readyDomains[domain + "_svg"] ? ".svg" : ".png";
            const p = "file://" + rawCacheDir + "/" + domain + ext;
            // console.log(`[FaviconService] -> CACHED: ${domain} -> ${p}`);
            return p;
        }
        
        if (!downloading[domain] && !failedDomains[domain]) {
            // console.log(`[FaviconService] -> DOWNLOADING: ${domain} (url: ${fullUrl || 'none'})`);
            downloadFavicon(domain, fullUrl);
        } else {
            // console.log(`[FaviconService] -> BLOCKED: ${domain} (downloading: ${!!downloading[domain]}, failed: ${!!failedDomains[domain]})`);
        }

        // BRAND FALLBACK (e.g. drive.google.com -> google.com)
        const parts = domain.split(".");
        if (parts.length > 2) {
            const parent = parts.slice(-2).join(".");
            if (parent !== domain && (readyDomains[parent] || readyDomains[parent + "_official"])) {
                if (readyDomains[parent + "_official"]) return "file://" + shellDir + "/assets/google/" + parent + ".png";
                const parentExt = readyDomains[parent + "_svg"] ? ".svg" : ".png";
                return "file://" + rawCacheDir + "/" + parent + parentExt;
            }
        }
        
        return "";
    }

    function cleanTitle(title) {
        if (!title) return "";
        return title.replace(/\s*[-|—|·]\s*(Mozilla Firefox|Brave|Google Chrome|Chromium|Vivaldi|Edge|Zen|Floorp|LibreWolf|Thorium|Waterfox|Mullvad|Tor Browser|Quickshell|Antigravity)\s*$/i, "").trim();
    }

    function extractDomain(url) {
        if (!url) return "";
        const match = url.match(/https?:\/\/(?:www\.)?([^\/]+)/i);
        return match ? match[1].toLowerCase() : "";
    }

    function extractDomainFromTitle(cleanTitle) {
        // GitHub titles use "user/repo" format
        if (/^[\w][\w.-]*\/[\w][\w.-]+([\s:]|$)/.test(cleanTitle)) {
            return "github.com";
        }
        
        // Generic "Domain.com" in title (or "http://domain.com")
        const domainMatch = cleanTitle.match(/(?:https?:\/\/)?(?:www\.)?([a-z0-9-]{2,})\.([a-z]{2,3}(\.[a-z]{2})?|land|nz|ai|io|ly|so|me|dev|app|info|xyz|icu|top|site|online)/i);
        if (domainMatch) {
            // matches[1] is domain (preview), matches[2] is TLD (md)
            return (domainMatch[1] + "." + domainMatch[2]).toLowerCase();
        }
        return "";
    }

    function downloadFavicon(domain, scrapeUrl) {
        if (downloading[domain]) return;
        let newDown = Object.assign({}, root.downloading);
        newDown[domain] = Date.now();
        root.downloading = newDown;
        
        const scriptPath = shellDir + "/scripts/favicons/download_favicon.sh";
        const targetUrl = scrapeUrl || "";
        
        const download = downloadProcess.createObject(null, {
            command: ["bash", scriptPath, domain, rawCacheDir, targetUrl]
        });
        
        download.onExited.connect((exitCode, exitStatus) => {
            // console.log(`[FaviconService] Download finished: ${domain} exit=${exitCode}`);
            if (exitCode === 0) {
                updateReady(domain);
            } else {
                // console.log(`[FaviconService] Download FAILED for ${domain}`);
                let newDown = Object.assign({}, root.downloading);
                delete newDown[domain];
                root.downloading = newDown;
                // Mark as failed to prevent infinite retries
                let newFailed = Object.assign({}, root.failedDomains);
                newFailed[domain] = Date.now();
                root.failedDomains = newFailed;
            }
            download.destroy();
        });
        download.running = true;
    }

    function updateReady(domain) {
        const checkSvg = checkProcess.createObject(null, {
            command: ["bash", "-c", `[ -f "${rawCacheDir}/${domain}.svg" ] && echo svg || echo png`]
        });
        checkSvg.stdout.onStreamFinished.connect(() => {
            const format = checkSvg.stdout.text.trim();
            let newReady = Object.assign({}, root.readyDomains);
            newReady[domain] = true;
            if (format === "svg") {
                newReady[domain + "_svg"] = true;
                // console.log(`[FaviconService] Ready (SVG): ${domain}`);
            } else {
                // console.log(`[FaviconService] Ready (PNG): ${domain}`);
            }
            root.readyDomains = newReady;
            
            let newDown = Object.assign({}, root.downloading);
            delete newDown[domain];
            root.downloading = newDown;
            
            root.cacheCounter++;
            root.faviconDownloaded(domain);
            checkSvg.destroy();
        });
        checkSvg.running = true;
    }

    function loadBridge() {
        if (bridgePath === "") return;
        const reader = readFileProcess.createObject(null, {
            path: bridgePath
        });
        reader.onTextChanged.connect(() => {
            try {
                const raw = reader.text();
                root.urlMap = JSON.parse(raw);
                // console.log(`[FaviconService] Bridge loaded: ${Object.keys(root.urlMap).length} mappings (${raw.length} bytes)`);
            } catch(e) {
                // console.log(`[FaviconService] Bridge parse ERROR: ${e}`);
            }
        });
    }

    function startupScan() {
        const cleanup = cleanupProcess.createObject(null, {
            command: ["bash", "-c", `find "${rawCacheDir}" -name "*.png" -not -name ".tmp_*" -type f | while read f; do head -c 5 "$f" | grep -qiE "^(<svg|<\\?xml)" && rm -f "$f" && continue; fsize=$(stat -c%s "$f" 2>/dev/null || echo 0); [ "$fsize" -le 400 ] && rm -f "$f"; done`]
        });
        cleanup.onExited.connect(() => {
            const scan = scanProcess.createObject(null, {
                command: ["bash", "-c", `ls "${rawCacheDir}" 2>/dev/null; echo "---OFFICIAL---"; ls "${shellDir}/assets/google" 2>/dev/null`]
            });
            scan.stdout.onStreamFinished.connect(() => {
                const output = scan.stdout.text.trim();
                if (!output) return;
                
                const lines = output.split("\n");
                let temp = {};
                let isOfficial = false;
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
                    } else if (!isOfficial && f.endsWith(".svg") && f.length > 4) {
                        const domain = f.replace(".svg", "");
                        temp[domain] = true;
                        temp[domain + "_svg"] = true; // Mark as SVG format
                    }
                }
                root.readyDomains = temp;
                root.cacheCounter++;
            });
            scan.running = true;
        });
        cleanup.running = true;
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
    Component { id: cleanupProcess; Process {} }
    Component { id: bridgeProcess; Process {} }
    Component { id: checkProcess; Process { stdout: StdioCollector {} } }
    Component { id: readFileProcess; FileView {} }
}
