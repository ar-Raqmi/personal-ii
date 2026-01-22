import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import Qt.labs.synchronizer

FocusScope {
    id: root
    required property var scopeRoot
    property int sidebarPadding: 10
    anchors.fill: parent
    property bool aiChatEnabled: Config.options.policies.ai !== 0
    property bool translatorEnabled: Config.options.sidebar.translator.enable
    property bool animeEnabled: Config.options.policies.weeb !== 0
    property bool animeCloset: Config.options.policies.weeb === 2
    property var tabButtonList: [
        {"icon": "apps", "name": Translation.tr("Apps")},
        ...(root.aiChatEnabled ? [{"icon": "neurology", "name": Translation.tr("Intelligence")}] : []),
        ...(root.translatorEnabled ? [{"icon": "translate", "name": Translation.tr("Translator")}] : []),
        ...((root.animeEnabled && !root.animeCloset) ? [{"icon": "bookmark_heart", "name": Translation.tr("Anime")}] : [])
    ]
    property int tabCount: swipeView.count

    Component.onCompleted: {
        // Initial setup based on requested tab
        tabBar.currentIndex = 0;
    }

    Connections {
        target: GlobalStates
        function onSidebarRequestedTabChanged() {
            if (GlobalStates.sidebarRequestedTab === "") {
                tabBar.currentIndex = 0;
            }
        }
        function onSidebarLeftOpenChanged() {
            if (!GlobalStates.sidebarLeftOpen) {
                // Visual reset
                tabBar.currentIndex = 0;
            } else {
                tabBar.currentIndex = 0;
            }
        }
    }

    function focusActiveItem() {
        if (swipeView.currentItem) {
            swipeView.currentItem.forceActiveFocus();
        }
    }

    Keys.onPressed: (event) => {
        if (event.key === Qt.Key_Tab) {
            if (event.modifiers === Qt.ShiftModifier) {
                tabBar.decrementCurrentIndex();
            } else {
                tabBar.incrementCurrentIndex();
            }
            event.accepted = true;
        } else if (event.modifiers === Qt.ControlModifier) {
            if (event.key === Qt.Key_PageDown) {
                tabBar.incrementCurrentIndex();
                event.accepted = true;
            }
            else if (event.key === Qt.Key_PageUp) {
                tabBar.decrementCurrentIndex();
                event.accepted = true;
            }
        }
    }

    ColumnLayout {
        anchors {
            fill: parent
            margins: sidebarPadding
        }
        spacing: sidebarPadding

        Toolbar {
            visible: tabButtonList.length > 0
            Layout.alignment: Qt.AlignHCenter
            enableShadow: false
            ToolbarTabBar {
                id: tabBar
                Layout.alignment: Qt.AlignHCenter
                tabButtonList: root.tabButtonList
                // Bidirectional sync
                onCurrentIndexChanged: {
                    if (swipeView.currentIndex !== currentIndex) {
                        swipeView.currentIndex = currentIndex;
                    }
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            implicitWidth: swipeView.implicitWidth
            implicitHeight: swipeView.implicitHeight
            radius: Appearance.rounding.normal
            color: "transparent"

            SwipeView { // Content pages
                id: swipeView
                anchors.fill: parent
                spacing: 10
                currentIndex: tabBar.currentIndex
                onCurrentIndexChanged: {
                    if (tabBar.currentIndex !== currentIndex) {
                        tabBar.currentIndex = currentIndex;
                    }
                    root.focusActiveItem();
                }

                clip: true
                layer.enabled: true
                layer.effect: OpacityMask {
                    maskSource: Rectangle {
                        width: swipeView.width
                        height: swipeView.height
                        radius: Appearance.rounding.small
                    }
                }

                contentChildren: [
                    appDrawer.createObject(),
                    ...((root.aiChatEnabled || (!root.translatorEnabled && !root.animeEnabled)) ? [aiChat.createObject()] : []),
                    ...(root.translatorEnabled ? [translator.createObject()] : []),
                    ...((root.tabButtonList.length === 0 || (!root.aiChatEnabled && !root.translatorEnabled && root.animeCloset)) ? [placeholder.createObject()] : []),
                    ...(root.animeEnabled ? [anime.createObject()] : []),
                ]
            }
        }

        Component {
            id: appDrawer
            AppDrawer {
                focus: swipeView.currentIndex === 0
            }
        }
        Component {
            id: aiChat
            AiChat {}
        }
        Component {
            id: translator
            Translator {}
        }
        Component {
            id: anime
            Anime {}
        }
        Component {
            id: placeholder
            Item {
                StyledText {
                    anchors.centerIn: parent
                    text: root.animeCloset ? Translation.tr("Nothing") : Translation.tr("Enjoy your empty sidebar...")
                    color: Appearance.colors.colSubtext
                }
            }
        }
    }
}