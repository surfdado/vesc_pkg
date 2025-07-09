import "qrc:/mobile"
import QtQuick 2.12
import QtQuick.Controls 2.12
import QtQuick.Layouts 1.3
import Vedder.vesc.commands 1.0
import Vedder.vesc.configparams 1.0
import Vedder.vesc.utility 1.0
import Vedder.vesc.vescinterface 1.0

Item {
    id: container
    anchors.fill: parent
    anchors.margins: 10
    property int pubmotePairCode: -1  // Initialize with a default invalid value
    property bool pairingTimeout: false
    property int remainingTime: 30  // Initialize with the full 30 seconds
    property int bmsConnected: 0
    property Commands mCommands: VescIf.commands()
    property int floatAccessoriesMagic: 102
    property bool acceptTOS: false
    property int lastStatusTime: 0
    property bool statusTimeout: false
    property bool readConfig: false

    Component.onCompleted: {
        if (VescIf.getLastFwRxParams().hwTypeStr() !== "Custom Module") {
            VescIf.emitMessageDialog("Float Accessories", "Warning: It doesn't look like this is installed on a VESC Express.", false, false)
        }

        sendCode(String.fromCharCode(102) + String.fromCharCode(1) + "(send-config)")
    }

    Timer {
        id: statusCheckTimer
        interval: 1000 // Check status every second
        running: true
        repeat: true
        onTriggered: {
            sendCode(String.fromCharCode(102) + String.fromCharCode(1) + "(status)")
            lastStatusTime++

            if (lastStatusTime > 2) { // 2 second timeout
                statusTimeout = true
            }
        }
    }

    // Timer for 30-second timeout
    Timer {
        id: pairingTimeoutTimer
        interval: 1000  // 1 second
        running: false
        repeat: true

        onTriggered: {
            remainingTime--;  // Decrease the remaining time by 1 second

            if (remainingTime <= 0) {
                pairingTimeout = true;
                sendCode(String.fromCharCode(102) + String.fromCharCode(1) + "(pair-pubmote -2)");  // Automatically reject if time runs out
                pubmotePairPopup.close();
            }
        }
    }

    // Popup for Pubmote pairing confirmation
    Popup {
        id: pubmotePairPopup
        modal: true
        focus: true
        visible: false
        width: parent.width * 0.8
        height: parent.height * 0.3
        anchors.centerIn: parent

        background: Rectangle {
            color: "black"
            radius: 10
        }

        onVisibleChanged: {
            if (visible) {
                // Generate code only when the popup is shown
                pubmotePairCode = Math.floor(1000 + Math.random() * 9000);  // Generates a number between 1000 and 9999
                pairingTimeout = false;  // Reset timeout flag
                remainingTime = 30;  // Reset the timer to 30 seconds
                pairingTimeoutTimer.start();  // Start the 1-second timer to count down

                // Send the pairing request with the generated code
                sendCode(String.fromCharCode(102) + String.fromCharCode(1) + "(pair-pubmote " + pubmotePairCode + ")");
            } else {
                pairingTimeoutTimer.stop();  // Stop timer if the popup is closed
            }
        }

        contentItem: ColumnLayout {
            anchors.fill: parent
            anchors.margins: 20
            spacing: 10

            Text {
                text: "Confirm Pubmote Pairing"
                color: "white"
                font.pointSize: 16
                Layout.alignment: Qt.AlignHCenter
            }

            Text {
                text: "Pairing Code: " + pubmotePairCode
                color: "white"
                Layout.alignment: Qt.AlignHCenter
            }

            Text {
                text: "Time remaining: " + remainingTime + " seconds"
                color: "white"
                Layout.alignment: Qt.AlignHCenter
            }

            RowLayout {
                spacing: 10
                Layout.alignment: Qt.AlignHCenter

                Button {
                    text: "Accept"
                    onClicked: {
                        if (!pairingTimeout) {
                            sendCode(String.fromCharCode(102) + String.fromCharCode(1) + "(pair-pubmote -1)");  // Accept pairing
                            pubmotePairPopup.close();
                        }
                    }
                }

                Button {
                    text: "Reject"
                    onClicked: {
                        sendCode(String.fromCharCode(102) + String.fromCharCode(1) + "(pair-pubmote -2)");  // Reject pairing manually
                        pubmotePairPopup.close();
                    }
                }
            }
        }
    }

    Popup {
        id: keySettingPopup
        modal: true
        focus: true
        visible: false
        width: parent.width * 0.8
        height: parent.height * 0.3
        anchors.centerIn: parent

        background: Rectangle {
            color: "black"
            radius: 10
        }

        contentItem: ColumnLayout {
            anchors.fill: parent
            anchors.margins: 20
            spacing: 10

            Text {
                text: "Set Keys"
                color: "white"
                font.pointSize: 16
                Layout.alignment: Qt.AlignHCenter
            }

            TextField {
                id: keyInput
                placeholderText: "Enter Key (16 hex bytes, e.g., FFAABBCC...)"
                Layout.fillWidth: true
            }

            TextField {
                id: counterInput
                placeholderText: "Enter Counter (16 hex bytes, e.g., FFAABBCC...)"
                Layout.fillWidth: true
            }

            Button {
                id: submitButton
                text: "Submit"
                Layout.alignment: Qt.AlignHCenter
                onClicked: {
                    var keyHex = keyInput.text.replace(/[^0-9A-Fa-f]/g, '');
                    var counterHex = counterInput.text.replace(/[^0-9A-Fa-f]/g, '');

                    if (keyHex.length === 32 && counterHex.length === 32) {
                        console.log("Key: " + keyHex);
                        console.log("Counter: " + counterHex);

                        var keyList = hexStringToLispList(keyHex);
                        var counterList = hexStringToLispList(counterHex);

                        var sendKeysString = "(send-keys " + keyList + " " + counterList + ")";
                        console.log("Sending: " + sendKeysString);
                        sendCode(String.fromCharCode(102) + String.fromCharCode(1) + sendKeysString);

                        keySettingPopup.close();
                    } else {
                        console.error("Invalid input: Both key and counter must result in 4 uint32 values each")
                    }
                }
            }
        }
    }

    Popup {
        id: termsPopup
        modal: true
        focus: true
        visible: false
        width: parent.width * 0.8
        height: parent.height * 0.6
        anchors.centerIn: parent

        background: Rectangle {
            color: "black"
            radius: 10
        }

        contentItem: Item {
            anchors.fill: parent

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 20
                spacing: 10
                ScrollView {
                    clip: true
                    width: parent.width
                Layout.fillWidth: true
                Layout.fillHeight: true
                    TextArea {
                        id: termsText
                        textFormat: Text.RichText
                        text: "<p>WARNING NOTICE:</p>" +
                            "<p>This code is released as part of legitimate security research and is intended to enable interoperability between a specific Battery Management System (BMS) and aftermarket Electronic Speed Controllers (ESCs) for a widely used motorized land vehicle. This vehicle is often utilized as a mobility aid for individuals with disabilities, such as those with Hidradenitis Suppurativa, which prevents the use of traditional mobility devices.</p>" +
                            "<p>The publication of this code is an exercise of the right to free speech and expression, protected under the First Amendment of the U.S. Constitution. Furthermore, this code is released in accordance with both the security research exception under DMCA Section 1201(g) and the exemption for motorized land vehicles, which allows the circumvention of technological protection measures (TPMs) for the purposes of repair, modification, and interoperability under the Librarian of Congress's 2015 ruling and subsequent triennial exemptions. This exemption applies specifically to vehicle software, including Battery Management Systems, and permits this work for diagnostic and modification purposes.</p>" +
                            "<p>This system lacks manufacturer-provided documentation or tools for repair. Currently, consumers are forced to replace the entire battery, enclosure, and BMS at significant cost, rather than repairing individual components. We are providing the necessary documentation and tools to facilitate the repair of these systems, enabling consumers to extend the life of their devices.</p>" +
                            "<p>This publication is further supported by the California Right to Repair Act (SB 244), which took full effect on July 1, 2024. Under this law, consumers and independent repair providers are entitled to access the tools, parts, and documentation necessary to perform repairs on electronics and appliances sold or used in California, reinforcing the legality and public interest of this code publication. Although some exceptions apply, this law affirms the right to repair motorized vehicles, aligning with the purpose of this research and promoting repairability and consumer choice.</p>" +
                            "<p>Additionally, this publication is protected under Washington’s Revised Code of Washington (RCW) § 4.24.525 and California Code of Civil Procedure § 425.16, which are anti-SLAPP laws designed to prevent lawsuits aimed at intimidating or silencing lawful speech on matters of public interest. Any attempt to interfere with or litigate against the publication of this code may result in the dismissal of such legal actions, with the imposition of attorney’s fees and statutory damages.</p>" +
                            "<p>Furthermore, the motor land vehicle this BMS resides in had its advertised speed reduced during a software update for the haptic buzz feature. This change constitutes a violation of Article 6(1)(a) of the EU Directive 2005/29/EC on Unfair Commercial Practices, which prohibits misleading actions that affect the consumer’s decision to purchase or retain a product. Reducing the performance of previously purchased products, is deemed unfair under EU law, particularly as consumers were not informed or compensated for this loss of functionality.</p>" +
                            "<p>Moreover, the haptic feedback feature remains insufficiently implemented. On uneven terrains such as trails, the vibration cannot be felt effectively, and the audio feedback is may sometimes be too quiet to be useful, especially for individuals with disabilities like hearing impairments. This code addresses these deficiencies by allowing use with ESCs that allow real-time interoperability with third-party phone applications that provide customizable alerts through speakers, or headphones, improving accessibility, safety, and overall user experience."
                        color: "white"
                        wrapMode: Text.Wrap
                        onLinkActivated: function(url) {
                            Qt.openUrlExternally(url)
                        }
                    }
                }

                CheckBox {
                    id: acceptCheckBox
                    text: "I have read and accept the Terms of Service."
                    checked: false
                    onCheckedChanged: {
                        acceptButton.enabled = checked
                    }
                }

                RowLayout {
                    Layout.alignment: Qt.AlignRight
                    spacing: 10

                    Button {
                        text: "Cancel"
                        onClicked: {
                            termsPopup.close()
                            bmsEnabled.checked = false
                            VescIf.emitMessageDialog("Float Accessories", "You must accept the Terms of Service to continue with BMS features.", false, false)
                        }
                    }

                    Button {
                        id: acceptButton
                        text: "Accept"
                        enabled: acceptCheckBox.checked
                        onClicked: {
                            acceptTOS = true
                            termsPopup.close()
                            sendCode(String.fromCharCode(102) + String.fromCharCode(1) + "(accept-tos)")
                        }
                    }
                }
            }
        }
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 10

        Text {
            Layout.alignment: Qt.AlignHCenter
            color: Utility.getAppHexColor("lightText")
            font.pointSize: 20
            text: "Float Accessories"
        }

        TabBar {
            id: tabBar
            Layout.fillWidth: true

            TabButton {
                text: qsTr("Control")
            }

            TabButton {
                text: qsTr("Config")
            }

            TabButton {
                text: qsTr("Settings")
            }

            TabButton {
                text: qsTr("About")
            }
        }

        TabBar {
            id: tabBar2
            Layout.fillWidth: true
            visible: tabBar.currentIndex === 1

            // Update enabled indices when checkboxes change
            Component.onCompleted: updateEnabledIndices()

            Connections {
                target: ledEnabled
                function onCheckedChanged() { updateEnabledIndices() }
            }

            Connections {
                target: pubmoteEnabled
                function onCheckedChanged() { updateEnabledIndices() }
            }

            Connections {
                target: bmsEnabled
                function onCheckedChanged() { updateEnabledIndices() }
            }

            TabButton {
                text: qsTr("LED")
                enabled: ledEnabled.checked
            }

            TabButton {
                text: qsTr("Pubmote")
                enabled: pubmoteEnabled.checked
            }

            TabButton {
                text: qsTr("BMS")
                enabled: bmsEnabled.checked
            }
        }

        // Stack Layout
        StackLayout {
            id: stackLayout
            Layout.fillWidth: true
            Layout.fillHeight: true
            currentIndex: tabBar.currentIndex

            // LED Control Tab
            ScrollView {
                clip: true
                ScrollBar.vertical.policy: ScrollBar.AsNeeded

                ColumnLayout {
                    width: stackLayout.width
                    spacing: 10

                    Timer {
                        id: debounceTimer
                        interval: 500  // Half a second (500ms)
                        repeat: false
                        onTriggered: {
                            applyControlChanges()
                        }
                    }

                    // Stack Layout
                    StackLayout {
                        id: stackLayout2
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        currentIndex: tabBar2.currentIndex
                    }

                    GroupBox {
                        title: "Lights Control"
                        Layout.fillWidth: true
                        visible: ledEnabled.checked

                        ColumnLayout {
                            anchors.fill: parent
                            spacing: 10

                            CheckBox {
                                id: ledOn
                                text: "Headlights On"
                                checked: true
                                onCheckedChanged: {
                                    handleDebouncedChange()
                                }
                            }

                            ColumnLayout {
                                id: ledHighBeamLayout
                                visible: (
                                    ledOn.checked
                                    && (
                                        (
                                            (
                                                ledFrontStripType.currentIndex > 1
                                                && ledFrontStripType.currentIndex != 7
                                            )
                                            || (
                                                ledFrontStripType.currentIndex === 7
                                                && ledFrontHighbeamPin.value >= 0
                                            )
                                        )
                                        || (
                                            (
                                                ledRearStripType.currentIndex > 1
                                                && ledRearStripType.currentIndex != 7
                                            )
                                            || (
                                                ledRearStripType.currentIndex === 7
                                                && ledRearHighbeamPin.value >= 0
                                            )
                                        )
                                    )
                                )
                                spacing: 10

                                CheckBox {
                                    id: ledHighbeamOn
                                    text: "Highbeams On"
                                    checked: true
                                    onCheckedChanged: {
                                        handleDebouncedChange()
                                    }
                                }
                            }

                            ColumnLayout {
                                id: ledOnLayout
                                visible: ledOn.checked
                                spacing: 10

                                Text {
                                    color: Utility.getAppHexColor("lightText")
                                    text: "Headlights Brightness"
                                }

                                Slider {
                                    id: ledBrightness
                                    from: 0.0
                                    to: 1.0
                                    value: 0.6
                                    onValueChanged: {
                                        handleDebouncedChange()
                                    }
                                }

                                Text {
                                    color: Utility.getAppHexColor("lightText")
                                    text: "Headlights Idle Brightness"
                                }

                                Slider {
                                    id: ledBrightnessIdle
                                    from: 0.0
                                    to: 1.0
                                    value: 0.3
                                    onValueChanged: {
                                        handleDebouncedChange()
                                    }
                                }
                            }

                            ColumnLayout {
                                    id: ledStatusBrightnessLayout
                                    visible: ledStatusStripType.currentValue > 0 || ledMallGrabEnabled.checked
                                    spacing: 10

                                    Text {
                                        color: Utility.getAppHexColor("lightText")
                                        text: ledMallGrabEnabled.checked && ledStatusStripType.currentValue > 0 ? "Status/Mall Grab Brightness" : ledMallGrabEnabled.checked ? "Mall Grab Brightness" : "Status Brightness"
                                    }

                                    Slider {
                                        id: ledBrightnessStatus
                                        from: 0.0
                                        to: 1.0
                                        value: 0.6
                                        onValueChanged: {
                                            handleDebouncedChange()
                                        }
                                    }
                            }

                            ColumnLayout {
                                id: ledHighBeamBrightnessLayout
                                visible: (
                                    ledOn.checked
                                    && ledHighbeamOn.checked
                                    && (
                                        ledFrontStripType.currentIndex === 7
                                        || ledRearStripType.currentIndex === 7
                                    )
                                )
                                spacing: 10

                                Text {
                                    color: Utility.getAppHexColor("lightText")
                                    text: "Highbeam Brightness"
                                }

                                Slider {
                                    id: ledBrightnessHighbeam
                                    from: 0.0
                                    to: 1.0
                                    value: 0.5
                                    onValueChanged: {
                                        handleDebouncedChange()
                                    }
                                }
                            }
                        }
                    }

                    GroupBox {
                        title: "BMS Control"
                        Layout.fillWidth: true
                        visible: bmsEnabled.checked && bmsType.currentIndex > 1

                        ColumnLayout {
                            anchors.fill: parent
                            spacing: 10

                            Switch {
                                id: bmsChargeState
                                text: "Charge BMS 90%"
                                checked: true
                                enabled: bmsConnected === 1
                                onCheckedChanged: {
                                    handleDebouncedChange()
                                }
                            }
                        }
                    }

                    GroupBox {
                        title: "Status"
                        Layout.fillWidth: true

                        ColumnLayout {
                            anchors.fill: parent
                            spacing: 10

                            // Status Texts Column
                            Text {
                                id: lastStatusText
                                Layout.fillWidth: true
                                color: statusTimeout ? "red" : Utility.getAppHexColor("lightText")
                                text: "Last Lisp Update: " + lastStatusTime + "s ago"
                            }

                            Text {
                                id: floatPackageStatus
                                Layout.fillWidth: true
                                color: Utility.getAppHexColor("lightText")
                                text: "Float Package Status: Unknown"
                            }

                            Text {
                                id: pubmoteStatus
                                Layout.fillWidth: true
                                color: Utility.getAppHexColor("lightText")
                                text: "Pubmote Status: Unknown"
                            }

                            Text {
                                id: bmsStatus
                                Layout.fillWidth: true
                                color: Utility.getAppHexColor("lightText")
                                text: "BMS Status: Unknown"
                            }
                            Text {
                                id: humidityStatus
                                Layout.fillWidth: true
                                color: Utility.getAppHexColor("lightText")
                                text: "LCM Humidity: Unknown"
                            }
                            Text {
                                id: humidityTempStatus
                                Layout.fillWidth: true
                                color: Utility.getAppHexColor("lightText")
                                text: "LCM Temp: Unknown"
                            }
                            Text {
                                id: bmsHumStatus
                                Layout.fillWidth: true
                                color: Utility.getAppHexColor("lightText")
                                text: "BMS Humidity: Unknown"
                            }
                            Text {
                                id: bmsHumTempStatus
                                Layout.fillWidth: true
                                color: Utility.getAppHexColor("lightText")
                                text: "BMS Temp: Unknown"
                            }
                        }
                    }

                    GroupBox {
                        title: "BMS Info"
                        Layout.fillWidth: true
                        visible: bmsEnabled.checked && bmsConnected === 1

                        ColumnLayout {
                            anchors.fill: parent
                            spacing: 10

                            Text {
                                id: bmsError
                                Layout.fillWidth: true
                                color: Utility.getAppHexColor("lightText")
                                text: "BMS Error: None"
                            }
                            Text {
                                id: bmsBatteryType
                                Layout.fillWidth: true
                                color: Utility.getAppHexColor("lightText")
                                text: "Battery Type: None"
                            }
                            Text {
                                id: bmsBatteryCycles
                                Layout.fillWidth: true
                                color: Utility.getAppHexColor("lightText")
                                text: "Battery Cycles: None"
                            }
                        }
                    }
                }
            }

            // LED Configuration Tab
            ScrollView {
                clip: true
                ScrollBar.vertical.policy: ScrollBar.AsNeeded

                ColumnLayout {
                    width: stackLayout.width
                    spacing: 10

                    ColumnLayout {
                        id: ledEnabledLayout
                        visible: ledEnabled.checked && tabBar2.currentIndex === 0
                        spacing: 10

                        GroupBox {
                            title: "LED General Config"
                            Layout.fillWidth: true

                            ColumnLayout {
                                anchors.fill: parent
                                spacing: 10

                                Text {
                                    color: Utility.getAppHexColor("lightText")
                                    text: "Max Blend Count"
                                }

                                SpinBox {
                                    id: ledMaxBlendCount
                                    from: 1
                                    to: 100
                                    value: 4
                                    editable: true
                                }

                                Text {
                                    color: Utility.getAppHexColor("lightText")
                                    text: "LED Fix"
                                }

                                SpinBox {
                                    id: ledFix
                                    from: 1
                                    to: 1000000
                                    value: 100
                                    editable: true
                                }

                                Text {
                                    color: Utility.getAppHexColor("lightText")
                                    text: "LED Max Brightness (80% by default to prevent LED burnout)"
                                }

                                Slider {
                                    id: ledMaxBrightness
                                    from: 0.0
                                    to: 1.0
                                    value: 0.8
                                    stepSize: 0.01
                                    }

                                Text {
                                    color: Utility.getAppHexColor("lightText")
                                    text: "Dim RGB on Highbeam (% of main brightness)"
                                }

                                Slider {
                                    id: ledDimOnHighbeamRatio
                                    from: 0.0
                                    to: 1.0
                                    value: 0.0
                                    stepSize: 0.1
                                }

                                Text {
                                    color: Utility.getAppHexColor("lightText")
                                    text: "Mode"
                                }

                                ComboBox {
                                    id: ledMode
                                    Layout.fillWidth: true
                                    model: [
                                        {text: "White/Red", value: 0},
                                        {text: "Battery Meter", value: 1},
                                        {text: "Cyan/Magenta", value: 2},
                                        {text: "Blue/Green", value: 3},
                                        {text: "Yellow/Green", value: 4},
                                        {text: "Rainbow Chase", value: 5},
                                        {text: "Strobe", value: 6},
                                        {text: "Rave", value: 7},
                                        {text: "Mullet", value: 8},
                                        {text: "Knight Rider", value: 9},
                                        {text: "Felony", value: 10},
                                        {text: "Trans Pride", value: 11}
                                    ]
                                    textRole: "text"
                                    valueRole: "value"
                                    onCurrentIndexChanged: {
                                        value = model[currentIndex].value
                                    }
                                    property int value: 0
                                }

                                Text {
                                    color: Utility.getAppHexColor("lightText")
                                    text: "Idle Mode"
                                }

                                ComboBox {
                                    id: ledModeIdle
                                    Layout.fillWidth: true
                                    model: ledMode.model
                                    textRole: "text"
                                    valueRole: "value"
                                    onCurrentIndexChanged: {
                                        value = model[currentIndex].value
                                    }
                                    property int value: 5
                                }

                                Text {
                                    color: Utility.getAppHexColor("lightText")
                                    text: "Startup Mode"
                                }

                                ComboBox {
                                    id: ledModeStartup
                                    Layout.fillWidth: true
                                    model: ledMode.model
                                    textRole: "text"
                                    valueRole: "value"
                                    onCurrentIndexChanged: {
                                        value = model[currentIndex].value
                                    }
                                    property int value: 5
                                }

                                Text {
                                    color: Utility.getAppHexColor("lightText")
                                    text: "Status Mode"
                                }

                                ComboBox {
                                    id: ledModeStatus
                                    Layout.fillWidth: true
                                    model: [
                                        {text: "Green->Red Voltage, Blue Sensor, Yellow->Red Duty", value: 0},
                                        {text: "Swap ADC1/ADC2", value: 1},
                                    ]
                                    textRole: "text"
                                    valueRole: "value"
                                    onCurrentIndexChanged: {
                                        value = model[currentIndex].value
                                    }
                                    property int value: 0
                                }

                                Text {
                                    color: Utility.getAppHexColor("lightText")
                                    text: "Button Mode"
                                }

                                ComboBox {
                                    id: ledModeButton
                                    Layout.fillWidth: true
                                    model: [
                                        {text: "Rainbow Chase", value: 0},
                                        {text: "Battery Meter", value: 1},
                                    ]
                                    textRole: "text"
                                    valueRole: "value"
                                    onCurrentIndexChanged: {
                                        value = model[currentIndex].value
                                    }
                                    property int value: 0
                                }

                                Text {
                                    color: Utility.getAppHexColor("lightText")
                                    text: "Footpad Mode"
                                }

                                ComboBox {
                                    id: ledModeFootpad
                                    Layout.fillWidth: true
                                    model: [
                                        {text: "Rainbow Chase", value: 0}
                                    ]
                                    textRole: "text"
                                    valueRole: "value"
                                    onCurrentIndexChanged: {
                                        value = model[currentIndex].value
                                    }
                                    property int value: 0
                                }

                                CheckBox {
                                    id: ledMallGrabEnabled
                                    text: "Mall Grab"
                                    checked: true
                                }

                                CheckBox {
                                    id: ledBrakeLightEnabled
                                    text: "Brake Light"
                                    checked: true
                                }

                                CheckBox {
                                    id: ledShowBatteryCharging
                                    text: "Show battery % while charging"
                                    checked: false
                                }

                                ColumnLayout {
                                    id: ledBrakeLightLayout
                                    visible: ledBrakeLightEnabled.checked
                                    spacing: 10

                                    Text {
                                        color: Utility.getAppHexColor("lightText")
                                        text: "Brake Light Min Amps"
                                    }

                                    SpinBox {
                                        id: ledBrakeLightMinAmps
                                        from: -40.0
                                        to: -1.0
                                        value: -4.0
                                        editable: true
                                    }
                                }

                                Text {
                                    color: Utility.getAppHexColor("lightText")
                                    text: "Idle Timeout (sec)"
                                }

                                SpinBox {
                                    id: idleTimeout
                                    from: 1
                                    to: 100
                                    value: 1
                                    editable: true
                                }

                                Text {
                                    color: Utility.getAppHexColor("lightText")
                                    text: "Idle Timeout Shutoff (sec)"
                                }

                                SpinBox {
                                    id: idleTimeoutShutoff
                                    from: 0
                                    to: 1000
                                    value: 600
                                    editable: true
                                }

                                Text {
                                    color: Utility.getAppHexColor("lightText")
                                    text: "Startup Timeout (s)"
                                }

                                SpinBox {
                                    id: ledStartupTimeout
                                    from: 10
                                    to: 60
                                    value: 20
                                    editable: true
                                }
                            }
                        }

                        GroupBox {
                            title: "Status Config"
                            Layout.fillWidth: true

                            ColumnLayout {
                                anchors.fill: parent
                                spacing: 10

                                Text {
                                    color: Utility.getAppHexColor("lightText")
                                    text: "Status Strip"
                                }

                                ComboBox {
                                    id: ledStatusStripType
                                    Layout.fillWidth: true
                                    model: [
                                        {text: "None", value: 0},
                                        {text: "Custom", value: 1},
                                    ]
                                    textRole: "text"
                                    valueRole: "value"
                                    onCurrentIndexChanged: {
                                        value = model[currentIndex].value
                                        updateStatusLEDSettings()
                                    }
                                    property int value: 1
                                }

                                ColumnLayout {
                                    id: ledStatusPinLayout
                                    visible: ledStatusStripType.currentValue > 0
                                    spacing: 10

                                    Text {
                                        color: Utility.getAppHexColor("lightText")
                                        text: "Status Pin"
                                    }

                                    SpinBox {
                                        id: ledStatusPin
                                        from: -1
                                        to: 100
                                        value: 7
                                        editable: true
                                    }

                                    Text {
                                        color: Utility.getAppHexColor("lightText")
                                        text: "Status Num"
                                    }

                                    SpinBox {
                                        id: ledStatusNum
                                        from: 0
                                        to: 100
                                        value: 10
                                        editable: true
                                    }

                                    Text {
                                        color: Utility.getAppHexColor("lightText")
                                        text: "Status Type"
                                    }

                                    ComboBox {
                                        id: ledStatusType
                                        Layout.fillWidth: true
                                        model: [
                                            {text: "GRB", value: 0},
                                            {text: "RGB", value: 1},
                                            {text: "GRBW", value: 2},
                                            {text: "RGBW", value: 3},
                                            {text: "WRGB", value: 4},
                                        ]
                                        textRole: "text"
                                        valueRole: "value"
                                        onCurrentIndexChanged: {
                                            value = model[currentIndex].value
                                        }
                                        property int value: 0
                                    }

                                    CheckBox {
                                        id: ledStatusReversed
                                        text: "Status Reversed"
                                        checked: false
                                    }
                                }
                            }
                        }

                        GroupBox {
                            title: "LED Front Config"
                            Layout.fillWidth: true

                            ColumnLayout {
                                anchors.fill: parent
                                spacing: 10

                                Text {
                                    color: Utility.getAppHexColor("lightText")
                                    text: "Front Strip"
                                }

                                ComboBox {
                                    id: ledFrontStripType
                                    Layout.fillWidth: true
                                    model: [
                                        {text: "None", value: 0},
                                        {text: "Custom", value: 1},
                                        {text: "Avaspark Laserbeam", value: 2},
                                        {text: "Avaspark Laserbeam Pint", value: 3},
                                        {text: "JetFleet H4", value: 4},
                                        {text: "JetFleet H4 (no limit DCDC)", value: 5},
                                        {text: "JetFleet GT", value: 6},
                                        {text: "Stock GT", value: 7},
                                        {text: "Avaspark Laserbeam V2", value: 8},
                                        {text: "Avaspark Laserbeam V2 Pint", value: 9},
                                        {text: "Light-shutka Flashfires", value: 10},
                                        {text: "Fungineers GTFO", value: 11},
                                    ]
                                    textRole: "text"
                                    valueRole: "value"
                                    onCurrentIndexChanged: {
                                        value = model[currentIndex].value
                                        updateFrontLEDSettings()
                                    }
                                    property int value: 2
                                }

                                ColumnLayout {
                                    id: ledFrontPinLayout
                                    visible: ledFrontStripType.currentValue > 0
                                    spacing: 10

                                    Text {
                                        color: Utility.getAppHexColor("lightText")
                                        text: "Front Pin"
                                    }

                                    SpinBox {
                                        id: ledFrontPin
                                        from: -1
                                        to: 100
                                        value: 8
                                        editable: true
                                    }
                                }

                                ColumnLayout {
                                    id: ledFrontHighbeamPinLayout
                                    visible: ledFrontStripType.currentValue === 7
                                    spacing: 10

                                    Text {
                                        color: Utility.getAppHexColor("lightText")
                                        text: "Front Highbeam Pin"
                                    }

                                    SpinBox {
                                        id: ledFrontHighbeamPin
                                        from: -1
                                        to: 100
                                        value: -1
                                        editable: true
                                    }
                                }

                                ColumnLayout {
                                    id: ledFrontCustomSettings
                                    visible: ledFrontStripType.currentValue === 1
                                    spacing: 10

                                    Text {
                                        color: Utility.getAppHexColor("lightText")
                                        text: "Front Num"
                                    }

                                    SpinBox {
                                        id: ledFrontNum
                                        from: 0
                                        to: 100
                                        value: 18
                                        editable: true
                                    }

                                    Text {
                                        color: Utility.getAppHexColor("lightText")
                                        text: "Front Type"
                                    }

                                    ComboBox {
                                        id: ledFrontType
                                        Layout.fillWidth: true
                                        model: [
                                            {text: "GRB", value: 0},
                                            {text: "RGB", value: 1},
                                            {text: "GRBW", value: 2},
                                            {text: "RGBW", value: 3},
                                            {text: "WRGB", value: 4},
                                        ]
                                        textRole: "text"
                                        valueRole: "value"
                                        onCurrentIndexChanged: {
                                            value = model[currentIndex].value
                                        }
                                        property int value: 0
                                    }
                                }

                                ColumnLayout {
                                    id: ledFrontReversedLayout
                                    visible: ledFrontStripType.currentValue > 0
                                    spacing: 10

                                    CheckBox {
                                        id: ledFrontReversed
                                        text: "Front Reversed"
                                        checked: false
                                    }
                                }
                            }
                        }

                        GroupBox {
                            title: "LED Rear Config"
                            Layout.fillWidth: true

                            ColumnLayout {
                                anchors.fill: parent
                                spacing: 10

                                Text {
                                    color: Utility.getAppHexColor("lightText")
                                    text: "Rear Strip"
                                }

                                ComboBox {
                                    id: ledRearStripType
                                    Layout.fillWidth: true
                                    model: [
                                        {text: "None", value: 0},
                                        {text: "Custom", value: 1},
                                        {text: "Avaspark Laserbeam", value: 2},
                                        {text: "Avaspark Laserbeam Pint", value: 3},
                                        {text: "JetFleet H4", value: 4},
                                        {text: "JetFleet H4 (no limit DCDC)", value: 5},
                                        {text: "JetFleet GT", value: 6},
                                        {text: "Stock GT", value: 7},
                                        {text: "Avaspark Laserbeam V2", value: 8},
                                        {text: "Avaspark Laserbeam V2 Pint", value: 9},
                                        {text: "Light-shutka Flashfires", value: 10},
                                        {text: "Fungineers GTFO", value: 11},
                                    ]
                                    textRole: "text"
                                    valueRole: "value"
                                    onCurrentIndexChanged: {
                                        value = model[currentIndex].value
                                        updateRearLEDSettings()
                                    }
                                    property int value: 2
                                }

                                ColumnLayout {
                                    id: ledRearPinLayout
                                    visible: ledRearStripType.currentValue > 0
                                    spacing: 10

                                    Text {
                                        color: Utility.getAppHexColor("lightText")
                                        text: "Rear Pin"
                                    }

                                    SpinBox {
                                        id: ledRearPin
                                        from: -1
                                        to: 100
                                        value: 9
                                        editable: true
                                    }
                                }

                                ColumnLayout {
                                    id: ledRearHighbeamPinLayout
                                    visible: ledRearStripType.currentValue === 7
                                    spacing: 10

                                    Text {
                                        color: Utility.getAppHexColor("lightText")
                                        text: "Rear Highbeam Pin"
                                    }

                                    SpinBox {
                                        id: ledRearHighbeamPin
                                        from: -1
                                        to: 100
                                        value: -1
                                        editable: true
                                    }
                                }

                                ColumnLayout {
                                    id: ledRearCustomSettings
                                    visible: ledRearStripType.currentValue === 1
                                    spacing: 10

                                    Text {
                                        color: Utility.getAppHexColor("lightText")
                                        text: "Rear Num"
                                    }

                                    SpinBox {
                                        id: ledRearNum
                                        from: 0
                                        to: 100
                                        value: 18
                                        editable: true
                                    }

                                    Text {
                                        color: Utility.getAppHexColor("lightText")
                                        text: "Rear Type"
                                    }

                                    ComboBox {
                                        id: ledRearType
                                        Layout.fillWidth: true
                                        model: [
                                            {text: "GRB", value: 0},
                                            {text: "RGB", value: 1},
                                            {text: "GRBW", value: 2},
                                            {text: "RGBW", value: 3},
                                            {text: "WRGB", value: 4},
                                        ]
                                        textRole: "text"
                                        valueRole: "value"
                                        onCurrentIndexChanged: {
                                            value = model[currentIndex].value
                                        }
                                        property int value: 0
                                    }
                                }

                                ColumnLayout {
                                    id: ledRearReversedLayout
                                    visible: ledRearStripType.currentValue > 0
                                    spacing: 10

                                    CheckBox {
                                        id: ledRearReversed
                                        text: "Rear Reversed"
                                        checked: false
                                    }
                                }
                            }
                        }

                        GroupBox {
                            title: "LED Button Config"
                            Layout.fillWidth: true

                            ColumnLayout {
                                anchors.fill: parent
                                spacing: 10

                                Text {
                                    color: Utility.getAppHexColor("lightText")
                                    text: "Button"
                                }

                                ComboBox {
                                    id: ledButtonStripType
                                    Layout.fillWidth: true
                                    model: [
                                        {text: "None", value: 0},
                                        {text: "NeoPixel RGB", value: 1},
                                    ]
                                    textRole: "text"
                                    valueRole: "value"
                                    onCurrentIndexChanged: {
                                        value = model[currentIndex].value
                                    }
                                    property int value: 0
                                }

                                ColumnLayout {
                                    id: ledButtonPinLayout
                                    visible: ledButtonStripType.currentValue > 0
                                    spacing: 10

                                    Text {
                                        color: Utility.getAppHexColor("lightText")
                                        text: "Button Pin"
                                    }

                                    SpinBox {
                                        id: ledButtonPin
                                        from: -1
                                        to: 100
                                        value: -1
                                        editable: true
                                    }
                                }

                                ColumnLayout {
                                    id: ledButtonCustomSettings
                                    visible: ledRearStripType.currentValue === 1
                                    spacing: 10
                                }
                            }
                        }

                        GroupBox {
                            title: "LED Footpad Config"
                            Layout.fillWidth: true

                            ColumnLayout {
                                anchors.fill: parent
                                spacing: 10

                                Text {
                                    color: Utility.getAppHexColor("lightText")
                                    text: "Footpad Strip"
                                }

                                ComboBox {
                                    id: ledFootpadStripType
                                    Layout.fillWidth: true
                                    model: [
                                        {text: "None", value: 0},
                                        {text: "Custom", value: 1}
                                    ]
                                    textRole: "text"
                                    valueRole: "value"
                                    onCurrentIndexChanged: {
                                        value = model[currentIndex].value
                                        updateFootpadLEDSettings()
                                    }
                                    property int value: 0
                                }

                                ColumnLayout {
                                    id: ledFootpadPinLayout
                                    visible: ledFootpadStripType.currentValue > 0
                                    spacing: 10

                                    Text {
                                        color: Utility.getAppHexColor("lightText")
                                        text: "Footpad Pin"
                                    }

                                    SpinBox {
                                        id: ledFootpadPin
                                        from: -1
                                        to: 100
                                        value: -1
                                        editable: true
                                    }
                                }

                                ColumnLayout {
                                    id: ledFootpadCustomSettings
                                    visible: ledFootpadStripType.currentValue === 1
                                    spacing: 10

                                    Text {
                                        color: Utility.getAppHexColor("lightText")
                                        text: "Footpad Num"
                                    }

                                    SpinBox {
                                        id: ledFootpadNum
                                        from: 0
                                        to: 100
                                        value: 13
                                        editable: true
                                    }

                                    Text {
                                        color: Utility.getAppHexColor("lightText")
                                        text: "Footpad Type"
                                    }

                                    ComboBox {
                                        id: ledFootpadType
                                        Layout.fillWidth: true
                                        model: [
                                            {text: "GRB", value: 0},
                                            {text: "RGB", value: 1},
                                            {text: "GRBW", value: 2},
                                            {text: "RGBW", value: 3},
                                            {text: "WRGB", value: 4},
                                        ]
                                        textRole: "text"
                                        valueRole: "value"
                                        onCurrentIndexChanged: {
                                            value = model[currentIndex].value
                                        }
                                        property int value: 0
                                    }
                                }

                                ColumnLayout {
                                    id: ledFootpadReversedLayout
                                    visible: ledFootpadStripType.currentValue > 0
                                    spacing: 10

                                    CheckBox {
                                        id: ledFootpadReversed
                                        text: "Footpad Reversed"
                                        checked: false
                                    }
                                }
                            }
                        }
                    }

                    ColumnLayout {
                        width: stackLayout.width
                        spacing: 10
                        GroupBox {
                            title: "Pubmote Config"
                            Layout.fillWidth: true
                            visible: pubmoteEnabled.checked && tabBar2.currentIndex === 1

                            ColumnLayout {
                                anchors.fill: parent
                                spacing: 5
                                RowLayout {
                                    spacing: 5
                                    id: pubmoteLayout

                                    Button {
                                        text: "Pair Pubmote"
                                        onClicked: {
                                            pubmotePairPopup.open();  // Open the confirmation popup with the random code
                                        }
                                    }

                                    Text {
                                        id: pubmoteMacAddress
                                        color: Utility.getAppHexColor("lightText")
                                        text: "Pubmote MAC: Unknown"
                                    }
                                }

                                RowLayout {
                                    spacing: 5
                                    id: pubmoteLayout2
                                    visible: pubmoteEnabled.checked
                                }
                            }
                        }
                    }

                    ColumnLayout {
                        width: stackLayout.width
                        spacing: 10
                        GroupBox {
                            title: "BMS Config"
                            Layout.fillWidth: true
                            visible: bmsEnabled.checked && tabBar2.currentIndex === 2
                            ColumnLayout {
                                anchors.fill: parent
                                spacing: 10

                                Text {
                                    color: Utility.getAppHexColor("lightText")
                                    text: "BMS Type"
                                }

                                ComboBox {
                                    id: bmsType
                                    Layout.fillWidth: true
                                    model: [
                                        {text: "None", value: 0},
                                        {text: "Unencrypted", value: 1},
                                        {text: "Encrypted", value: 2},
                                    ]
                                    textRole: "text"
                                    valueRole: "value"
                                    onCurrentIndexChanged: {
                                        value = model[currentIndex].value
                                    }
                                    property int value: 0
                                }

                                ColumnLayout {
                                    id: bmsSettings
                                    visible: bmsType.currentIndex > 0
                                    spacing: 10

                                    ColumnLayout {
                                        id: bmsCryptoSettingsLayout
                                        visible: bmsType.currentIndex > 1
                                        spacing: 10

                                        Button {
                                            text: "Set Keys"
                                            onClicked: {
                                                keyInput.text = ""
                                                counterInput.text = ""
                                                keySettingPopup.open()
                                            }
                                        }
                                    }

                                    CheckBox {
                                        id: bmsRS485Chip
                                        text: "RS485 Chip (Required for encrypted BMS charger level without Owie RS485 bypass)"
                                        checked: false
                                    }

                                    Text {
                                        color: Utility.getAppHexColor("lightText")
                                        text: "RS485 RO/A Pin"
                                    }

                                    SpinBox {
                                        id: bmsRs485ROPin
                                        from: -1
                                        to: 100
                                        value: -1
                                        editable: true
                                    }

                                    ColumnLayout {
                                        id: bmsRS485chipLayout
                                        visible: bmsRS485Chip.checked
                                        spacing: 10

                                        Text {
                                            color: Utility.getAppHexColor("lightText")
                                            text: "RS485 DI Pin"
                                        }

                                        SpinBox {
                                            id: bmsRs485DIPin
                                            from: -1
                                            to: 100
                                            value: -1
                                            editable: true
                                        }

                                        Text {
                                            color: Utility.getAppHexColor("lightText")
                                            text: "RS485 DE/RE Pin"
                                        }

                                        SpinBox {
                                            id: bmsRs485DEREPin
                                            from: -1
                                            to: 100
                                            value: -1
                                            editable: true
                                        }

                                        Button {
                                            text: "Factory Init"
                                            //enabled: bmsConnected === 1
                                            onClicked: {
                                                bmsFactoryInit()
                                            }
                                        }
                                    }

                                    CheckBox {
                                        id: bmsChargeOnly
                                        text: "Charge only (Mosfet toggle wakeup to keep alive)"
                                        checked: false
                                    }

                                    ColumnLayout {
                                        id: bmsChargeOnlyLayout
                                        visible: bmsChargeOnly.checked
                                        spacing: 10

                                        Text {
                                            color: Utility.getAppHexColor("lightText")
                                            text: "Wakeup Pin"
                                        }

                                        SpinBox {
                                            id: bmsWakeupPin
                                            from: -1
                                            to: 100
                                            value: -1
                                            editable: true
                                        }
                                    }

                                    CheckBox {
                                        id: bmsOverrideSOC
                                        text: "Override SOC (Voltage)"
                                        checked: false
                                    }

                                    Text {
                                        color: Utility.getAppHexColor("lightText")
                                        text: "BMS Buffer Size"
                                    }

                                    SpinBox {
                                        id: bmsBuffSize
                                        from: 16
                                        to: 256
                                        value: 128
                                        editable: true
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // Settings tab
            ScrollView {
                clip: true
                ScrollBar.vertical.policy: ScrollBar.AsNeeded

                ColumnLayout {
                    width: stackLayout.width
                    spacing: 10

                    GroupBox {
                        title: "Features"
                        Layout.fillWidth: true

                        ColumnLayout {
                            anchors.fill: parent
                            spacing: 10
                            CheckBox {
                                id: ledEnabled
                                text: "LED Enabled"
                                checked: true
                            }

                            CheckBox {
                                id: pubmoteEnabled
                                text: "Pubmote Enabled"
                                checked: false
                                enabled: true
                            }

                            CheckBox {
                                id: bmsEnabled
                                text: "BMS Enabled"
                                checked: false
                                enabled: true
                            }
                        }
                    }

                    GroupBox {
                        title: "Loop Settings"
                        Layout.fillWidth: true

                        ColumnLayout {
                            width: stackLayout.width
                            spacing: 10

                            Text {
                                color: Utility.getAppHexColor("lightText")
                                text: "CAN Delay (hz)"
                            }

                            SpinBox {
                                id: canLoopDelay
                                from: 1
                                to: 1000
                                value: 8
                                stepSize: 1
                                editable: true
                            }

                            Text {
                                color: Utility.getAppHexColor("lightText")
                                text: "LED Delay (hz) "
                                visible: ledEnabled.checked
                            }

                            SpinBox {
                                id: ledLoopDelay
                                from: 1
                                to: 1000
                                value: 20
                                stepSize: 1
                                visible: ledEnabled.checked
                                editable: true
                            }

                            Text {
                                color: Utility.getAppHexColor("lightText")
                                text: "Pubmote Delay (hz)"
                                visible: pubmoteEnabled.checked
                            }

                            SpinBox {
                                id: pubmoteLoopDelay
                                from: 1
                                to: 1000
                                value: 8
                                stepSize: 1
                                visible: pubmoteEnabled.checked
                                editable: true
                            }

                            Text {
                                color: Utility.getAppHexColor("lightText")
                                text: "BMS Delay (hz): "
                                visible: bmsEnabled.checked
                            }

                            SpinBox {
                                id: bmsLoopDelay
                                from: 1
                                to: 1000
                                value: 8
                                stepSize: 1
                                visible: bmsEnabled.checked
                                editable: true
                            }
                        }
                    }
                }
            }

            // About Tab
            ScrollView {
                clip: true
                ScrollBar.vertical.policy: ScrollBar.AsNeeded
                ScrollBar.horizontal.policy: ScrollBar.AlwaysOff

                ColumnLayout {
                    width: stackLayout.width
                    spacing: 20

                    TextArea {
                        id: aboutText
                        textFormat: Text.RichText
                        text: "<p><b>FLOAT ACCESSORIES PACKAGE</b></p>" +
                            "<p>A VESC Express package for controlling LEDs, BMS and Pubmote.</p>" +

                            "<p><b>Support Future Work</b></p>" +
                            "<p>Buy me a Coffee: <a href='https://venmo.com/sylerclayton'>https://venmo.com/sylerclayton</a></p>" +
                            "<p>Support me on Patreon: <a href='https://patreon.com/SylerTheCreator'>https://patreon.com/SylerTheCreator</a></p>" +

                            "<p><b>CREDITS</b></p>" +
                            "<p>Special Thanks: Benjamin Vedder, surfdado, Mitch (NuRxG), Siwoz, lolwheel (OWIE), ThankTheMaker (rESCue), 4_fools (avaspark), auden_builds (pubmote)</p>" +
                            "<p>gr33tz: outlandnish, exphat, datboig42069</p>" +
                            "<p>Beta Testers: Pickles</p>" +

                            "<p>My Blog: <a href='https://sylerclayton.com'>https://sylerclayton.com</a></p>" +

                            "<p><b>BUILD INFO</b></p>" +
                            "<p>Version 2.9</p>" +
                            "<p>Source code can be found here: <a href='https://github.com/relys/vesc_pkg'>https://github.com/relys/vesc_pkg</a></p>"
                        Layout.fillWidth: true
                        wrapMode: Text.WordWrap
                        color: Utility.getAppHexColor("lightText")
                        onLinkActivated: function(url) {
                            Qt.openUrlExternally(url)
                        }
                    }
                }
            }
        }

        // Save and Restore Buttons
        RowLayout {
            Layout.fillWidth: true
            spacing: 10

            Button {
                text: "Read Cfg"
                onClicked: {
                    sendCode(String.fromCharCode(102) + String.fromCharCode(1) + "(send-config)")
                }
            }

            Button {
                text: "Save Cfg"
                enabled: readConfig && lastStatusTime < 2
                onClicked: {
                    if (bmsEnabled.checked && !acceptTOS) {
                        termsPopup.visible = true
                    }

                    //console.log(makeArgStr())
                    sendCode(String.fromCharCode(102) + String.fromCharCode(1) + "(recv-config " + makeArgStr() + " )")
                    //sendCode(String.fromCharCode(102) + String.fromCharCode(1) + "(save-config)")
                    //sendCode(String.fromCharCode(102) + String.fromCharCode(1) + "(send-config)")
                }
            }

            Button {
                text: "Restore Defaults"
                onClicked: {
                    sendCode(String.fromCharCode(102) + String.fromCharCode(1) + "(restore-config)")
                    sendCode(String.fromCharCode(102) + String.fromCharCode(1) + "(send-config)")
                }
            }
        }
    }

    function updateStatusLEDSettings() {
        switch(ledStatusStripType.value) {
            case 0: // None
                break
            case 1: // Custom
                break
            default:
                // Do nothing, keep user-defined values
        }
    }

    function updateFrontLEDSettings() {
        switch(ledFrontStripType.value) {
            case 0: // None
                break
            case 1: // Custom
                break
            case 2: // Avaspark Laserbeam
                ledFrontNum.value = 18
                ledFrontType.currentIndex = 0
                break
            case 3: // Avaspark Laserbeam Pint
                ledFrontNum.value = 16
                ledFrontType.currentIndex = 0
                break
            case 4: // JetFleet H4
                ledFrontNum.value = 17
                ledFrontType.currentIndex = 0
                break
            case 5: // JetFleet H4 (no limit)
                ledFrontNum.value = 17
                ledFrontType.currentIndex = 0
                break
            case 6: // JetFleet GT
                ledFrontNum.value = 11
                ledFrontType.currentIndex = 0
                break
            case 7: // Stock GT
                ledFrontNum.value = 11
                ledFrontType.currentIndex = 2
                break
            case 8: // Avaspark Laserbeam V3
                ledFrontNum.value = 13
                ledFrontType.currentIndex = 0
                break
            case 9: // Avaspark Laserbeam V3 Pint
                ledFrontNum.value = 10
                ledFrontType.currentIndex = 0
                break
            case 10: // Light-shutka Flashfires
                ledFrontNum.value = 20;
                ledFrontType.currentIndex = 0
                break
            case 11: // Fungineers GTFO
                ledFrontNum.value = 10
                ledFrontType.currentIndex = 0
                break
            default:
                // Do nothing, keep user-defined values
        }
    }

    function updateRearLEDSettings() {
        switch(ledRearStripType.value) {
            case 0: // None
                break
            case 1: // Custom
                break
            case 2: // Avaspark Laserbeam
                ledRearNum.value = 18
                ledRearType.currentIndex = 0
                break
            case 3: // Avaspark Laserbeam Pint
                ledRearNum.value = 16
                ledRearType.currentIndex = 0
                break
            case 4: // JetFleet H4
                ledRearNum.value = 17
                ledRearType.currentIndex = 0
                break
            case 5: // JetFleet H4 (no limit)
                ledRearNum.value = 17
                ledRearType.currentIndex = 0
                break
            case 6: // JetFleet GT
                ledRearNum.value = 11
                ledRearType.currentIndex = 0
                break
            case 7: // Stock GT
                ledRearNum.value = 11
                ledRearType.currentIndex = 2
                break
            case 8: // Avaspark Laserbeam V2
                ledRearNum.value = 13
                ledRearType.currentIndex = 0
                break
            case 9: // Avaspark Laserbeam V2 Pint
                ledRearNum.value = 10
                ledRearType.currentIndex = 0
                break
            case 10: // Light-shutka Flashfires
                ledRearNum.value = 20
                ledRearType.currentIndex = 0
                break
            case 11: // Fungineers GTFO
                ledFrontNum.value = 10
                ledFrontType.currentIndex = 0
                break
            default:
                // Do nothing, keep user-defined values
        }
    }

    function updateFootpadLEDSettings() {
        switch(ledFootpadStripType.value) {
            case 0: // None
                break
            case 1: // Custom
                break
            default:
                // Do nothing, keep user-defined values
        }
    }

    function bmsFactoryInit(str) {
        sendCode(String.fromCharCode(102) + String.fromCharCode(1) + "(bms-trigger-factory-init)")
    }

    function makeControlArgStr() {
        return [
            ledOn.checked * 1,
            ledHighbeamOn.checked * 1,
            parseFloat(ledBrightness.value).toFixed(2),
            parseFloat(ledBrightnessHighbeam.value).toFixed(2),
            parseFloat(ledBrightnessIdle.value).toFixed(2),
            parseFloat(ledBrightnessStatus.value).toFixed(2),
            bmsChargeState.checked * 1
        ].join(" ");
    }

    function handleDebouncedChange() {
        debounceTimer.restart()  // Reset the timer on any change
    }

    function applyControlChanges() {
        //console.log("Applying LED control settings after debounce")
        sendCode(String.fromCharCode(102) + String.fromCharCode(1) + "(recv-control " + makeControlArgStr() + " )")
    }

    function makeArgStr() {
        return [
            ledEnabled.checked * 1,
            bmsEnabled.checked * 1,
            pubmoteEnabled.checked * 1,
            ledOn.checked * 1,
            ledHighbeamOn.checked * 1,
            ledMode.currentIndex,
            ledModeIdle.currentIndex,
            ledModeStatus.currentIndex,
            ledModeStartup.currentIndex,
            ledModeButton.currentIndex,
            ledModeFootpad.currentIndex,
            ledMallGrabEnabled.checked * 1,
            ledBrakeLightEnabled.checked * 1,
            parseFloat(ledBrakeLightMinAmps.value).toFixed(2),
            idleTimeout.value,
            idleTimeoutShutoff.value,
            parseFloat(ledBrightness.value).toFixed(2),
            parseFloat(ledBrightnessHighbeam.value).toFixed(2),
            parseFloat(ledBrightnessIdle.value).toFixed(2),
            parseFloat(ledBrightnessStatus.value).toFixed(2),
            ledStatusPin.value,
            ledStatusNum.value,
            ledStatusType.currentIndex,
            ledStatusReversed.checked * 1,
            ledFrontPin.value,
            ledFrontNum.value,
            ledFrontType.currentIndex,
            ledFrontReversed.checked * 1,
            ledFrontStripType.currentIndex,
            ledRearPin.value,
            ledRearNum.value,
            ledRearType.currentIndex,
            ledRearReversed.checked * 1,
            ledRearStripType.currentIndex,
            ledButtonPin.value,
            ledButtonStripType.currentIndex,
            ledFootpadPin.value,
            ledFootpadNum.value,
            ledFootpadType.currentIndex,
            ledFootpadReversed.checked * 1,
            ledFootpadStripType.currentIndex,
            bmsRs485DIPin.value,
            bmsRs485ROPin.value,
            bmsRs485DEREPin.value,
            bmsWakeupPin.value,
            bmsOverrideSOC.checked * 1,
            bmsRS485Chip.checked * 1,
            ledLoopDelay.value,
            bmsLoopDelay.value,
            pubmoteLoopDelay.value,
            canLoopDelay.value,
            ledMaxBlendCount.value,
            ledStartupTimeout.value,
            parseFloat(ledDimOnHighbeamRatio.value).toFixed(2),
            bmsType.currentIndex,
            ledStatusStripType.currentIndex,
            bmsChargeOnly.checked * 1,
            ledFix.value,
            ledShowBatteryCharging.checked * 1,
            ledFrontHighbeamPin.value,
            ledRearHighbeamPin.value,
            bmsBuffSize.value,
            parseFloat(ledMaxBrightness.value).toFixed(2)
        ].join(" ");
    }

    // Property to track enabled tabs
    property var enabledIndices: []

    // Update enabled indices whenever checkbox states change
    onEnabledIndicesChanged: {
        // If current tab is disabled, switch to first enabled tab
        if (!enabledIndices.includes(tabBar2.currentIndex)) {
            const firstEnabled = enabledIndices[0]
            if (firstEnabled !== undefined) {
                tabBar2.currentIndex = firstEnabled
            }
        }
    }

    function updateEnabledIndices() {
        const newIndices = []
        if (ledEnabled.checked) newIndices.push(0)
        if (pubmoteEnabled.checked) newIndices.push(1)
        if (bmsEnabled.checked) newIndices.push(2)
        enabledIndices = newIndices
    }

    function sendCode(str) {
        mCommands.sendCustomAppData(str + '\0')
    }

    function hexStringToLispList(hexString) {
        var result = "'(";
        for (var i = 0; i < hexString.length; i += 2) {
            var byteHex = hexString.substr(i, 2);
            result += "0x" + byteHex.toUpperCase() + (i < 30 ? " " : "");
        }
        result += ")";
        return result;
    }

    function unpackUint32ToBytes(packedValue) {
        return [
            (packedValue >> 24) & 0xFF,
            (packedValue >> 16) & 0xFF,
            (packedValue >> 8) & 0xFF,
            packedValue & 0xFF
        ];
    }

    Connections {
        target: mCommands

        function onCustomAppDataReceived(data) {
            var str = data.toString()

            if (str.startsWith("settings")) {
                var tokens = str.split(" ")
                acceptTOS = (Number(tokens[4])) ? true : false
                ledEnabled.checked = Number(tokens[5])
                bmsEnabled.checked = Number(tokens[6])
                pubmoteEnabled.checked = Number(tokens[7])
                ledOn.checked = Number(tokens[8])
                ledHighbeamOn.checked = Number(tokens[9])
                ledMode.currentIndex = Number(tokens[10])
                ledModeIdle.currentIndex = Number(tokens[11])
                ledModeStatus.currentIndex = Number(tokens[12])
                ledModeStartup.currentIndex = Number(tokens[13])
                ledModeButton.currentIndex = Number(tokens[14])
                ledModeFootpad.currentIndex = Number(tokens[15])
                ledMallGrabEnabled.checked = Number(tokens[16])
                ledBrakeLightEnabled.checked = Number(tokens[17])
                ledBrakeLightMinAmps.value = Number(tokens[18])
                idleTimeout.value = Number(tokens[19])
                idleTimeoutShutoff.value = Number(tokens[20])
                ledBrightness.value = Number(tokens[21])
                ledBrightnessHighbeam.value = Number(tokens[22])
                ledBrightnessIdle.value = Number(tokens[23])
                ledBrightnessStatus.value = Number(tokens[24])
                ledStatusPin.value = Number(tokens[25])
                ledStatusNum.value = Number(tokens[26])
                ledStatusType.currentIndex = Number(tokens[27])
                ledStatusReversed.checked = Number(tokens[28])
                ledFrontPin.value = Number(tokens[29])
                ledFrontNum.value = Number(tokens[30])
                ledFrontType.currentIndex = Number(tokens[31])
                ledFrontReversed.checked = Number(tokens[32])
                ledFrontStripType.currentIndex = Number(tokens[33])
                ledRearPin.value = Number(tokens[34])
                ledRearNum.value = Number(tokens[35])
                ledRearType.currentIndex = Number(tokens[36])
                ledRearReversed.checked = Number(tokens[37])
                ledRearStripType.currentIndex = Number(tokens[38])
                ledButtonPin.value = Number(tokens[39])
                ledButtonStripType.currentIndex = Number(tokens[40])
                ledFootpadPin.value = Number(tokens[41])
                ledFootpadNum.value = Number(tokens[42])
                ledFootpadType.currentIndex = Number(tokens[43])
                ledFootpadReversed.checked = Number(tokens[44])
                ledFootpadStripType.currentIndex = Number(tokens[45])
                // Format and display MAC address... need to unpack
                var unpack = unpackUint32ToBytes(Number(tokens[46])).concat(unpackUint32ToBytes(Number(tokens[47]))).slice(0,-2)
                var macAddress = unpack.map(function(token) {
                    return ("0" + Number(token).toString(16)).slice(-2);
                }).join(":");
                // esp-now-secret-code 48
                bmsRs485DIPin.value = Number(tokens[49])
                bmsRs485ROPin.value = Number(tokens[50])
                bmsRs485DEREPin.value = Number(tokens[51])
                bmsWakeupPin.value = Number(tokens[52])
                bmsOverrideSOC.checked = Number(tokens[53])
                bmsRS485Chip.checked = Number(tokens[54])
                //Need to read and unpack. To set this is also going to be handled in seperate button like tos, pair-pubmote etc.
                //bmsKeyA.value = Number(tokens[55])
                //bmsKeyB.value = Number(tokens[56])
                //bmsKeyC.value = Number(tokens[57])
                //bmsKeyD.value = Number(tokens[58])
                //bmsCounterA.value = Number(tokens[59])
                //bmsCounterB.value = Number(tokens[60])
                //bmsCounterC.value = Number(tokens[61])
                //bmsCounterD.value = Number(tokens[62])
                ledLoopDelay.value = Number(tokens[63])
                bmsLoopDelay.value = Number(tokens[64])
                pubmoteLoopDelay.value = Number(tokens[65])
                canLoopDelay.value = Number(tokens[66])
                ledMaxBlendCount.value = Number(tokens[67])
                ledStartupTimeout.value = Number(tokens[68])
                ledDimOnHighbeamRatio.value = Number(tokens[69])
                bmsType.currentIndex = Number(tokens[70])
                ledStatusStripType.currentIndex = Number(tokens[71])
                bmsChargeOnly.checked = Number(tokens[72])
                ledFix.value = Number(tokens[73])
                ledShowBatteryCharging.checked = Number(tokens[74])
                ledFrontHighbeamPin.value = Number(tokens[75])
                ledRearHighbeamPin.value = Number(tokens[76])
                bmsBuffSize.value = Number(tokens[77])
                ledMaxBrightness.value = Number(tokens[78])

                pubmoteMacAddress.text = "Pubmote MAC: " + ((Number(tokens[46]) == -1) ? "Not Paired" : macAddress.toUpperCase());
                readConfig = true;
            } else if (str.startsWith("msg")) {
                var msg = str.substring(4)
                VescIf.emitMessageDialog("Float Accessories", msg, false, false)
            } else if (str.startsWith("float-stats")) {
                var tokens = str.split(" ")

                // Float Package connection status
                var floatPackageConnected = Number(tokens[1])
                floatPackageStatus.text = "Float Package Status: " + (floatPackageConnected ? "Connected" : "Not Connected")
                floatPackageStatus.color = floatPackageConnected ? "green" : "red"

                // Pubmote connection status
                var pubmoteConnected = Number(tokens[2])
                var wifiChannel = Number(tokens[7])
                pubmoteStatus.text = "Pubmote Status: " + (
                    pubmoteConnected
                        ? "Connected (WiFi Channel " + (wifiChannel ? wifiChannel : "?") + ")"
                        : "Not Connected (WiFi Channel " + (wifiChannel ? wifiChannel : "?") + ")"
                )
                pubmoteStatus.color = pubmoteConnected ? "green" : "red"

                // BMS connection status
                bmsConnected = Number(tokens[3])
                bmsStatus.text = "BMS Status: " + (bmsConnected ? "Connected" : "Not Connected")
                bmsStatus.color = bmsConnected ? "green" : "red"
                var bmsStatusTemp = Number(tokens[4])
                bmsError.text = "BMS Error: " + bmsStatusTemp + "\nCharging: " + ((bmsStatusTemp & 0x20)>0) + "\nEmpty: " + ((bmsStatusTemp & 0x04)>0) + "\nTemp: " + ((bmsStatusTemp & 0x03)>0) + "\nOvercharge: " + ((bmsStatusTemp & 0x08)>0) + "\nSoC Calibration: " + ((bmsStatusTemp & 0x40)>0)
                bmsBatteryType.text = "Battery Type: " + Number(tokens[5])
                bmsBatteryCycles.text = "Battery Cycles: " + Number(tokens[6])

                // Humidity Sensor Status
                var hum = parseFloat(tokens[8])
                var humTemp = parseFloat(tokens[9])
                humidityStatus.text = "LCM Humidity: " + (hum>-100 ? hum +"%" : "Unknown")
                humidityStatus.color = hum>-100 ? (hum < 65 ? "green" :hum < 80 ? "orange" : "red") : "grey"
                humidityTempStatus.text = "LCM Temp: " + (humTemp>-100 ?  Math.floor((humTemp * 1.8 + 32) * 100)/100 +"F " + humTemp + "C" : "Unknown")
                humidityTempStatus.color = humTemp>-100 ? "green" : "grey"

                var bmsHum = parseFloat(tokens[10])
                var bmsHumTemp = parseFloat(tokens[11])
                bmsHumStatus.text = "BMS Humidity: " + (bmsHum ? bmsHum +"%" : "Unknown")
                bmsHumStatus.color = bmsHum ? (bmsHum < 65 ? "green" : bmsHum < 80 ? "orange" : "red") : "grey"
                bmsHumTempStatus.text = "BMS Temp: " + (bmsHumTemp ? Math.floor((bmsHumTemp * 1.8 + 32) * 100)/100 +"F " + bmsHumTemp + "C" : "Unknown")
                bmsHumTempStatus.color = bmsHumTemp ? "green" : "grey"

                // Update status flags
                lastStatusTime = 0  // Reset the timer when status is received
                statusTimeout = false
            } else if (str.startsWith("control")) {
                var tokens = str.split(" ")
                ledOn.checked = Number(tokens[1])
                ledHighbeamOn.checked = Number(tokens[2])
                ledBrightness.value = Number(tokens[3])
                ledBrightnessHighbeam.value = parseFloat(Number(tokens[4]))
                ledBrightnessIdle.value = Number(tokens[5])
                ledBrightnessStatus.value = Number(tokens[6])
                bmsChargeState.checked = Number(tokens[7])
            } else if (str.startsWith("status Settings Read")) {
                sendCode(String.fromCharCode(102) + String.fromCharCode(1) + "(send-control)")
                var msg = str.substring(7)
                VescIf.emitStatusMessage(msg, true)
            } else if (str.startsWith("status")) {
                var msg = str.substring(7)
                VescIf.emitStatusMessage(msg, true)
            }
        }
    }
}