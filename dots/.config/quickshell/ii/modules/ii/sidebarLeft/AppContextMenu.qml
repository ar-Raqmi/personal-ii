import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell

Item {
    id: root
    anchors.fill: parent
    visible: opacity > 0
    opacity: 0

    property var modelData: null
    property point menuPoint: Qt.point(0, 0)

    signal menuClosed
    signal menuOpened

    function open(app, pos) {
        root.modelData = app;
        
        const margin = 12;
        const menuWidth = menuSurface.width;
        const menuHeight = layout.implicitHeight + 16;
        
        let x = pos.x;
        let y = pos.y;
        
        if (x + menuWidth + margin > root.width) {
            x = pos.x - menuWidth;
        }
        
        if (y + menuHeight + margin > root.height) {
            y = pos.y - menuHeight;
        }
        
        x = Math.max(margin, Math.min(x, root.width - menuWidth - margin));
        y = Math.max(margin, Math.min(y, root.height - menuHeight - margin));
        
        root.menuPoint = Qt.point(x, y);
        
        openAnim.restart();
        root.menuOpened();
    }

    function close() {
        closeAnim.restart();
        root.menuClosed();
    }

    function launchApp(app) {
        if (!app) return;
        GlobalStates.sidebarLeftOpen = false;
        if (!app.runInTerminal) {
            app.execute();
        } else {
             Quickshell.execDetached(["bash", '-c', `${Config.options.apps.terminal} -e '${StringUtils.shellSingleQuoteEscape(app.command.join(' '))}'`]);
        }
    }

    Rectangle {
        id: overlay
        anchors.fill: parent
        color: "black"
        opacity: root.opacity * 0.2 // subtle dim (do I really need this? I don't know I keep here for a while)
        
        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.AllButtons
            hoverEnabled: true
            onPressed: root.close()
            cursorShape: Qt.ArrowCursor
        }
    }

    StyledRectangularShadow {
        anchors.fill: menuSurface
        target: menuSurface
        radius: menuSurface.radius
        opacity: root.opacity
    }

    // Actual Menu
    Rectangle {
        id: menuSurface
        x: root.menuPoint.x
        y: root.menuPoint.y
        width: 160
        height: layout.implicitHeight + 12
        
        color: Appearance.colors.colLayer0
        radius: Appearance.rounding.windowRounding
        border.width: 1
        border.color: Appearance.colors.colLayer0Border
        clip: true
        
        scale: root.opacity > 0 ? 1 : 0.95
        transformOrigin: Item.TopLeft

        ColumnLayout {
            id: layout
            anchors {
                top: parent.top
                left: parent.left
                right: parent.right
                topMargin: 6
                bottomMargin: 6
            }
            spacing: 0

            // Open App (execute from .desktop file)
            RippleButton {
                Layout.fillWidth: true
                Layout.leftMargin: 6
                Layout.rightMargin: 6
                horizontalPadding: 12
                implicitHeight: 32
                buttonRadius: Appearance.rounding.small
                
                onClicked: {
                    root.launchApp(root.modelData);
                    root.close();
                }

                contentItem: StyledText {
                    text: Translation.tr("Open Application")
                    font.weight: Font.DemiBold
                    font.pixelSize: Appearance.font.pixelSize.small
                    color: Appearance.colors.colOnLayer0
                    verticalAlignment: Text.AlignVCenter
                }
            }

            Rectangle {
                visible: (root.modelData?.actions?.length ?? 0) > 0
                Layout.fillWidth: true
                Layout.topMargin: 4
                Layout.bottomMargin: 4
                height: 1
                color: Appearance.colors.colLayer0Border
                opacity: 0.3
            }

            // Desktop Actions (extra stuff like New Window and such)
            Repeater {
                model: root.modelData?.actions ?? []
                delegate: RippleButton {
                    Layout.fillWidth: true
                    Layout.leftMargin: 6
                    Layout.rightMargin: 6
                    horizontalPadding: 12
                    implicitHeight: 28
                    buttonRadius: Appearance.rounding.small

                    onClicked: {
                        modelData.execute();
                        root.close();
                        GlobalStates.sidebarLeftOpen = false;
                    }

                    contentItem: StyledText {
                        Layout.fillWidth: true
                        text: modelData.name
                        font.pixelSize: 11
                        elide: Text.ElideRight
                        color: Appearance.colors.colOnLayer0
                        verticalAlignment: Text.AlignVCenter
                    }
                }
            }
        }
    }

    ParallelAnimation {
        id: openAnim
        NumberAnimation {
            target: root
            property: "opacity"
            from: 0
            to: 1
            duration: 150
            easing.type: Easing.OutCubic
        }
        NumberAnimation {
            target: menuSurface
            property: "scale"
            from: 0.95
            to: 1
            duration: 200
            easing.type: Easing.OutBack
        }
    }

    ParallelAnimation {
        id: closeAnim
        NumberAnimation {
            target: root
            property: "opacity"
            from: 1
            to: 0
            duration: 100
            easing.type: Easing.InQuad
        }
        NumberAnimation {
            target: menuSurface
            property: "scale"
            from: 1
            to: 0.98
            duration: 100
            easing.type: Easing.InQuad
        }
    }
}
