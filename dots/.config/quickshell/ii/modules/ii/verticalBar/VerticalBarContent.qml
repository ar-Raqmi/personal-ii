import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Bluetooth
import Quickshell.Services.UPower
import Quickshell.Services.Mpris
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import qs.modules.ii.bar as Bar
import qs.modules.ii.verticalBar

Item { // Bar content region
    id: root

    property var screen: root.QsWindow.window?.screen
    property var brightnessMonitor: Brightness.getMonitorForScreen(screen)
    property MprisPlayer activePlayer: MprisController.activePlayer

    component HorizontalBarSeparator: Rectangle {
        Layout.leftMargin: Appearance.sizes.baseBarHeight / 3
        Layout.rightMargin: Appearance.sizes.baseBarHeight / 3
        Layout.fillWidth: true
        implicitHeight: 1
        color: Appearance.colors.colOutlineVariant
    }

    // Background
    Rectangle {
        id: barBackground
        anchors {
            fill: parent
            margins: Config.options.bar.cornerStyle === 1 ? (Appearance.sizes.hyprlandGapsOut) : 0
        }
        color: Config.options.bar.showBackground ? Appearance.colors.colLayer0 : "transparent"
        radius: Config.options.bar.cornerStyle === 1 ? Appearance.rounding.windowRounding : 0
        border.width: Config.options.bar.cornerStyle === 1 ? 1 : 0
        border.color: Appearance.colors.colLayer0Border
    }

    // Top Section
    ColumnLayout {
        id: topSection
        anchors {
            top: parent.top
            left: parent.left
            right: parent.right
            bottom: clockSection.top
            topMargin: Config.options.bar.cornerStyle === 1 ? Appearance.sizes.hyprlandGapsOut : 0
        }
        spacing: 0

        Bar.LeftSidebarButton {
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: 10
            colBackground: topSectionScrollArea.hovered ? Appearance.colors.colLayer1Hover : ColorUtils.transparentize(Appearance.colors.colLayer1Hover, 1)
        }

        RippleButton {
            id: overviewButton
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: 10
            implicitWidth: 36
            implicitHeight: 36
            buttonRadius: Appearance.rounding.full
            colBackground: topSectionScrollArea.hovered ? Appearance.colors.colLayer1Hover : ColorUtils.transparentize(Appearance.colors.colLayer1Hover, 1)
            colBackgroundHover: Appearance.colors.colLayer1Hover
            colRipple: Appearance.colors.colLayer1Active
            colBackgroundToggled: Appearance.colors.colSecondaryContainer
            colBackgroundToggledHover: Appearance.colors.colSecondaryContainerHover
            colRippleToggled: Appearance.colors.colSecondaryContainerActive
            toggled: GlobalStates.overviewOpen
            onPressed: GlobalStates.overviewOpen = !GlobalStates.overviewOpen
            
            property color colIcon: toggled ? Appearance.m3colors.m3onSecondaryContainer : Appearance.colors.colOnLayer0
            Behavior on colIcon {
                animation: Appearance.animation.elementMoveFast.colorAnimation.createObject(this)
            }

            MaterialSymbol {
                anchors.centerIn: parent
                text: "grid_view"
                iconSize: 24
                color: overviewButton.colIcon
            }
        }

        StyledFlickable {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.topMargin: 10
            contentHeight: topContentColumn.implicitHeight
            interactive: contentHeight > height
            clip: true

            ColumnLayout {
                id: topContentColumn
                width: parent.width
                spacing: 10

                Bar.Workspaces {
                    vertical: true
                    workspaceButtonWidth: 32
                    Layout.alignment: Qt.AlignHCenter
                }
            }
        }
    }

    // Centered Clock Section
    Column {
        id: clockSection
        anchors.centerIn: parent
        spacing: 2
        z: 10

        Bar.BarGroup {
            vertical: true
            padding: 8
            visible: activePlayer !== null
            width: Appearance.sizes.verticalBarWidth - 8
            VerticalMedia {
                Layout.fillWidth: true
            }
        }

        Bar.BarGroup {
            vertical: true
            padding: 8
            width: Appearance.sizes.verticalBarWidth - 8

            VerticalClockWidget {
                Layout.alignment: Qt.AlignHCenter
                Layout.fillWidth: true
            }

            HorizontalBarSeparator {}

            VerticalDateWidget {
                Layout.alignment: Qt.AlignHCenter
                Layout.fillWidth: true
            }
        }
    }

    // Bottom Section
    ColumnLayout {
        id: bottomSection
        anchors {
            top: clockSection.bottom
            bottom: parent.bottom
            left: parent.left
            right: parent.right
            bottomMargin: Config.options.bar.cornerStyle === 1 ? Appearance.sizes.hyprlandGapsOut : 0
        }
        spacing: 0

        StyledFlickable {
            Layout.fillWidth: true
            Layout.fillHeight: true
            contentHeight: bottomContentColumn.implicitHeight
            interactive: contentHeight > height
            clip: true

            ColumnLayout {
                id: bottomContentColumn
                width: parent.width
                spacing: 2

                Bar.BarGroup {
                    vertical: true
                    padding: 4
                    visible: Config.options.bar.verbose
                    Layout.alignment: Qt.AlignHCenter
                    VerticalUtilButtons {
                        Layout.fillWidth: true
                    }
                }

                Bar.BarGroup {
                    vertical: true
                    padding: 4
                    visible: Config.options.bar.weather.enable
                    Layout.alignment: Qt.AlignHCenter
                    VerticalWeatherWidget {
                        Layout.fillWidth: true
                    }
                }

                Bar.BarGroup {
                    vertical: true
                    padding: 4
                    visible: Battery.available
                    Layout.alignment: Qt.AlignHCenter
                    BatteryIndicator {
                        Layout.fillWidth: true
                    }
                }
            }
        }

        Bar.SysTray {
            vertical: true
            Layout.fillWidth: true
            Layout.topMargin: 4
            invertSide: Config?.options.bar.bottom
        }

        RippleButton {
            id: rightSidebarButton
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: 4
            Layout.bottomMargin: 10
            implicitWidth: indicatorsColumnLayout.implicitWidth + 12
            implicitHeight: indicatorsColumnLayout.implicitHeight + 8
            buttonRadius: Appearance.rounding.full
            
            colBackground: bottomSectionScrollArea.hovered ? Appearance.colors.colLayer1Hover : ColorUtils.transparentize(Appearance.colors.colLayer1Hover, 1)
            colBackgroundHover: Appearance.colors.colLayer1Hover
            colRipple: Appearance.colors.colLayer1Active
            colBackgroundToggled: Appearance.colors.colSecondaryContainer
            colBackgroundToggledHover: Appearance.colors.colSecondaryContainerHover
            colRippleToggled: Appearance.colors.colSecondaryContainerActive
            toggled: GlobalStates.sidebarRightOpen
            onPressed: GlobalStates.sidebarRightOpen = !GlobalStates.sidebarRightOpen
            
            property color colText: toggled ? Appearance.m3colors.m3onSecondaryContainer : Appearance.colors.colOnLayer0
            Behavior on colText {
                animation: Appearance.animation.elementMoveFast.colorAnimation.createObject(this)
            }

            ColumnLayout {
                id: indicatorsColumnLayout
                anchors.centerIn: parent
                property real realSpacing: 6
                spacing: 0

                Revealer {
                    vertical: true
                    reveal: Audio.sink?.audio?.muted ?? false
                    Layout.fillWidth: true
                    Layout.bottomMargin: reveal ? indicatorsColumnLayout.realSpacing : 0
                    Behavior on Layout.bottomMargin {
                        animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
                    }
                    MaterialSymbol {
                        text: "volume_off"
                        iconSize: Appearance.font.pixelSize.larger
                        color: rightSidebarButton.colText
                    }
                }
                Revealer {
                    vertical: true
                    reveal: Audio.source?.audio?.muted ?? false
                    Layout.fillWidth: true
                    Layout.bottomMargin: reveal ? indicatorsColumnLayout.realSpacing : 0
                    MaterialSymbol {
                        text: "mic_off"
                        iconSize: Appearance.font.pixelSize.larger
                        color: rightSidebarButton.colText
                    }
                }
                Bar.HyprlandXkbIndicator {
                    vertical: true
                    Layout.alignment: Qt.AlignHCenter
                    Layout.bottomMargin: indicatorsColumnLayout.realSpacing
                    color: rightSidebarButton.colText
                }
                Revealer {
                    vertical: true
                    reveal: Notifications.silent || Notifications.unread > 0
                    Layout.fillWidth: true
                    Layout.bottomMargin: reveal ? indicatorsColumnLayout.realSpacing : 0
                    implicitHeight: reveal ? notificationUnreadCount.implicitHeight : 0
                    implicitWidth: reveal ? notificationUnreadCount.implicitWidth : 0
                    Behavior on Layout.bottomMargin {
                        animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
                    }
                    Bar.NotificationUnreadCount {
                        id: notificationUnreadCount
                    }
                }
                MaterialSymbol {
                    text: Network.materialSymbol
                    iconSize: Appearance.font.pixelSize.larger
                    color: rightSidebarButton.colText
                }
                MaterialSymbol {
                    Layout.topMargin: indicatorsColumnLayout.realSpacing
                    visible: BluetoothStatus.available && BluetoothStatus.enabled
                    text: BluetoothStatus.connected ? "bluetooth_connected" : "bluetooth"
                    iconSize: Appearance.font.pixelSize.larger
                    color: rightSidebarButton.colText
                }
                MaterialSymbol {
                    Layout.topMargin: indicatorsColumnLayout.realSpacing
                    visible: BluetoothStatus.available && !BluetoothStatus.enabled
                    text: "bluetooth_disabled"
                    iconSize: Appearance.font.pixelSize.larger
                    color: rightSidebarButton.colText
                }
            }
        }
    }

    // Scroll areas for brightness/volume (overlaying the sections)
    FocusedScrollMouseArea {
        id: topSectionScrollArea
        anchors.top: parent.top
        anchors.bottom: clockSection.verticalCenter
        width: parent.width
        onScrollDown: root.brightnessMonitor.setBrightness(root.brightnessMonitor.brightness - 0.05)
        onScrollUp: root.brightnessMonitor.setBrightness(root.brightnessMonitor.brightness + 0.05)
        onPressed: event => { if (event.button === Qt.LeftButton) GlobalStates.sidebarLeftOpen = !GlobalStates.sidebarLeftOpen; }
        z: -1
    }

    FocusedScrollMouseArea {
        id: bottomSectionScrollArea
        anchors.top: clockSection.verticalCenter
        anchors.bottom: parent.bottom
        width: parent.width
        onScrollDown: Audio.decrementVolume();
        onScrollUp: Audio.incrementVolume();
        onPressed: event => { if (event.button === Qt.LeftButton) GlobalStates.sidebarRightOpen = !GlobalStates.sidebarRightOpen; }
        z: -1
    }
}
