import qs
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import qs.services
import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.modules.ii.sidebarLeft

FocusScope {
    id: root
    
    property string searchingText: LauncherSearch.query
    property bool showResults: searchingText != ""

    enum SearchPrefixType { Math, ShellCommand, WebSearch, Clipboard, Emojis, DefaultSearch }

    property int searchPrefixType: {
        if (root.searchingText.startsWith(Config.options.search.prefix.math)) return CenterWidgetGroup.Math;
        if (root.searchingText.startsWith(Config.options.search.prefix.shellCommand)) return CenterWidgetGroup.ShellCommand;
        if (root.searchingText.startsWith(Config.options.search.prefix.webSearch)) return CenterWidgetGroup.WebSearch;
        if (root.searchingText.startsWith(Config.options.search.prefix.clipboard)) return CenterWidgetGroup.Clipboard;
        if (root.searchingText.startsWith(Config.options.search.prefix.emojis)) return CenterWidgetGroup.Emojis;
        return CenterWidgetGroup.DefaultSearch;
    }

    Component.onCompleted: {
        if (GlobalStates.sidebarSearchText !== "") {
            searchInput.text = GlobalStates.sidebarSearchText;
            LauncherSearch.query = GlobalStates.sidebarSearchText;
        }
        focusGrabTimer.restart();
    }

    Rectangle {
        id: background
        anchors.fill: parent
        radius: Appearance.rounding.normal
        color: Appearance.colors.colLayer1
        border.width: 1
        border.color: Appearance.colors.colLayer0Border

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 5
            spacing: 5

            // Search Bar
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 50
                color: Appearance.colors.colLayer2
                radius: Appearance.rounding.normal
                border.width: 1
                border.color: Appearance.colors.colLayer0Border

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 10
                    spacing: 10

                    MaterialShapeWrappedMaterialSymbol {
                        id: searchIcon
                        Layout.alignment: Qt.AlignVCenter
                        iconSize: Appearance.font.pixelSize.large
                        color: Appearance.colors.colPrimary
                        colSymbol: Appearance.colors.colOnPrimary
                        shape: {
                            switch(root.searchPrefixType) {
                                case CenterWidgetGroup.Math: return MaterialShape.Shape.PuffyDiamond;
                                case CenterWidgetGroup.ShellCommand: return MaterialShape.Shape.PixelCircle;
                                case CenterWidgetGroup.WebSearch: return MaterialShape.Shape.SoftBurst;
                                case CenterWidgetGroup.Clipboard: return MaterialShape.Shape.Gem;
                                case CenterWidgetGroup.Emojis: return MaterialShape.Shape.Sunny;
                                default: return MaterialShape.Shape.Cookie7Sided;
                            }
                        }
                        text: {
                            switch (root.searchPrefixType) {
                                case CenterWidgetGroup.Math: return "calculate";
                                case CenterWidgetGroup.ShellCommand: return "terminal";
                                case CenterWidgetGroup.WebSearch: return "travel_explore";
                                case CenterWidgetGroup.Clipboard: return "content_paste_search";
                                case CenterWidgetGroup.Emojis: return "add_reaction";
                                default: return "search";
                            }
                        }
                    }

                    TextInput {
                        id: searchInput
                        Layout.fillWidth: true
                        focus: true
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
                        
                        onTextChanged: {
                            GlobalStates.sidebarSearchText = text;
                            LauncherSearch.query = text;
                        }

                        Connections {
                            target: GlobalStates
                            function onSidebarSearchTextChanged() {
                                if (searchInput.text !== GlobalStates.sidebarSearchText) {
                                    searchInput.text = GlobalStates.sidebarSearchText;
                                    LauncherSearch.query = GlobalStates.sidebarSearchText;
                                    focusGrabTimer.restart();
                                }
                            }
                        }

                        Timer {
                            id: focusGrabTimer
                            interval: 10
                            onTriggered: {
                                searchInput.forceActiveFocus();
                                searchInput.cursorPosition = searchInput.text.length;
                            }
                        }

                        Keys.onPressed: (event) => {
                            if (resultsList.count > 0) {
                                if (event.key === Qt.Key_Down) {
                                    resultsList.incrementCurrentIndex();
                                    event.accepted = true;
                                } else if (event.key === Qt.Key_Up) {
                                    resultsList.decrementCurrentIndex();
                                    event.accepted = true;
                                } else if (event.key === Qt.Key_Left || event.key === Qt.Key_Right) {
                                    event.accepted = true;
                                } else if (event.key === Qt.Key_Enter || event.key === Qt.Key_Return) {
                                    let firstItem = resultsList.itemAtIndex(resultsList.currentIndex);
                                    if (firstItem && firstItem.mouseArea) {
                                        firstItem.mouseArea.clicked(null);
                                    }
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

            // Results List
            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true

                ListView {
                    id: resultsList
                    anchors.fill: parent
                    visible: root.showResults
                    clip: true
                    spacing: 2
                    highlightMoveDuration: Appearance.animation.elementMove.duration
                    keyNavigationEnabled: true
                    
                    model: ScriptModel {
                        id: resultModel
                        values: []
                    }
                    
                    delegate: SearchItem {
                        id: searchItemDelegate
                        required property int index
                        required property var modelData
                        width: ListView.view.width
                        entry: modelData
                        query: StringUtils.cleanOnePrefix(GlobalStates.sidebarSearchText, [Config.options.search.prefix.action, Config.options.search.prefix.app, Config.options.search.prefix.clipboard, Config.options.search.prefix.emojis, Config.options.search.prefix.math, Config.options.search.prefix.shellCommand, Config.options.search.prefix.webSearch])
                        highlighted: resultsList.currentIndex === index
                        
                        // Animation from overview
                        opacity: 0
                        scale: 0.95
                        Component.onCompleted: {
                            enterAnim.start()
                        }
                        ParallelAnimation {
                            id: enterAnim
                            NumberAnimation { target: searchItemDelegate; property: "opacity"; from: 0; to: 1; duration: 200 }
                            NumberAnimation { target: searchItemDelegate; property: "scale"; from: 0.95; to: 1; duration: 200; easing.type: Easing.OutCubic }
                        }
                    }

                    Keys.onPressed: (event) => {
                        if (event.key === Qt.Key_Up && resultsList.currentIndex === 0) {
                            searchInput.forceActiveFocus();
                            event.accepted = true;
                        } else if (event.key === Qt.Key_Left || event.key === Qt.Key_Right) {
                            event.accepted = true;
                        } else if (event.key === Qt.Key_Enter || event.key === Qt.Key_Return) {
                            let currentItem = resultsList.currentItem;
                            if (currentItem && currentItem.mouseArea) {
                                currentItem.mouseArea.clicked(null);
                            }
                            event.accepted = true;
                        } else if (event.text !== "" && event.modifiers === Qt.NoModifier && 
                                   event.key !== Qt.Key_Escape && event.key !== Qt.Key_Backtab && 
                                   event.key !== Qt.Key_Tab) {
                            searchInput.forceActiveFocus();
                            searchInput.text += event.text;
                            event.accepted = true;
                        }
                    }

                    Connections {
                        target: LauncherSearch
                        function onResultsChanged() {
                            let allResults = LauncherSearch.results;
                            let filtered = [];
                            for (let i = 0; i < allResults.length; i++) {
                                let item = allResults[i];
                                if (item && item.type !== Translation.tr("App")) {
                                    filtered.push(item);
                                }
                            }
                            resultModel.values = filtered;
                        }
                    }
                }

                // Placeholder
                ColumnLayout {
                    anchors.centerIn: parent
                    visible: !root.showResults
                    spacing: 10
                    opacity: 0.3

                    MaterialSymbol {
                        Layout.alignment: Qt.AlignHCenter
                        text: "search_insights"
                        iconSize: 48
                        color: Appearance.colors.colOnLayer1
                    }
                    StyledText {
                        Layout.alignment: Qt.AlignHCenter
                        font.pixelSize: Appearance.font.pixelSize.large
                        color: Appearance.colors.colOnLayer1
                    }
                }
            }
        }
    }
}
