import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Bluetooth
import Quickshell.Hyprland
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

    // Top Section — Logo, Overview, Workspaces (fills remaining space)
    ColumnLayout {
        id: topSection
        anchors {
            top: parent.top
            left: parent.left
            right: parent.right
            bottom: bottomSection.top
            topMargin: Config.options.bar.cornerStyle === 1 ? Appearance.sizes.hyprlandGapsOut : 0
        }
        spacing: 0

        Bar.LeftSidebarButton {
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: 10
            colBackground: ColorUtils.transparentize(Appearance.colors.colLayer1Hover, 1)
        }

        RippleButton {
            id: overviewButton
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: 10
            implicitWidth: 36
            implicitHeight: 36
            buttonRadius: Appearance.rounding.full
            colBackground: ColorUtils.transparentize(Appearance.colors.colLayer1Hover, 1)
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

    // Bottom Section — anchored to bottom, grows upward
    // Order (top→bottom): SysTray, Utils+Weather, Status+Media, Battery, Date, Time
    ColumnLayout {
        id: bottomSection
        anchors {
            bottom: parent.bottom
            left: parent.left
            right: parent.right
            bottomMargin: Config.options.bar.cornerStyle === 1 ? Appearance.sizes.hyprlandGapsOut : 0
        }
        spacing: 2

        Bar.SysTray {
            vertical: true
            Layout.fillWidth: true
            invertSide: Config?.options.bar.bottom
        }

        Bar.BarGroup {
            vertical: true
            padding: 4
            visible: Config.options.bar.verbose || Config.options.bar.weather.enable
            Layout.alignment: Qt.AlignHCenter

            VerticalUtilButtons {
                visible: Config.options.bar.verbose
                Layout.fillWidth: true
            }

            VerticalWeatherWidget {
                visible: Config.options.bar.weather.enable
                Layout.fillWidth: true
            }
        }

        Bar.BarGroup {
            vertical: true
            padding: 8
            Layout.bottomMargin: 10
            width: Appearance.sizes.verticalBarWidth - 8

            // Media player (visible only when active)
            VerticalMedia {
                visible: activePlayer !== null
                Layout.fillWidth: true
            }

            HorizontalBarSeparator {
                visible: activePlayer !== null
            }

            // Status indicators — same design language as clock/date
            ColumnLayout {
                Layout.alignment: Qt.AlignHCenter
                spacing: 4

                MaterialSymbol {
                    Layout.alignment: Qt.AlignHCenter
                    text: Network.materialSymbol
                    iconSize: Appearance.font.pixelSize.large
                    color: Appearance.colors.colOnLayer1
                }

                MaterialSymbol {
                    Layout.alignment: Qt.AlignHCenter
                    visible: BluetoothStatus.available && BluetoothStatus.enabled
                    text: BluetoothStatus.connected ? "bluetooth_connected" : "bluetooth"
                    iconSize: Appearance.font.pixelSize.large
                    color: Appearance.colors.colOnLayer1
                }

                MaterialSymbol {
                    Layout.alignment: Qt.AlignHCenter
                    visible: BluetoothStatus.available && !BluetoothStatus.enabled
                    text: "bluetooth_disabled"
                    iconSize: Appearance.font.pixelSize.large
                    color: Appearance.colors.colOnLayer1
                }

                Revealer {
                    vertical: true
                    reveal: Audio.sink?.audio?.muted ?? false
                    Layout.fillWidth: true
                    MaterialSymbol {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: "volume_off"
                        iconSize: Appearance.font.pixelSize.large
                        color: Appearance.colors.colOnLayer1
                    }
                }

                Revealer {
                    vertical: true
                    reveal: Audio.source?.audio?.muted ?? false
                    Layout.fillWidth: true
                    MaterialSymbol {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: "mic_off"
                        iconSize: Appearance.font.pixelSize.large
                        color: Appearance.colors.colOnLayer1
                    }
                }

                Revealer {
                    vertical: true
                    reveal: Notifications.silent
                    Layout.fillWidth: true
                    MaterialSymbol {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: "do_not_disturb_on"
                        iconSize: Appearance.font.pixelSize.large
                        color: Appearance.colors.colOnLayer1
                    }
                }
            }

            HorizontalBarSeparator {}

            BatteryIndicator {
                visible: Battery.available
                Layout.fillWidth: true
            }

            HorizontalBarSeparator {
                visible: Battery.available
            }

            Item {
                Layout.fillWidth: true
                implicitHeight: dateClockColumn.implicitHeight

                ColumnLayout {
                    id: dateClockColumn
                    anchors.fill: parent
                    spacing: 9

                    VerticalDateWidget {
                        Layout.alignment: Qt.AlignHCenter
                        Layout.fillWidth: true
                    }

                    HorizontalBarSeparator {}

                    VerticalClockWidget {
                        Layout.alignment: Qt.AlignHCenter
                        Layout.fillWidth: true
                    }
                }

                MouseArea {
                    id: dateClockMouseArea
                    anchors.fill: parent
                    acceptedButtons: Qt.NoButton
                    hoverEnabled: true
                    propagateComposedEvents: true

                    Bar.ClockWidgetPopup {
                        hoverTarget: dateClockMouseArea
                    }
                }
            }
        }
    }

    // Workspace scroll — entire bar
    WheelHandler {
        onWheel: (event) => {
            if (event.angleDelta.y < 0)
                Hyprland.dispatch(`workspace r+1`);
            else if (event.angleDelta.y > 0)
                Hyprland.dispatch(`workspace r-1`);
        }
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
    }

    // Top 50% click → left sidebar
    MouseArea {
        anchors.top: parent.top
        anchors.bottom: parent.verticalCenter
        width: parent.width
        acceptedButtons: Qt.LeftButton
        onClicked: GlobalStates.sidebarLeftOpen = !GlobalStates.sidebarLeftOpen
        z: -1
    }

    // Bottom 50% click → right sidebar
    MouseArea {
        anchors.top: parent.verticalCenter
        anchors.bottom: parent.bottom
        width: parent.width
        acceptedButtons: Qt.LeftButton
        onClicked: GlobalStates.sidebarRightOpen = !GlobalStates.sidebarRightOpen
        z: -1
    }
}
