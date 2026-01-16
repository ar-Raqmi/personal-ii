import QtQuick
import Quickshell
import qs.services
import qs

QtObject {
    id: root

    property Connections sidebarConnections: Connections {
        target: GlobalStates
        
        function onSidebarLeftOpenChanged() {
            if (GlobalStates.sidebarLeftOpen) {
                GlobalStates.sidebarRightOpen = false;
                GlobalStates.overviewOpen = false;
            }
        }

        function onSidebarRightOpenChanged() {
            if (GlobalStates.sidebarRightOpen) {
                GlobalStates.sidebarLeftOpen = false;
                GlobalStates.overviewOpen = false;
                Notifications.timeoutAll();
                Notifications.markAllRead();
            }
        }

        function onOverviewOpenChanged() {
            if (GlobalStates.overviewOpen) {
                GlobalStates.sidebarLeftOpen = false;
                GlobalStates.sidebarRightOpen = false;
            }
        }
    }
}
