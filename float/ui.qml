/*
    Copyright 2022 Benjamin Vedder	benjamin@vedder.se

    This file is part of VESC Tool.

    VESC Tool is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    VESC Tool is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with this program.  If not, see <http://www.gnu.org/licenses/>.
    */

import QtQuick 2.12
import QtQuick.Controls 2.12
import QtQuick.Layouts 1.3

import Vedder.vesc.utility 1.0
import Vedder.vesc.commands 1.0
import Vedder.vesc.configparams 1.0

// This example shows how to read and write settings using the custom
// config. It is also possible to send and receive custom data using
// send_app_data and set_app_data_handler on the euc-side and Commands
// onCustomAppDataReceived and mCommands.sendCustomAppData in qml.

Item {
    id: mainItem
    anchors.fill: parent
    anchors.margins: 5

    property Commands mCommands: VescIf.commands()
    property ConfigParams mMcConf: VescIf.mcConfig()
    property ConfigParams mAppConf: VescIf.appConfig()
    property ConfigParams mCustomConf: VescIf.customConfig(0)

    property var dialogParent: ApplicationWindow.overlay
    
    // Timer 1, 10hz for ble comms
    Timer {
        running: true
        repeat: true
        interval: 100
        
        onTriggered: {
            // Poll app data
            var buffer = new ArrayBuffer(2)
            var dv = new DataView(buffer)
            var ind = 0
            dv.setUint8(ind, 101); ind += 1
            dv.setUint8(ind, 0x1); ind += 1
            mCommands.sendCustomAppData(buffer)
            
            // Process Controls
            if(reverseButton.pressed){
                var buffer = new ArrayBuffer(6)
                var dv = new DataView(buffer)
                var ind = 0
                dv.setUint8(ind, 101); ind += 1; // Float Package
                dv.setUint8(ind, 7); ind += 1; // Command ID: RC Move
                dv.setUint8(ind, 0); ind += 1; // Direction
                dv.setUint8(ind, movementStrengthSlider.value); ind += 1; // Current
                dv.setUint8(ind, 1); ind += 1; // Time
                dv.setUint8(ind, movementStrengthSlider.value + 1); ind += 1; // Sum = time + current
                mCommands.sendCustomAppData(buffer)
            }
            if(forwardButton.pressed){
                var buffer = new ArrayBuffer(6)
                var dv = new DataView(buffer)
                var ind = 0
                dv.setUint8(ind, 101); ind += 1; // Float Package
                dv.setUint8(ind, 7); ind += 1; // Command ID: RC Move
                dv.setUint8(ind, 1); ind += 1; // Direction
                dv.setUint8(ind, movementStrengthSlider.value); ind += 1; // Current
                dv.setUint8(ind, 1); ind += 1; // Time
                dv.setUint8(ind, movementStrengthSlider.value + 1); ind += 1; // Sum = time + current
                mCommands.sendCustomAppData(buffer)
            }
            if(tiltEnabled.checked){
                mCommands.lispSendReplCmd("(set-remote-state " + tiltSlider.value + " 0 0 0 0)")
            }
        }
    }

    // Timer 2, 100hz for for UI updates
    Timer {
        running: true
        repeat: true
        interval: 10
        
        onTriggered: {
            if(!tiltSlider.pressed){
                var stepSize = 0.05
                if(tiltSlider.value > 0){
                    if(tiltSlider.value < stepSize){
                        tiltSlider.value = 0
                    }else{
                        tiltSlider.value -= stepSize
                    }
                }else if(tiltSlider.value < 0){
                    if(tiltSlider.value > -stepSize){
                        tiltSlider.value = 0
                    }else{
                        tiltSlider.value += stepSize
                    }
                } 
            }
        }
    }
    
    Connections {
        target: mCommands
        
        // This function will be called when VESC_IF->send_app_data is used. To
        // send data back mCommands.sendCustomAppData can be used. That data
        // will be received in the function registered with VESC_IF->set_app_data_handler
        onCustomAppDataReceived: {
            // Ints and floats can be extracted like this from the data
            var dv = new DataView(data, 0)
            var ind = 0
            var magicnr = dv.getUint8(ind); ind += 1;
            var msgtype = dv.getUint8(ind); ind += 1;

            if (magicnr != 101) {
                return;
            }
            if (msgtype == 1) {
                var pid_value = dv.getFloat32(ind); ind += 4;
                var pitch = dv.getFloat32(ind); ind += 4;
                var roll = dv.getFloat32(ind); ind += 4;
                var state = dv.getInt8(ind); ind += 1;
                var setpointAdjustmentType = state >> 4;
                state = state &0xF;
                var switch_state = dv.getInt8(ind); ind += 1;
                var adc1 = dv.getFloat32(ind); ind += 4;
                var adc2 = dv.getFloat32(ind); ind += 4;

                var float_setpoint = dv.getFloat32(ind); ind += 4;
                var float_atr = dv.getFloat32(ind); ind += 4;
                var float_braketilt = dv.getFloat32(ind); ind += 4;
                var float_torquetilt = dv.getFloat32(ind); ind += 4;
                var float_turntilt = dv.getFloat32(ind); ind += 4;
                var float_inputtilt = dv.getFloat32(ind); ind += 4;

                var true_pitch = dv.getFloat32(ind); ind += 4;
                var filtered_current = dv.getFloat32(ind); ind += 4;
                var float_acc_diff = dv.getFloat32(ind); ind += 4;
                var applied_booster_current = dv.getFloat32(ind); ind += 4;
                var motor_current = dv.getFloat32(ind); ind += 4;
                var throttle_val = dv.getFloat32(ind); ind += 4;

                // var debug1 = dv.getFloat32(ind); ind += 4;
                // var debug2 = dv.getFloat32(ind); ind += 4;

                var stateString
                if(state == 0){
                    stateString = "BOOT"	// we're in this state only for the first second or so then never again
                }else if(state == 1){
                    stateString = "RUNNING"
                }else if(state == 2){
                    stateString = "RUNNING_TILTBACK"
                }else if(state == 3){
                    stateString = "RUNNING_WHEELSLIP"
                }else if(state == 4){
                    stateString = "RUNNING_UPSIDEDOWN"
                }else if(state == 6){
                    stateString = "STOP_ANGLE_PITCH"
                }else if(state == 7){
                    stateString = "STOP_ANGLE_ROLL"
                }else if(state == 8){
                    stateString = "STOP_SWITCH_HALF"
                }else if(state == 9){
                    stateString = "STOP_SWITCH_FULL"
                }else if(state == 11){
                    if ((roll > 120) || (roll < -120)) {
                        stateString = "STARTUP UPSIDEDOWN"
                    }
                    else {
                        stateString = "STARTUP"
                    }
                }else if(state == 12){
                    stateString = "STOP_REVERSE"
                }else if(state == 13){
                    stateString = "STOP_QUICKSTOP"
                }else{
                    stateString = "UNKNOWN"
                }

                var suffix = ""
                if (setpointAdjustmentType == 0) {
                    suffix = "[CENTERING]";
                } else if (setpointAdjustmentType == 1) {
                    suffix = "[REVERSESTOP]";
                } else if (setpointAdjustmentType == 3) {
                    suffix = "[DUTY]";
                } else if (setpointAdjustmentType == 4) {
                    suffix = "[HV]";
                } else if (setpointAdjustmentType == 5) {
                    suffix = "[LV]";
                } else if (setpointAdjustmentType == 6) {
                    suffix = "[TEMP]";
                }
                if ((state > 0) && (state < 6)) {
                    stateString += suffix;
                }

                var switchString
                if(switch_state == 0){
                    switchString = "Off"
                }else if(switch_state == 1){
                    switchString = "Half"
                    /*HOW TO ACCESS CONFIG FROM QML???
                    if (adc1 >= VescIf.mcConfig().fault_adc1)
                        switchString += " [On|"
                    else
                        switchString += " [Off|"
                    if (adc2 >= VescIf.mcConfig().fault_adc2)
                        switchString += "On]"
                    else
                        switchString += "Off]"*/
                }else{
                    switchString = "On"
                }

                if(state == 15){
                    stateString = "DISABLED"
                    switchString = "Enable in Float Cfg: Specs"
                    rt_state.text = "Float Package is Disabled\n\n" +
                                    "You can re-enable it in\nFloat Cfg: Specs\n\n"
                    rt_data.text = "-- n/a --"
                    setpoints.text = "-- n/a --"
                    debug.text = "-- n/a --"
                }
                else {
                rt_state.text =
                    "State               : " + stateString + "\n" +
                    "Switch              : " + switchString + "\n"

                rt_data.text =
                    "Current (Requested) : " + pid_value.toFixed(2) + "A\n" +
                    "Current (Motor)     : " + motor_current.toFixed(2) + "A\n" +
                    "Pitch               : " + pitch.toFixed(2) + "°\n" +
                    "Roll                : " + roll.toFixed(2) + "°\n" +
                    "ADC1 / ADC2         : " + adc1.toFixed(2) + "V / " + adc2.toFixed(2) + "V\n"

                setpoints.text =
                    "Setpoint            : " + float_setpoint.toFixed(2) + "°\n" +
                    "ATR Setpoint        : " + float_atr.toFixed(2) + "°\n" +
                    "BrakeTilt Setpoint  : " + float_braketilt.toFixed(2) + "°\n" +
                    "TorqueTilt Setpoint : " + float_torquetilt.toFixed(2) + "°\n" +
                    "TurnTilt Setpoint   : " + float_turntilt.toFixed(2) + "°\n" +
                    "RemoteTilt Setpoint  : " + float_inputtilt.toFixed(2) + "°\n"

                debug.text =
                    "True Pitch          : " + true_pitch.toFixed(2) + "°\n" +
                    "Torque              : " + filtered_current.toFixed(2) + "A\n" +
                    "Acc. Diff.          : " + float_acc_diff.toFixed(2) + "\n" +
                    "Booster Current     : " + applied_booster_current.toFixed(2) + "A\n" +
                    "Remote Input        : " + (throttle_val * 100).toFixed(0) + "%\n"
                }
            }
        }
    }

    ColumnLayout {
        id: root
        anchors.fill: parent
    

        TabBar {
            id: tabBar
            currentIndex: 0
            Layout.fillWidth: true
            clip: true
            enabled: true

            background: Rectangle {
                opacity: 1
                color: {color = Utility.getAppHexColor("lightBackground")}
            }
            property int buttons: 3
            property int buttonWidth: 120

            Repeater {
                model: ["RT Data", "Controls", "Tunes"]
                TabButton {
                    text: modelData
                    onClicked:{
                        stackLayout.currentIndex = index
                    }
                }
            }
        }
        
        StackLayout {
            id: stackLayout
            Layout.fillWidth: true
            Layout.fillHeight: true
            // onCurrentIndexChanged: {tabBar.currentIndex = currentIndex

            ColumnLayout { // RT Data Page
                id: rtDataColumn
                
                ScrollView {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    
                    ColumnLayout {
                        Text {
                            id: header0
                            color: Utility.getAppHexColor("lightText")
                            font.family: "DejaVu Sans Mono"
                            Layout.margins: 0
                            Layout.leftMargin: 0
                            Layout.fillWidth: true
                            text: "Float App State"
                            font.underline: true
                            font.weight: Font.Black
                            font.pointSize: 14
                        }
                        Text {
                            id: rt_state
                            color: Utility.getAppHexColor("lightText")
                            font.family: "DejaVu Sans Mono"
                            Layout.margins: 0
                            Layout.leftMargin: 5
                            Layout.preferredWidth: parent.width/3
                            text: "Waiting for RT Data"
                        }
                        Text {
                            id: header1
                            color: Utility.getAppHexColor("lightText")
                            font.family: "DejaVu Sans Mono"
                            Layout.margins: 0
                            Layout.leftMargin: 0
                            Layout.fillWidth: true
                            text: "Float App RT Data"
                            font.underline: true
                            font.weight: Font.Black
                            font.pointSize: 14
                        }
                        Text {
                            id: rt_data
                            color: Utility.getAppHexColor("lightText")
                            font.family: "DejaVu Sans Mono"
                            Layout.margins: 0
                            Layout.leftMargin: 5
                            Layout.preferredWidth: parent.width/3
                            text: "-\n"
                        }
                        Text {
                            id: header2
                            color: Utility.getAppHexColor("lightText")
                            font.family: "DejaVu Sans Mono"
                            Layout.margins: 0
                            Layout.leftMargin: 0
                            Layout.fillWidth: true
                            text: "Setpoints"
                            font.underline: true
                            font.weight: Font.Black
                            font.pointSize: 14
                        }
                        Text {
                            id: setpoints
                            color: Utility.getAppHexColor("lightText")
                            font.family: "DejaVu Sans Mono"
                            Layout.margins: 0
                            Layout.leftMargin: 5
                            Layout.preferredWidth: parent.width/3
                            text: "-\n"
                        }
                        Text {
                            id: header3
                            color: Utility.getAppHexColor("lightText")
                            font.family: "DejaVu Sans Mono"
                            Layout.margins: 0
                            Layout.leftMargin: 0
                            Layout.fillWidth: true
                            text: "DEBUG"
                            font.underline: true
                            font.weight: Font.Black
                        }
                        Text {
                            id: debug
                            color: Utility.getAppHexColor("lightText")
                            font.family: "DejaVu Sans Mono"
                            Layout.margins: 0
                            Layout.leftMargin: 5
                            Layout.preferredWidth: parent.width/3
                            text: "-"
                        }
                    }
                }
            }

            ColumnLayout { // Controls Page
                id: controlsColumn
                Layout.fillWidth: true

                // Movement controls
                Text {
                    id: movementControlsHeader
                    color: Utility.getAppHexColor("lightText")
                    font.family: "DejaVu Sans Mono"
                    Layout.margins: 0
                    Layout.leftMargin: 0
                    Layout.fillWidth: true
                    text: "Movement Controls"
                    font.underline: true
                    font.weight: Font.Black
                    font.pointSize: 14
                }
                RowLayout {
                    id: movementStrength
                    Layout.fillWidth: true

                    Text {
                        id: movementStrengthLabel
                        color: Utility.getAppHexColor("lightText")
                        font.family: "DejaVu Sans Mono"
                        text: "Strength:"
                    }
                    Slider {
                        id: movementStrengthSlider
                        from: 20
                        value: 40
                        to: 80
                        stepSize: 1
                    }
                }
                RowLayout {
                    id: movementControls
                    Layout.fillWidth: true
                    Button {
                        id: reverseButton
                        text: "Reverse"
                        Layout.fillWidth: true
                    }
                    Button {
                        id: forwardButton
                        text: "Forward"
                        Layout.fillWidth: true
                    }
                }
                
                // Tilt controls
                Text {
                    id: tiltControlsHeader
                    color: Utility.getAppHexColor("lightText")
                    font.family: "DejaVu Sans Mono"
                    Layout.margins: 0
                    Layout.leftMargin: 0
                    Layout.fillWidth: true
                    text: "Tilt Controls"
                    font.underline: true
                    font.weight: Font.Black
                    font.pointSize: 14
                }
                 CheckBox {
                    id: tiltEnabled
                    checked: false
                    text: qsTr("Enabled (Overrides Remote)")
                    onClicked: {
                        if(tiltEnabled.checked && mCustomConf.getParamEnum("inputtilt_remote_type", 0) != 1){
                            mCustomConf.updateParamEnum("inputtilt_remote_type", 1)
                            mCommands.customConfigSet(0, mCustomConf)
                        }
                    }
                }
                Slider {
                    id: tiltSlider
                    from: -1
                    value: 0
                    to: 1
                    Layout.fillWidth: true
                }
            }

            ColumnLayout { // Tunes Page
                id: profilesColumn
                
                Button {
                    id: tuneButtonMitch
                    text: "Apply Mitch's The BESTEST Tune"
                    Layout.fillWidth: true
                    onClicked: {
                        // mCustomConf.updateParamFloat("float_version", 0)
                        mCustomConf.updateParamDouble("kp", 10)
                        mCustomConf.updateParamDouble("ki", 0)
                        mCustomConf.updateParamDouble("kd", 0)
                        mCustomConf.updateParamDouble("kp2", 1.0)
                        mCustomConf.updateParamDouble("mahony_kp", 2.3)
                        // mCustomConf.updateParamInt("hertz", 400)
                        // mCustomConf.updateParamDouble("fault_pitch", 0)
                        // mCustomConf.updateParamDouble("fault_roll", 0)
                        // mCustomConf.updateParamDouble("fault_adc1", 0)
                        // mCustomConf.updateParamDouble("fault_adc2", 0)
                        // mCustomConf.updateParamInt("fault_delay_pitch", 0)
                        // mCustomConf.updateParamInt("fault_delay_roll", 0)
                        // mCustomConf.updateParamInt("fault_delay_switch_half", 0)
                        // mCustomConf.updateParamInt("fault_delay_switch_full", 0)
                        // mCustomConf.updateParamInt("fault_adc_half_erpm", 0)
                        // mCustomConf.updateParamBool("fault_is_dual_switch", 0)
                        // mCustomConf.updateParamBool("fault_moving_fault_disabled", 0)
                        // mCustomConf.updateParamBool("fault_darkride_enabled", 0)
                        // mCustomConf.updateParamBool("fault_reversestop_enabled", 0)
                        // mCustomConf.updateParamDouble("tiltback_duty_angle", 0)
                        // mCustomConf.updateParamDouble("tiltback_duty_speed", 0)
                        // mCustomConf.updateParamDouble("tiltback_duty", 0)
                        // mCustomConf.updateParamDouble("tiltback_hv_angle", 0)
                        // mCustomConf.updateParamDouble("tiltback_hv_speed", 0)
                        // mCustomConf.updateParamDouble("tiltback_hv", 0)
                        // mCustomConf.updateParamDouble("tiltback_lv_angle", 0)
                        // mCustomConf.updateParamDouble("tiltback_lv_speed", 0)
                        // mCustomConf.updateParamDouble("tiltback_lv", 0)
                        // mCustomConf.updateParamDouble("tiltback_return_speed", 0)
                        mCustomConf.updateParamDouble("tiltback_constant", 0)
                        // mCustomConf.updateParamInt("tiltback_constant_erpm", 0)
                        mCustomConf.updateParamDouble("tiltback_variable", 0)
                        // mCustomConf.updateParamDouble("tiltback_variable_max", 0)
                        // mCustomConf.updateParamEnum("inputtilt_remote_type", 0)
                        // mCustomConf.updateParamDouble("inputtilt_speed", 0)
                        // mCustomConf.updateParamDouble("inputtilt_angle_limit", 0)
                        // mCustomConf.updateParamBool("inputtilt_invert_throttle", 0)
                        // mCustomConf.updateParamDouble("inputtilt_deadband", 0)
                        // mCustomConf.updateParamDouble("noseangling_speed", 0)
                        // mCustomConf.updateParamDouble("startup_pitch_tolerance", 0)
                        // mCustomConf.updateParamDouble("startup_roll_tolerance", 0)
                        // mCustomConf.updateParamDouble("startup_speed", 0)
                        // mCustomConf.updateParamDouble("startup_click_current", 0)
                        mCustomConf.updateParamBool("startup_softstart_enabled", false)
                        // mCustomConf.updateParamBool("startup_simplestart_enabled", 0)
                        // mCustomConf.updateParamBool("startup_pushstart_enabled", 0)
                        // mCustomConf.updateParamBool("startup_dirtylandings_enabled", 0)
                        // mCustomConf.updateParamDouble("brake_current", 0)
                        // mCustomConf.updateParamDouble("ki_limit", 0)
                        // mCustomConf.updateParamDouble("booster_angle", 0)
                        // mCustomConf.updateParamDouble("booster_ramp", 0)
                        mCustomConf.updateParamDouble("booster_current", 0)
                        mCustomConf.updateParamDouble("torquetilt_start_current", 5)
                        mCustomConf.updateParamDouble("torquetilt_angle_limit", 8)
                        mCustomConf.updateParamDouble("torquetilt_on_speed", 5)
                        mCustomConf.updateParamDouble("torquetilt_off_speed", 3)
                        mCustomConf.updateParamDouble("torquetilt_strength", 0.15)
                        mCustomConf.updateParamDouble("torquetilt_strength_regen", 0.15)
                        mCustomConf.updateParamDouble("atr_strength_up", 0)
                        mCustomConf.updateParamDouble("atr_strength_down", 0)
                        mCustomConf.updateParamDouble("atr_torque_offset", 0)
                        mCustomConf.updateParamDouble("atr_speed_boost", 0)
                        mCustomConf.updateParamDouble("atr_angle_limit", 0)
                        mCustomConf.updateParamDouble("atr_on_speed", 0)
                        mCustomConf.updateParamDouble("atr_off_speed", 0)
                        mCustomConf.updateParamDouble("atr_response_boost", 0)
                        mCustomConf.updateParamDouble("atr_transition_boost", 0)
                        mCustomConf.updateParamDouble("atr_filter", 0)
                        mCustomConf.updateParamDouble("atr_amps_accel_ratio", 0)
                        mCustomConf.updateParamDouble("atr_amps_decel_ratio", 0)
                        mCustomConf.updateParamDouble("braketilt_strength", 0)
                        // mCustomConf.updateParamDouble("braketilt_lingering", 0)
                        mCustomConf.updateParamDouble("turntilt_strength", 0)
                        // mCustomConf.updateParamDouble("turntilt_angle_limit", 0)
                        // mCustomConf.updateParamDouble("turntilt_start_angle", 0)
                        // mCustomConf.updateParamInt("turntilt_start_erpm", 0)
                        // mCustomConf.updateParamDouble("turntilt_speed", 0)
                        // mCustomConf.updateParamInt("turntilt_erpm_boost", 0)
                        // mCustomConf.updateParamInt("turntilt_erpm_boost_end", 0)
                        // mCustomConf.updateParamInt("turntilt_yaw_aggregate", 0)
                        // mCustomConf.updateParamBool("is_buzzer_enabled", 0)
                        mCommands.customConfigSet(0, mCustomConf)
                    }
                }

                Button {
                    id: tuneButtonDefault
                    text: "Lame Default Tune :-/"
                    Layout.fillWidth: true
                    onClicked: {
                        // mCustomConf.updateParamFloat("float_version", 0)
                        mCustomConf.updateParamDouble("kp", 20)
                        mCustomConf.updateParamDouble("ki", 0.005)
                        mCustomConf.updateParamDouble("kd", 0)
                        mCustomConf.updateParamDouble("kp2", 0.6)
                        mCustomConf.updateParamDouble("mahony_kp", 2.0)
                        // mCustomConf.updateParamInt("hertz", 400)
                        // mCustomConf.updateParamDouble("fault_pitch", 0)
                        // mCustomConf.updateParamDouble("fault_roll", 0)
                        // mCustomConf.updateParamDouble("fault_adc1", 0)
                        // mCustomConf.updateParamDouble("fault_adc2", 0)
                        // mCustomConf.updateParamInt("fault_delay_pitch", 0)
                        // mCustomConf.updateParamInt("fault_delay_roll", 0)
                        // mCustomConf.updateParamInt("fault_delay_switch_half", 0)
                        // mCustomConf.updateParamInt("fault_delay_switch_full", 0)
                        // mCustomConf.updateParamInt("fault_adc_half_erpm", 0)
                        // mCustomConf.updateParamBool("fault_is_dual_switch", 0)
                        // mCustomConf.updateParamBool("fault_moving_fault_disabled", 0)
                        // mCustomConf.updateParamBool("fault_darkride_enabled", 0)
                        // mCustomConf.updateParamBool("fault_reversestop_enabled", 0)
                        // mCustomConf.updateParamDouble("tiltback_duty_angle", 0)
                        // mCustomConf.updateParamDouble("tiltback_duty_speed", 0)
                        // mCustomConf.updateParamDouble("tiltback_duty", 0)
                        // mCustomConf.updateParamDouble("tiltback_hv_angle", 0)
                        // mCustomConf.updateParamDouble("tiltback_hv_speed", 0)
                        // mCustomConf.updateParamDouble("tiltback_hv", 0)
                        // mCustomConf.updateParamDouble("tiltback_lv_angle", 0)
                        // mCustomConf.updateParamDouble("tiltback_lv_speed", 0)
                        // mCustomConf.updateParamDouble("tiltback_lv", 0)
                        // mCustomConf.updateParamDouble("tiltback_return_speed", 0)
                        mCustomConf.updateParamDouble("tiltback_constant", 0)
                        // mCustomConf.updateParamInt("tiltback_constant_erpm", 0)
                        mCustomConf.updateParamDouble("tiltback_variable", 0)
                        // mCustomConf.updateParamDouble("tiltback_variable_max", 0)
                        // mCustomConf.updateParamEnum("inputtilt_remote_type", 0)
                        // mCustomConf.updateParamDouble("inputtilt_speed", 0)
                        // mCustomConf.updateParamDouble("inputtilt_angle_limit", 0)
                        // mCustomConf.updateParamBool("inputtilt_invert_throttle", 0)
                        // mCustomConf.updateParamDouble("inputtilt_deadband", 0)
                        mCustomConf.updateParamDouble("noseangling_speed", 5)
                        // mCustomConf.updateParamDouble("startup_pitch_tolerance", 0)
                        // mCustomConf.updateParamDouble("startup_roll_tolerance", 0)
                        // mCustomConf.updateParamDouble("startup_speed", 0)
                        // mCustomConf.updateParamDouble("startup_click_current", 0)
                        mCustomConf.updateParamBool("startup_softstart_enabled", false)
                        // mCustomConf.updateParamBool("startup_simplestart_enabled", 0)
                        // mCustomConf.updateParamBool("startup_pushstart_enabled", 0)
                        // mCustomConf.updateParamBool("startup_dirtylandings_enabled", 0)
                        // mCustomConf.updateParamDouble("brake_current", 0)
                        mCustomConf.updateParamDouble("ki_limit", 30)
                        // mCustomConf.updateParamDouble("booster_angle", 8)
                        // mCustomConf.updateParamDouble("booster_ramp", 4)
                        mCustomConf.updateParamDouble("booster_current", 0)
                        // mCustomConf.updateParamDouble("torquetilt_start_current", 5)
                        // mCustomConf.updateParamDouble("torquetilt_angle_limit", 8)
                        // mCustomConf.updateParamDouble("torquetilt_on_speed", 5)
                        // mCustomConf.updateParamDouble("torquetilt_off_speed", 3)
                        mCustomConf.updateParamDouble("torquetilt_strength", 0.0)
                        mCustomConf.updateParamDouble("torquetilt_strength_regen", 0.0)
                        mCustomConf.updateParamDouble("atr_strength_up", 1)
                        mCustomConf.updateParamDouble("atr_strength_down", 1)
                        mCustomConf.updateParamDouble("atr_torque_offset", 7)
                        mCustomConf.updateParamDouble("atr_speed_boost", 0.3)
                        mCustomConf.updateParamDouble("atr_angle_limit", 8)
                        mCustomConf.updateParamDouble("atr_on_speed", 4)
                        mCustomConf.updateParamDouble("atr_off_speed", 3)
                        mCustomConf.updateParamDouble("atr_response_boost", 1.5)
                        mCustomConf.updateParamDouble("atr_transition_boost", 2.5)
                        mCustomConf.updateParamDouble("atr_filter", 5)
                        mCustomConf.updateParamDouble("atr_amps_accel_ratio", 11)
                        mCustomConf.updateParamDouble("atr_amps_decel_ratio", 10)
                        mCustomConf.updateParamDouble("braketilt_strength", 0)
                        mCustomConf.updateParamDouble("braketilt_lingering", 2)
                        mCustomConf.updateParamDouble("turntilt_strength", 6)
                        mCustomConf.updateParamDouble("turntilt_angle_limit", 3)
                        mCustomConf.updateParamDouble("turntilt_start_angle", 2)
                        mCustomConf.updateParamInt("turntilt_start_erpm", 1000)
                        mCustomConf.updateParamDouble("turntilt_speed", 5)
                        mCustomConf.updateParamInt("turntilt_erpm_boost", 200)
                        mCustomConf.updateParamInt("turntilt_erpm_boost_end", 5000)
                        mCustomConf.updateParamInt("turntilt_yaw_aggregate", 90)
                        // mCustomConf.updateParamBool("is_buzzer_enabled", 0)
                        mCommands.customConfigSet(0, mCustomConf)
                    }
                }

                Button {
                    id: tuneButtonVESCManPint
                    text: "Nana nana nana nana VESCMan (Pint)"
                    Layout.fillWidth: true
                    onClicked: {
                        // mCustomConf.updateParamFloat("float_version", 0)
                        mCustomConf.updateParamDouble("kp", 20)
                        mCustomConf.updateParamDouble("ki", 0.01)
                        mCustomConf.updateParamDouble("kd", 0)
                        mCustomConf.updateParamDouble("kp2", 0.3)
                        mCustomConf.updateParamDouble("mahony_kp", 2.0)
                        // mCustomConf.updateParamInt("hertz", 400)
                        // mCustomConf.updateParamDouble("fault_pitch", 0)
                        // mCustomConf.updateParamDouble("fault_roll", 0)
                        // mCustomConf.updateParamDouble("fault_adc1", 0)
                        // mCustomConf.updateParamDouble("fault_adc2", 0)
                        // mCustomConf.updateParamInt("fault_delay_pitch", 0)
                        // mCustomConf.updateParamInt("fault_delay_roll", 0)
                        // mCustomConf.updateParamInt("fault_delay_switch_half", 0)
                        // mCustomConf.updateParamInt("fault_delay_switch_full", 0)
                        // mCustomConf.updateParamInt("fault_adc_half_erpm", 0)
                        // mCustomConf.updateParamBool("fault_is_dual_switch", 0)
                        // mCustomConf.updateParamBool("fault_moving_fault_disabled", 0)
                        // mCustomConf.updateParamBool("fault_darkride_enabled", 0)
                        // mCustomConf.updateParamBool("fault_reversestop_enabled", 0)
                        // mCustomConf.updateParamDouble("tiltback_duty_angle", 0)
                        // mCustomConf.updateParamDouble("tiltback_duty_speed", 0)
                        // mCustomConf.updateParamDouble("tiltback_duty", 0)
                        // mCustomConf.updateParamDouble("tiltback_hv_angle", 0)
                        // mCustomConf.updateParamDouble("tiltback_hv_speed", 0)
                        // mCustomConf.updateParamDouble("tiltback_hv", 0)
                        // mCustomConf.updateParamDouble("tiltback_lv_angle", 0)
                        // mCustomConf.updateParamDouble("tiltback_lv_speed", 0)
                        // mCustomConf.updateParamDouble("tiltback_lv", 0)
                        // mCustomConf.updateParamDouble("tiltback_return_speed", 0)
                        mCustomConf.updateParamDouble("tiltback_constant", 0)
                        // mCustomConf.updateParamInt("tiltback_constant_erpm", 0)
                        mCustomConf.updateParamDouble("tiltback_variable", 0)
                        // mCustomConf.updateParamDouble("tiltback_variable_max", 0)
                        // mCustomConf.updateParamEnum("inputtilt_remote_type", 0)
                        // mCustomConf.updateParamDouble("inputtilt_speed", 0)
                        // mCustomConf.updateParamDouble("inputtilt_angle_limit", 0)
                        // mCustomConf.updateParamBool("inputtilt_invert_throttle", 0)
                        // mCustomConf.updateParamDouble("inputtilt_deadband", 0)
                        mCustomConf.updateParamDouble("noseangling_speed", 5)
                        // mCustomConf.updateParamDouble("startup_pitch_tolerance", 0)
                        // mCustomConf.updateParamDouble("startup_roll_tolerance", 0)
                        // mCustomConf.updateParamDouble("startup_speed", 0)
                        // mCustomConf.updateParamDouble("startup_click_current", 0)
                        mCustomConf.updateParamBool("startup_softstart_enabled", false)
                        // mCustomConf.updateParamBool("startup_simplestart_enabled", 0)
                        // mCustomConf.updateParamBool("startup_pushstart_enabled", 0)
                        // mCustomConf.updateParamBool("startup_dirtylandings_enabled", 0)
                        // mCustomConf.updateParamDouble("brake_current", 0)
                        mCustomConf.updateParamDouble("ki_limit", 20)
                        mCustomConf.updateParamDouble("booster_angle", 0)
                        mCustomConf.updateParamDouble("booster_ramp", 2)
                        mCustomConf.updateParamDouble("booster_current", 10)
                        mCustomConf.updateParamDouble("torquetilt_start_current", 15)
                        mCustomConf.updateParamDouble("torquetilt_angle_limit", 5)
                        mCustomConf.updateParamDouble("torquetilt_on_speed", 5)
                        mCustomConf.updateParamDouble("torquetilt_off_speed", 10)
                        mCustomConf.updateParamDouble("torquetilt_strength", 0.05)
                        mCustomConf.updateParamDouble("torquetilt_strength_regen", 0.0)
                        mCustomConf.updateParamDouble("atr_strength_up", 0.5)
                        mCustomConf.updateParamDouble("atr_strength_down", 0.5)
                        mCustomConf.updateParamDouble("atr_torque_offset", 7)
                        mCustomConf.updateParamDouble("atr_speed_boost", 0.3)
                        mCustomConf.updateParamDouble("atr_angle_limit", 8)
                        mCustomConf.updateParamDouble("atr_on_speed", 4)
                        mCustomConf.updateParamDouble("atr_off_speed", 3)
                        mCustomConf.updateParamDouble("atr_response_boost", 1.5)
                        mCustomConf.updateParamDouble("atr_transition_boost", 3)
                        mCustomConf.updateParamDouble("atr_filter", 5)
                        mCustomConf.updateParamDouble("atr_amps_accel_ratio", 10)
                        mCustomConf.updateParamDouble("atr_amps_decel_ratio", 15)
                        mCustomConf.updateParamDouble("braketilt_strength", 0)
                        mCustomConf.updateParamDouble("braketilt_lingering", 2)
                        mCustomConf.updateParamDouble("turntilt_strength", 4)
                        mCustomConf.updateParamDouble("turntilt_angle_limit", 2)
                        mCustomConf.updateParamDouble("turntilt_start_angle", 2)
                        mCustomConf.updateParamInt("turntilt_start_erpm", 1000)
                        mCustomConf.updateParamDouble("turntilt_speed", 3)
                        mCustomConf.updateParamInt("turntilt_erpm_boost", 200)
                        mCustomConf.updateParamInt("turntilt_erpm_boost_end", 5000)
                        mCustomConf.updateParamInt("turntilt_yaw_aggregate", 90)
                        // mCustomConf.updateParamBool("is_buzzer_enabled", 0)
                        mCommands.customConfigSet(0, mCustomConf)
                    }
                }
                
            }
                
        }
    }

}
