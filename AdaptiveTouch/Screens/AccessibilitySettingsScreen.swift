import SwiftUI

struct AccessibilitySettingsScreen: View {
    @ObservedObject var motion: MotionSensorManager
    @AppStorage("motionEnabled") private var enabled = true
    @AppStorage("strength") private var strength = 0.5
    @AppStorage("maxOffset") private var maxOffset = 12.0
    @AppStorage("sensitivity") private var sensitivity = 1.0
    @AppStorage("margin") private var margin = 0.07
    @AppStorage("freezeTouch") private var freezeTouch = true
    @AppStorage("expansion") private var expansion = 6.0
    @AppStorage("tolerance") private var tolerance = 12.0
    @AppStorage("touchMode") private var mode = "protected"
    @AppStorage("holdDuration") private var hold = 0.5
    @AppStorage("duplicates") private var duplicates = true
    @AppStorage("haptics") private var haptics = true
    @AppStorage("reduceMotion") private var reduced = false
    @AppStorage("simulation") private var simulation = false
    @AppStorage("debugOverlay") private var debug = false
    var body: some View {
        Form {
            Section("Motion stabilization") {
                Toggle("Stabilization", isOn: $enabled)
                slider("Strength", value: $strength, range: 0...1)
                slider("Maximum offset (points)", value: $maxOffset, range: 0...24)
                slider("Motion sensitivity", value: $sensitivity, range: 0.5...2)
                slider("Outer margin", value: $margin, range: 0.04...0.12)
                Toggle("Pause movement while pressing", isOn: $freezeTouch)
                Button("Recenter") { motion.recenter() }.frame(minHeight: 44)
                Button("Restore motion defaults") { enabled = true; strength = 0.5; maxOffset = 12; sensitivity = 1; margin = 0.07; freezeTouch = true; motion.recenter() }.frame(minHeight: 44)
            }
            Section("Touch assistance") {
                slider("Target expansion (points)", value: $expansion, range: 0...16)
                slider("Movement tolerance (points)", value: $tolerance, range: 4...30)
                Picker("Touch protection", selection: $mode) {
                    Text("Normal").tag("normal"); Text("Protected").tag("protected"); Text("Hold to activate").tag("hold")
                }
                if mode == "hold" { slider("Hold duration (seconds)", value: $hold, range: 0.3...0.8) }
                Toggle("Prevent repeated activations", isOn: $duplicates)
            }
            Section("Display and feedback") {
                Toggle("Reduce motion", isOn: $reduced)
                Toggle("Haptic feedback", isOn: $haptics)
                Text("Text size and contrast follow your iPhone accessibility settings.").font(.footnote)
            }
            Section("Developer") {
                Toggle("Simulated motion", isOn: $simulation)
                Toggle("Debug overlay", isOn: $debug)
                NavigationLink("Sensor diagnostics") { DiagnosticsScreen(motion: motion) }.frame(minHeight: 44)
            }
        }.navigationTitle("Accessibility").navigationBarTitleDisplayMode(.inline)
    }
    private func slider(_ label: String, value: Binding<Double>, range: ClosedRange<Double>) -> some View {
        VStack(alignment: .leading) { Text("\(label): \(value.wrappedValue, specifier: "%.2f")"); Slider(value: value, in: range).accessibilityLabel(label) }.padding(.vertical, 4)
    }
}

struct DiagnosticsScreen: View {
    @ObservedObject var motion: MotionSensorManager
    var body: some View {
        List {
            Text(motion.simulationEnabled ? "Simulation Active" : "Physical sensor")
            Text("Sensor available: \(motion.isAvailable ? "Yes" : "No")")
            Text("Status: \(motion.statusMessage)")
            Text("Updates running: \(motion.isRunning ? "Yes" : "No")")
            #if targetEnvironment(simulator)
            Text("Running in iOS Simulator")
            #else
            Text("Running on a device")
            #endif
            Button("Retry motion updates") { motion.stop(); motion.start() }
            Text("State: \(motion.state.classification.rawValue)")
            Text("Confidence: \(motion.state.confidence, specifier: "%.2f")")
            Text("Offset: \(motion.state.offset.width, specifier: "%.1f"), \(motion.state.offset.height, specifier: "%.1f") points")
            Text("Sample rate: \(motion.state.actualFrequency, specifier: "%.1f") Hz")
            if let s = motion.state.sample {
                Text("Rotation (rad/s): \(s.rotationX, specifier: "%.3f"), \(s.rotationY, specifier: "%.3f"), \(s.rotationZ, specifier: "%.3f")")
                Text("Attitude (rad): \(s.roll, specifier: "%.3f"), \(s.pitch, specifier: "%.3f"), \(s.yaw, specifier: "%.3f")")
                Text("User acceleration (g): \(s.accelerationX, specifier: "%.3f"), \(s.accelerationY, specifier: "%.3f"), \(s.accelerationZ, specifier: "%.3f")")
            }
        }.navigationTitle("Diagnostics")
    }
}
