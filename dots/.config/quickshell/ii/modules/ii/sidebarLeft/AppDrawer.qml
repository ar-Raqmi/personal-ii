import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets

FocusScope {
    id: root
    // Removed anchors.fill: parent because it's in a SwipeView

    property string query: ""
    
    // Sort applications by name - using slice() to avoid readonly container error
    property var allApps: DesktopEntries.applications.values.slice().sort((a, b) => a.name.localeCompare(b.name))
    property var filteredApps: query === "" ? allApps : allApps.filter(app => 
        app.name.toLowerCase().includes(query.toLowerCase()) || 
        (app.genericName && app.genericName.toLowerCase().includes(query.toLowerCase()))
    )

    function launchApp(app) {
        if (!app) return;
        GlobalStates.sidebarLeftOpen = false
        if (!app.runInTerminal)
            app.execute();
        else {
            Quickshell.execDetached(["bash", '-c', `${Config.options.apps.terminal} -e '${StringUtils.shellSingleQuoteEscape(app.command.join(' '))}'`]);
        }
    }

    onQueryChanged: {
        appGrid.currentIndex = 0
    }

    Connections {
        target: GlobalStates
        function onSidebarLeftOpenChanged() {
            if (GlobalStates.sidebarLeftOpen) {
                searchInput.text = ""
                root.query = ""
                focusTimer.restart();
            }
        }
    }
    
    onActiveFocusChanged: {
        if (activeFocus) {
            focusTimer.restart();
        }
    }

    Timer {
        id: focusTimer
        interval: 10
        onTriggered: searchInput.forceActiveFocus()
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 10
        spacing: 10

        // Search bar for the app drawer
        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 40
            radius: Appearance.rounding.normal
            color: Appearance.colors.colLayer2
            border.color: Appearance.colors.colLayer0Border
            border.width: 1

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 10
                anchors.rightMargin: 10
                spacing: 8

                MaterialSymbol {
                    text: "search"
                    iconSize: 20
                    color: Appearance.colors.colSubtext
                }

                TextInput {
                    id: searchInput
                    Layout.fillWidth: true
                    font.pixelSize: Appearance.font.pixelSize.normal
                    color: Appearance.colors.colOnLayer0
                    selectionColor: Appearance.colors.colPrimary
                    selectedTextColor: Appearance.m3colors.m3onPrimary
                    verticalAlignment: TextInput.AlignVCenter
                    
                    Text {
                        font: parent.font
                        color: Appearance.colors.colSubtext
                        visible: !parent.text && !parent.activeFocus
                    }

                    onTextChanged: root.query = text

                    Keys.onPressed: (event) => {
                        if (appGrid.count > 0) {
                            if (event.key === Qt.Key_Down) {
                                appGrid.moveCurrentIndexDown();
                                event.accepted = true;
                            } else if (event.key === Qt.Key_Up) {
                                appGrid.moveCurrentIndexUp();
                                event.accepted = true;
                            } else if (event.key === Qt.Key_Right) {
                                appGrid.moveCurrentIndexRight();
                                event.accepted = true;
                            } else if (event.key === Qt.Key_Left) {
                                appGrid.moveCurrentIndexLeft();
                                event.accepted = true;
                            } else if (event.key === Qt.Key_Enter || event.key === Qt.Key_Return) {
                                root.launchApp(appGrid.model[appGrid.currentIndex]);
                                event.accepted = true;
                            }
                        }
                    }
                }

                RippleButton {
                    visible: searchInput.text !== ""
                    implicitWidth: 24
                    implicitHeight: 24
                    buttonRadius: Appearance.rounding.full
                    onClicked: {
                        searchInput.text = ""
                        searchInput.forceActiveFocus()
                    }
                    MaterialSymbol {
                        anchors.centerIn: parent
                        text: "close"
                        iconSize: 16
                        color: Appearance.colors.colSubtext
                    }
                }
            }
        }

        GridView {
            id: appGrid
            Layout.fillWidth: true
            Layout.fillHeight: true
            cellWidth: parent.width / 4
            cellHeight: 90
            clip: true
            model: root.filteredApps
            keyNavigationEnabled: true
            highlightMoveDuration: 150
            highlightFollowsCurrentItem: true

            Keys.onPressed: (event) => {
                if (event.key === Qt.Key_Up) {
                    // Navigate to search if in the top row
                    if (appGrid.currentIndex < 4) {
                        searchInput.forceActiveFocus();
                        event.accepted = true;
                    }
                } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                    root.launchApp(appGrid.model[appGrid.currentIndex]);
                    event.accepted = true;
                } else if (event.key === Qt.Key_Backspace) {
                    searchInput.forceActiveFocus();
                    // Move cursor to end and delete
                    searchInput.cursorPosition = searchInput.text.length;
                    searchInput.text = searchInput.text.slice(0, -1);
                    event.accepted = true;
                } else if (event.text !== "" && event.modifiers === Qt.NoModifier && 
                           event.key !== Qt.Key_Escape && event.key !== Qt.Key_Backtab && 
                           event.key !== Qt.Key_Tab) {
                    searchInput.forceActiveFocus();
                    searchInput.text += event.text;
                    event.accepted = true;
                }
            }

            delegate: RippleButton {
                id: appButton
                width: appGrid.cellWidth - 10
                height: appGrid.cellHeight - 10
                buttonRadius: Appearance.rounding.normal
                colBackgroundHover: Appearance.colors.colLayer2Hover
                colRipple: Appearance.colors.colLayer2Active
                highlighted: GridView.isCurrentItem
                
                required property var modelData

                onClicked: root.launchApp(modelData)

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 5
                    spacing: 4

                    IconImage {
                        Layout.alignment: Qt.AlignHCenter
                        source: Quickshell.iconPath(modelData.icon, "image-missing")
                        implicitWidth: 40
                        implicitHeight: 40
                    }

                    StyledText {
                        Layout.fillWidth: true
                        horizontalAlignment: Text.AlignHCenter
                        text: modelData.name
                        font.pixelSize: 11
                        elide: Text.ElideRight
                        color: Appearance.colors.colOnLayer0
                        wrapMode: Text.Wrap
                        maximumLineCount: 2
                    }
                }

                StyledToolTip {
                    text: modelData.comment ?? ""
                    visible: text !== "" && (parent.hovered || appButton.highlighted)
                }
            }
        }
    }
}
