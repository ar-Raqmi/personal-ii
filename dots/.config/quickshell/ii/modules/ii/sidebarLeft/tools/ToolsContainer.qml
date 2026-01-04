import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Bluetooth
import Quickshell.Hyprland

import qs.modules.ii.sidebarRight.quickToggles
import qs.modules.ii.sidebarRight.quickToggles.classicStyle

FocusScope {
    id: root
    property int sidebarPadding: 10
    
    ColumnLayout {
        anchors.fill: parent
        anchors.margins: sidebarPadding
        spacing: sidebarPadding

        // Workflow Toggles in Classic Style
        Rectangle {
            id: workflowPanel
            Layout.alignment: Qt.AlignHCenter
            radius: Appearance.rounding.normal
            color: Appearance.colors.colLayer1
            implicitWidth: workflowButtons.implicitWidth
            implicitHeight: workflowButtons.implicitHeight

            ButtonGroup {
                id: workflowButtons
                spacing: 5
                padding: 5
                color: "transparent"

                QuickToggleButton {
                    buttonIcon: "image_search"
                    onClicked: { 
                        GlobalStates.sidebarLeftOpen = false; 
                        Quickshell.execDetached(["qs", "-p", Quickshell.shellPath(""), "ipc", "call", "region", "search"]); 
                    }
                    StyledToolTip { text: Translation.tr("Google Lens") }
                }
                QuickToggleButton {
                    buttonIcon: "music_cast"
                    toggled: SongRec.running
                    onClicked: SongRec.toggleRunning()
                    StyledToolTip { text: Translation.tr("Music Recognition") }
                }
                QuickToggleButton {
                    buttonIcon: "content_copy"
                    onClicked: { 
                        GlobalStates.sidebarSearchText = Config.options.search.prefix.clipboard;
                    }
                    StyledToolTip { text: Translation.tr("Clipboard History") }
                }
                QuickToggleButton {
                    buttonIcon: "add_reaction"
                    onClicked: { 
                        GlobalStates.sidebarSearchText = Config.options.search.prefix.emojis; 
                    }
                    StyledToolTip { text: Translation.tr("Emojis") }
                }
            }
        }

        CenterWidgetGroup {
            Layout.alignment: Qt.AlignHCenter
            Layout.fillHeight: true
            Layout.fillWidth: true
        }

        BottomWidgetGroup {
            Layout.alignment: Qt.AlignHCenter
            Layout.fillHeight: false
            Layout.fillWidth: true
            Layout.preferredHeight: implicitHeight
        }
    }
}