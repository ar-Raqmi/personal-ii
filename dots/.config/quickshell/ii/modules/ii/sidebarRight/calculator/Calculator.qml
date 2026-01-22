import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import qs
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import qs.services

FocusScope {
    id: root
    implicitHeight: 300 
    focus: true
    
    property string displayValue: "0"
    property string previousValue: ""
    property string operation: ""
    property bool newNumber: true

    function handleDigit(digit) {
        if (newNumber) {
            displayValue = digit;
            newNumber = false;
        } else {
            if (displayValue === "0" && digit !== ".") {
                displayValue = digit;
            } else {
                displayValue += digit;
            }
        }
    }

    function handleOperation(op) {
        if (operation !== "" && !newNumber) {
            calculate();
        }
        previousValue = displayValue;
        operation = op;
        newNumber = true;
    }

    function calculate() {
        if (operation === "") return;
        let prev = parseFloat(previousValue);
        let current = parseFloat(displayValue);
        let result = 0;
        switch(operation) {
            case "+": result = prev + current; break;
            case "-": result = prev - current; break;
            case "*": result = prev * current; break;
            case "/": result = prev / current; break;
        }
        displayValue = result.toString();
        operation = "";
        newNumber = true;
    }

    function clear() { displayValue = "0"; previousValue = ""; operation = ""; newNumber = true; }
    function backspace() {
        if (displayValue.length > 1) displayValue = displayValue.slice(0, -1);
        else { displayValue = "0"; newNumber = true; }
    }

    Keys.onPressed: (event) => {
        if (event.text >= "0" && event.text <= "9") {
            handleDigit(event.text);
            event.accepted = true;
        } else if (event.text === "." || event.text === ",") {
            handleDigit(".");
            event.accepted = true;
        } else if (event.text === "+") {
            handleOperation("+");
            event.accepted = true;
        } else if (event.text === "-") {
            handleOperation("-");
            event.accepted = true;
        } else if (event.text === "*" || event.text === "x") {
            handleOperation("*");
            event.accepted = true;
        } else if (event.text === "/") {
            handleOperation("/");
            event.accepted = true;
        } else if (event.key === Qt.Key_Enter || event.key === Qt.Key_Return || event.text === "=") {
            calculate();
            event.accepted = true;
        } else if (event.key === Qt.Key_Backspace) {
            backspace();
            event.accepted = true;
        } else if (event.key === Qt.Key_Escape || event.key === Qt.Key_Delete) {
            clear();
            event.accepted = true;
        }
    }

    MouseArea {
        anchors.fill: parent
        onPressed: {
            root.forceActiveFocus();
            mouse.accepted = false;
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 5
        spacing: 8

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 55
            color: Appearance.colors.colLayer2
            radius: Appearance.rounding.small
            
            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 8
                spacing: 0
                StyledText {
                    Layout.alignment: Qt.AlignRight
                    text: root.operation ? root.previousValue + " " + root.operation : " "
                    font.pixelSize: Appearance.font.pixelSize.smallest
                    color: Appearance.colors.colSubtext
                }
                StyledText {
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignRight
                    text: root.displayValue
                    font.pixelSize: 20
                    font.weight: 600
                    font.family: Appearance.font.family.numbers
                    color: Appearance.colors.colOnSurface
                    elide: Text.ElideLeft
                    horizontalAlignment: Text.AlignRight
                }
            }
        }

        GridLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            columns: 4
            rowSpacing: 6
            columnSpacing: 6

            CompactCalcButton { text: "C"; colBackground: Appearance.colors.colErrorContainer; colText: Appearance.colors.colOnErrorContainer; onClicked: root.clear() }
            CompactCalcButton { icon: "backspace"; onClicked: root.backspace() }
            CompactCalcButton { text: "%"; onClicked: { root.displayValue = (parseFloat(root.displayValue) / 100).toString(); root.newNumber = true; } }
            CompactCalcButton { text: "÷"; op: true; onClicked: root.handleOperation("/") }

            CompactCalcButton { text: "7"; onClicked: root.handleDigit("7") }
            CompactCalcButton { text: "8"; onClicked: root.handleDigit("8") }
            CompactCalcButton { text: "9"; onClicked: root.handleDigit("9") }
            CompactCalcButton { icon: "close"; op: true; onClicked: root.handleOperation("*") }

            CompactCalcButton { text: "4"; onClicked: root.handleDigit("4") }
            CompactCalcButton { text: "5"; onClicked: root.handleDigit("5") }
            CompactCalcButton { text: "6"; onClicked: root.handleDigit("6") }
            CompactCalcButton { icon: "remove"; op: true; onClicked: root.handleOperation("-") }

            CompactCalcButton { text: "1"; onClicked: root.handleDigit("1") }
            CompactCalcButton { text: "2"; onClicked: root.handleDigit("2") }
            CompactCalcButton { text: "3"; onClicked: root.handleDigit("3") }
            CompactCalcButton { icon: "add"; op: true; onClicked: root.handleOperation("+") }

            CompactCalcButton { text: "0"; Layout.columnSpan: 2; Layout.fillWidth: true; onClicked: root.handleDigit("0") }
            CompactCalcButton { text: "."; onClicked: root.handleDigit(".") }
            CompactCalcButton { icon: "equal"; colBackground: Appearance.colors.colPrimary; colText: Appearance.colors.colOnPrimary; onClicked: root.calculate() }
        }
    }

    component CompactCalcButton: Rectangle {
        property bool op: false
        property string icon: ""
        property string text: ""
        property color colText: op ? Appearance.colors.colOnPrimaryContainer : Appearance.colors.colOnSurface
        property color colBackground: op ? Appearance.colors.colPrimaryContainer : Appearance.colors.colLayer2
        signal clicked()
        id: btnRoot
        Layout.fillWidth: true
        Layout.fillHeight: true
        radius: Appearance.rounding.small
        color: mouseArea.containsPress ? ColorUtils.mix(colBackground, colText, 0.8) : (mouseArea.containsMouse ? ColorUtils.mix(colBackground, colText, 0.92) : colBackground)
        Behavior on color { ColorAnimation { duration: 150 } }
        Item {
            anchors.centerIn: parent
            MaterialSymbol { anchors.centerIn: parent; visible: btnRoot.icon !== ""; text: btnRoot.icon; iconSize: 18; color: btnRoot.colText }
            StyledText { anchors.centerIn: parent; visible: btnRoot.icon === ""; text: btnRoot.text; font.pixelSize: 16; font.weight: 500; font.family: Appearance.font.family.numbers; color: btnRoot.colText }
        }
        MouseArea { id: mouseArea; anchors.fill: parent; hoverEnabled: true; onClicked: btnRoot.clicked() }
    }
}