// pragma NativeMethodBehavior: AcceptThisObject
import qs
import qs.services
import qs.modules.common
import qs.modules.common.models
import qs.modules.common.widgets
import qs.modules.common.functions
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import Quickshell.Hyprland

Rectangle {
    id: root
    property LauncherSearchResult entry
    property string query
    property bool entryShown: entry?.shown ?? true
    property string itemType: entry?.type ?? Translation.tr("App")
    property string itemName: entry?.name ?? ""
    property var iconType: entry?.iconType
    property string iconName: entry?.iconName ?? ""
    property var itemExecute: entry?.execute
    property var fontType: switch(entry?.fontType) {
        case LauncherSearchResult.FontType.Monospace:
            return "monospace"
        case LauncherSearchResult.FontType.Normal:
            return "main"
        default:
            return "main"
    }
    property string itemClickActionName: entry?.verb ?? "Open"
    property string bigText: entry?.iconType === LauncherSearchResult.IconType.Text ? entry?.iconName ?? "" : ""
    property string materialSymbol: entry.iconType === LauncherSearchResult.IconType.Material ? entry?.iconName ?? "" : ""
    property string cliphistRawString: entry?.rawValue ?? ""
    property bool blurImage: entry?.blurImage ?? false
    
    // Keyboard navigation
    property bool highlighted: false
    
    visible: root.entryShown
    implicitHeight: mainColumn.implicitHeight + 16
    radius: Appearance.rounding.small
    color: (mouseArea.containsPress || root.highlighted) ? Appearance.colors.colLayer2Active : (mouseArea.containsMouse ? Appearance.colors.colLayer2Hover : Appearance.colors.colLayer2)

    Behavior on color { ColorAnimation { duration: 150 } }

    property string highlightPrefix: `<font color="${Appearance.colors.colPrimary}">`
    property string highlightSuffix: `</font>`
    function highlightContent(content, query) {
        if (!query || query.length === 0 || content == query || fontType === "monospace")
            return StringUtils.escapeHtml(content);

        let contentLower = content.toLowerCase();
        let queryLower = query.toLowerCase();

        let result = "";
        let lastIndex = 0;
        let qIndex = 0;

        for (let i = 0; i < content.length && qIndex < query.length; i++) {
            if (contentLower[i] === queryLower[qIndex]) {
                if (i > lastIndex)
                    result += StringUtils.escapeHtml(content.slice(lastIndex, i));
                result += root.highlightPrefix + StringUtils.escapeHtml(content[i]) + root.highlightSuffix;
                lastIndex = i + 1;
                qIndex++;
            }
        }
        if (lastIndex < content.length)
            result += StringUtils.escapeHtml(content.slice(lastIndex));

        return result;
    }
    property string displayContent: highlightContent(root.itemName, root.query)

    ColumnLayout {
        id: mainColumn
        anchors {
            left: parent.left
            right: parent.right
            top: parent.top
            margins: 8
        }
        spacing: 4

        RowLayout {
            spacing: 10
            Layout.fillWidth: true

            // Icon
            Loader {
                id: iconLoader
                active: true
                Layout.alignment: Qt.AlignTop
                sourceComponent: switch(root.iconType) {
                    case LauncherSearchResult.IconType.Material: return materialSymbolComponent
                    case LauncherSearchResult.IconType.Text: return bigTextComponent
                    case LauncherSearchResult.IconType.System: return iconImageComponent
                    default: return null
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0
                
                StyledText {
                    text: root.itemType
                    font.pixelSize: Appearance.font.pixelSize.smallest
                    color: Appearance.colors.colSubtext
                    visible: root.itemType != ""
                }

                StyledText {
                    id: nameText
                    Layout.fillWidth: true
                    textFormat: Text.StyledText
                    font.pixelSize: Appearance.font.pixelSize.small
                    font.family: Appearance.font.family[root.fontType]
                    color: Appearance.colors.colOnSurface
                    elide: Text.ElideRight
                    maximumLineCount: 2
                    wrapMode: Text.Wrap
                    text: root.displayContent
                }
            }
            
            // Actions
            RowLayout {
                spacing: 4
                Layout.alignment: Qt.AlignTop
                Repeater {
                    model: (root.entry.actions ?? []).slice(0, 2)
                    delegate: IconToolbarButton {
                        required property var modelData
                        text: modelData.iconName || "video_settings"
                        implicitWidth: 30
                        implicitHeight: 30
                        onClicked: modelData.execute()
                        StyledToolTip { text: modelData.name }
                    }
                }
            }
        }

        Loader {
            active: root.cliphistRawString && Cliphist.entryIsImage(root.cliphistRawString)
            Layout.fillWidth: true
            sourceComponent: CliphistImage {
                entry: root.cliphistRawString
                maxWidth: mainColumn.width
                maxHeight: 120
                blur: root.blurImage
            }
        }
    }

    property alias mouseArea: mouseArea
    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        onClicked: {
            GlobalStates.sidebarLeftOpen = false
            root.itemExecute()
        }
    }

    Component { id: iconImageComponent; IconImage { source: Quickshell.iconPath(root.iconName, "image-missing"); width: 24; height: 24 } }
    Component { id: materialSymbolComponent; MaterialSymbol { text: root.materialSymbol; iconSize: 24; color: Appearance.colors.colPrimary } }
    Component { id: bigTextComponent; StyledText { text: root.bigText; font.pixelSize: 20; color: Appearance.colors.colPrimary } }
}