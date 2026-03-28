import SwiftUI

struct AudioDevicesView: View {
    var deviceManager: AudioDeviceManager = .shared

    var body: some View {
        Form {
            Section("Input Device") {
                Picker("Input Mode", selection: Binding(
                    get: { deviceManager.useSystemDefaultInput },
                    set: { newValue in
                        deviceManager.useSystemDefaultInput = newValue
                        deviceManager.savePreferences()
                    }
                )) {
                    Text("Follow System Default").tag(true)
                    Text("Use Specific Device").tag(false)
                }
                .pickerStyle(.radioGroup)
                .labelsHidden()

                Picker("Input Device", selection: Binding(
                    get: { deviceManager.selectedInputDeviceUID ?? "" },
                    set: { newValue in
                        deviceManager.selectedInputDeviceUID = newValue.isEmpty ? nil : newValue
                        deviceManager.savePreferences()
                    }
                )) {
                    Text("Select a device...").tag("")
                    ForEach(deviceManager.availableInputDevices) { device in
                        Text(device.name).tag(device.uid)
                    }
                }
                .disabled(deviceManager.useSystemDefaultInput)
            }

            Section("Output Device") {
                Picker("Output Mode", selection: Binding(
                    get: { deviceManager.useSystemDefaultOutput },
                    set: { newValue in
                        deviceManager.useSystemDefaultOutput = newValue
                        deviceManager.savePreferences()
                    }
                )) {
                    Text("Follow System Default").tag(true)
                    Text("Use Specific Device").tag(false)
                }
                .pickerStyle(.radioGroup)
                .labelsHidden()

                Picker("Output Device", selection: Binding(
                    get: { deviceManager.selectedOutputDeviceUID ?? "" },
                    set: { newValue in
                        deviceManager.selectedOutputDeviceUID = newValue.isEmpty ? nil : newValue
                        deviceManager.savePreferences()
                    }
                )) {
                    Text("Select a device...").tag("")
                    ForEach(deviceManager.availableOutputDevices) { device in
                        Text(device.name).tag(device.uid)
                    }
                }
                .disabled(deviceManager.useSystemDefaultOutput)
            }
        }
        .formStyle(.grouped)
        .onAppear {
            deviceManager.refreshDevices()
            deviceManager.loadPreferences()
        }
    }
}
