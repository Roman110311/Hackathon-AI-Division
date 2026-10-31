import SwiftUI

/// A short, optional non-clinical setup. Samples are local and discarded after calculation.
struct CalibrationScreen: View {
    @ObservedObject var motion: MotionSensorManager
    @AppStorage("motionEnabled") private var enabled = true
    @AppStorage("sensitivity") private var sensitivity = 1.0
    @AppStorage("tolerance") private var tolerance = 12.0
    @AppStorage("expansion") private var expansion = 6.0
    @AppStorage("calibrationBaseline") private var savedBaseline = 0.0
    @State private var stage = 0
    @State private var collecting = false
    @State private var baseline = 0.0
    @State private var deliberate = 0.0
    @State private var touches = 0
    @State private var message = ""
    @State private var captureTask: Task<Void, Never>?
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("Guided calibration").font(.largeTitle.bold())
                Text("Use a comfortable grip. These measurements are for interface settings, not a medical assessment.")
                if stage == 0 {
                    Text("1. Hold your phone naturally").font(.title2.bold())
                    Text("We will sample your normal motion for three seconds. You do not need to hold still.")
                    PortalButton(title: "Measure natural motion") { capture(next: 1) }
                } else if stage == 1 {
                    Text("2. Move deliberately").font(.title2.bold())
                    Text("Gently tilt the phone while we sample for three seconds.")
                    PortalButton(title: "Measure deliberate movement") { capture(next: 2) }
                } else if stage == 2 {
                    Text("3. Practice tapping").font(.title2.bold())
                    Text("Tap the practice button three times. No precision is required.")
                    PortalButton(title: "Practice tap \(min(touches, 3)) of 3") { touches += 1; if touches >= 3 { stage = 3 } }
                } else {
                    Text("Recommended settings").font(.title2.bold())
                    Text("Natural rotation average: \(baseline, specifier: "%.3f") rad/s")
                    Text("Deliberate rotation average: \(deliberate, specifier: "%.3f") rad/s")
                    Text("Motion sensitivity: \(recommendedSensitivity, specifier: "%.1f"). Touch expansion and tolerance use conservative defaults; the practice taps do not measure accuracy.")
                    PortalButton(title: "Apply Settings") { sensitivity = recommendedSensitivity; expansion = 6; tolerance = 12; savedBaseline = baseline; motion.recenter(); dismiss() }
                    PortalButton(title: "Try Again", secondary: true) { stage = 0; touches = 0; message = "" }
                    PortalButton(title: "Restore Defaults", secondary: true) { sensitivity = 1; expansion = 6; tolerance = 12; savedBaseline = 0; motion.recenter() }
                }
                if collecting { ProgressView("Collecting samples…") }
                if !message.isEmpty { Text(message).foregroundStyle(.secondary) }
                PortalButton(title: "Skip", secondary: true) { dismiss() }
            }.padding(20).frame(maxWidth: .infinity, alignment: .leading)
        }
        .navigationTitle("Calibration").navigationBarTitleDisplayMode(.inline)
        .onDisappear { captureTask?.cancel(); if !enabled { motion.stop() } }
    }
    private var recommendedSensitivity: Double { baseline > 0.12 ? 0.8 : (baseline < 0.025 ? 1.2 : 1.0) }
    private func capture(next: Int) {
        guard !collecting else { return }
        guard !motion.simulationEnabled else { message = "Turn off simulated motion to calibrate using your phone."; return }
        // Start on demand: calibration needs actual sensor samples even if the user
        // previously disabled the visual stabilization setting.
        motion.start()
        guard motion.isRunning else { message = motion.statusMessage; return }
        collecting = true; message = ""
        captureTask = Task { @MainActor in
            var values: [Double] = []
            var lastTimestamp: TimeInterval = -1
            // Allow the hardware a short startup period before the 3-second sample.
            for _ in 0..<40 {
                if motion.state.sample != nil || !motion.isRunning { break }
                do { try await Task.sleep(nanoseconds: 50_000_000) } catch { collecting = false; return }
            }
            guard motion.isRunning else { collecting = false; message = motion.statusMessage; return }
            for _ in 0..<60 {
                do { try await Task.sleep(nanoseconds: 50_000_000) } catch { collecting = false; return }
                if let sample = motion.state.sample, sample.timestamp != lastTimestamp {
                    values.append(hypot(sample.rotationX, sample.rotationY)); lastTimestamp = sample.timestamp
                }
            }
            collecting = false
            guard values.count >= 10 else { message = "Not enough motion readings. \(motion.statusMessage) Please try again."; return }
            let average = values.reduce(0, +) / Double(values.count)
            if next == 1 { baseline = average; motion.recenter() } else { deliberate = average }
            stage = next
        }
    }
}
