import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import Qt.labs.synchronizer
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland

Scope {
    id: searchScope
    property bool dontAutoCancelSearch: false

    PanelWindow {
        id: panelWindow
        property string searchingText: ""
        readonly property HyprlandMonitor monitor: Hyprland.monitorFor(panelWindow.screen)
        property bool monitorIsFocused: (Hyprland.focusedMonitor?.id == monitor?.id)
        visible: GlobalStates.searchOpen
        WlrLayershell.keyboardFocus: GlobalStates.searchOpen ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

        WlrLayershell.namespace: "quickshell:search"
        WlrLayershell.layer: WlrLayer.Top
        color: "transparent"

        mask: Region {
            item: GlobalStates.searchOpen ? columnLayout : null
        }

        anchors {
            top: true
            bottom: true
            left: true
            right: true
        }

        Connections {
            target: GlobalStates
            function onSearchOpenChanged() {
                if (!GlobalStates.searchOpen) {
                    searchWidget.disableExpandAnimation();
                    searchScope.dontAutoCancelSearch = false;
                    GlobalFocusGrab.dismiss();
                } else {
                    if (!searchScope.dontAutoCancelSearch) {
                        searchWidget.cancelSearch();
                    }
                    GlobalFocusGrab.addDismissable(panelWindow);
                }
            }
        }

        Connections {
            target: GlobalFocusGrab
            function onDismissed() {
                GlobalStates.searchOpen = false;
            }
        }
        implicitWidth: columnLayout.implicitWidth
        implicitHeight: columnLayout.implicitHeight

        function setSearchingText(text) {
            searchWidget.setSearchingText(text);
            searchWidget.focusFirstItem();
        }

        Column {
            id: columnLayout
            visible: GlobalStates.searchOpen
            anchors.centerIn: parent
            spacing: -8

            Keys.onPressed: event => {
                if (event.key === Qt.Key_Escape) {
                    GlobalStates.searchOpen = false;
                }
            }

            SearchWidget {
                id: searchWidget
                anchors.horizontalCenter: parent.horizontalCenter
                Synchronizer on searchingText {
                    property alias source: panelWindow.searchingText
                }
            }
        }
    }

    function toggleClipboard() {
        if (GlobalStates.searchOpen && searchScope.dontAutoCancelSearch) {
            GlobalStates.searchOpen = false;
            return;
        }
        searchScope.dontAutoCancelSearch = true;
        panelWindow.setSearchingText(Config.options.search.prefix.clipboard);
        GlobalStates.searchOpen = true;
    }

    function toggleEmojis() {
        if (GlobalStates.searchOpen && searchScope.dontAutoCancelSearch) {
            GlobalStates.searchOpen = false;
            return;
        }
        searchScope.dontAutoCancelSearch = true;
        panelWindow.setSearchingText(Config.options.search.prefix.emojis);
        GlobalStates.searchOpen = true;
    }

    IpcHandler {
        target: "search"

        function toggle() {
            GlobalStates.searchOpen = !GlobalStates.searchOpen;
        }
        function close() {
            GlobalStates.searchOpen = false;
        }
        function open() {
            GlobalStates.searchOpen = true;
        }
        function toggleReleaseInterrupt() {
            GlobalStates.superReleaseMightTrigger = false;
        }
        function clipboardToggle() {
            searchScope.toggleClipboard();
        }
        function emojiToggle() {
            searchScope.toggleEmojis();
        }
    }

    GlobalShortcut {
        name: "searchToggle"
        description: "Toggles search on press"

        onPressed: {
            GlobalStates.searchOpen = !GlobalStates.searchOpen;
        }
    }

    GlobalShortcut {
        name: "searchClipboardToggle"
        description: "Toggle clipboard query on search widget"

        onPressed: {
            searchScope.toggleClipboard();
        }
    }

    GlobalShortcut {
        name: "searchEmojiToggle"
        description: "Toggle emoji query on search widget"

        onPressed: {
            searchScope.toggleEmojis();
        }
    }
}
