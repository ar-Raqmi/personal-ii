import qs.modules.common
import qs.modules.common.widgets
import qs.services
import qs.modules.common.functions
import Qt5Compat.GraphicalEffects
import QtQuick
import Quickshell.Io
import Quickshell.Widgets

IconImage {
    id: root
    property string url
    property string displayText

    property real size: 32
    property string downloadUserAgent: Config.options?.networking.userAgent ?? ""
    property string faviconDownloadPath: Directories.favicons
    property string domainName: url.includes("vertexaisearch") ? displayText : StringUtils.getDomain(url)
    property string faviconUrl: `https://www.google.com/s2/favicons?domain=${domainName}&sz=32`
    property string fileName: `${domainName}.ico`
    property string faviconFilePath: `${faviconDownloadPath}/${fileName}`
    property string urlToLoad

    Process {
        id: faviconDownloadProcess
        running: false
        property string tmpPath: `${faviconDownloadPath}/.tmp_${fileName}`
        command: ["bash", "-c", `[ -f ${faviconFilePath} ] && exit 0 || curl -s '${root.faviconUrl}' -o '${tmpPath}' -L -H 'User-Agent: ${downloadUserAgent}' && head -c 5 '${tmpPath}' | grep -qiE '^(<svg|<\\?xml)' && rm -f '${tmpPath}' && exit 1; fsize=$(stat -c%s '${tmpPath}' 2>/dev/null || echo 0); [ "$fsize" -le 400 ] && rm -f '${tmpPath}' && exit 1; mv '${tmpPath}' '${faviconFilePath}'`]
        onExited: (exitCode, exitStatus) => {
            if (exitCode === 0) {
                root.urlToLoad = root.faviconFilePath
            }
        }
    }

    Component.onCompleted: {
        faviconDownloadProcess.running = true
    }

    source: Qt.resolvedUrl(root.urlToLoad)
    implicitSize: root.size

    layer.enabled: true
    layer.effect: OpacityMask {
        maskSource: Rectangle {
            width: root.implicitSize
            height: root.implicitSize
            radius: Appearance.rounding.full
        }
    }
}