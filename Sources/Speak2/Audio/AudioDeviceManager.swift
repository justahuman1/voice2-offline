import CoreAudio
import AudioToolbox
import Foundation

struct AudioDevice: Identifiable, Hashable {
    let id: AudioDeviceID
    let uid: String
    let name: String
    let hasInput: Bool
    let hasOutput: Bool
}

@Observable
@MainActor
final class AudioDeviceManager {
    static let shared = AudioDeviceManager()

    var availableInputDevices: [AudioDevice] = []
    var availableOutputDevices: [AudioDevice] = []
    var useSystemDefaultInput: Bool = true
    var useSystemDefaultOutput: Bool = true
    var selectedInputDeviceUID: String? = nil
    var selectedOutputDeviceUID: String? = nil

    func refreshDevices() {
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        var dataSize: UInt32 = 0
        var status = AudioObjectGetPropertyDataSize(
            AudioObjectID(kAudioObjectSystemObject),
            &propertyAddress,
            0, nil,
            &dataSize
        )
        guard status == noErr else { return }

        let deviceCount = Int(dataSize) / MemoryLayout<AudioDeviceID>.size
        var deviceIDs = [AudioDeviceID](repeating: 0, count: deviceCount)
        status = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &propertyAddress,
            0, nil,
            &dataSize,
            &deviceIDs
        )
        guard status == noErr else { return }

        var inputs: [AudioDevice] = []
        var outputs: [AudioDevice] = []

        for deviceID in deviceIDs {
            guard let device = queryDevice(deviceID) else { continue }
            if device.uid == "system_default" { continue }
            if device.hasInput { inputs.append(device) }
            if device.hasOutput { outputs.append(device) }
        }

        availableInputDevices = inputs
        availableOutputDevices = outputs
    }

    func savePreferences() {
        let defaults = UserDefaults.standard
        defaults.set(useSystemDefaultInput, forKey: "useSystemDefaultInput")
        defaults.set(useSystemDefaultOutput, forKey: "useSystemDefaultOutput")
        defaults.set(selectedInputDeviceUID, forKey: "selectedInputDeviceUID")
        defaults.set(selectedOutputDeviceUID, forKey: "selectedOutputDeviceUID")
    }

    func loadPreferences() {
        let defaults = UserDefaults.standard
        if defaults.object(forKey: "useSystemDefaultInput") != nil {
            useSystemDefaultInput = defaults.bool(forKey: "useSystemDefaultInput")
        }
        if defaults.object(forKey: "useSystemDefaultOutput") != nil {
            useSystemDefaultOutput = defaults.bool(forKey: "useSystemDefaultOutput")
        }
        selectedInputDeviceUID = defaults.string(forKey: "selectedInputDeviceUID")
        selectedOutputDeviceUID = defaults.string(forKey: "selectedOutputDeviceUID")
    }

    private func queryDevice(_ deviceID: AudioDeviceID) -> AudioDevice? {
        // Get UID
        var uidAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyDeviceUID,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var uid: CFString = "" as CFString
        var uidSize = UInt32(MemoryLayout<CFString>.size)
        let uidStatus = AudioObjectGetPropertyData(deviceID, &uidAddress, 0, nil, &uidSize, &uid)
        guard uidStatus == noErr else { return nil }

        // Get name
        var nameAddress = AudioObjectPropertyAddress(
            mSelector: kAudioObjectPropertyName,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var name: CFString = "" as CFString
        var nameSize = UInt32(MemoryLayout<CFString>.size)
        let nameStatus = AudioObjectGetPropertyData(deviceID, &nameAddress, 0, nil, &nameSize, &name)
        guard nameStatus == noErr else { return nil }

        // Check input streams
        let hasInput = streamCount(deviceID: deviceID, scope: kAudioObjectPropertyScopeInput) > 0
        let hasOutput = streamCount(deviceID: deviceID, scope: kAudioObjectPropertyScopeOutput) > 0

        return AudioDevice(
            id: deviceID,
            uid: uid as String,
            name: name as String,
            hasInput: hasInput,
            hasOutput: hasOutput
        )
    }

    private func streamCount(deviceID: AudioDeviceID, scope: AudioObjectPropertyScope) -> Int {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyStreams,
            mScope: scope,
            mElement: kAudioObjectPropertyElementMain
        )
        var dataSize: UInt32 = 0
        let status = AudioObjectGetPropertyDataSize(deviceID, &address, 0, nil, &dataSize)
        guard status == noErr else { return 0 }
        return Int(dataSize) / MemoryLayout<AudioStreamID>.size
    }
}
