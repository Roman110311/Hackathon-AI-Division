import SwiftUI

private struct TouchConfigurationKey: EnvironmentKey { static let defaultValue = TouchConfiguration() }
private struct TouchContactKey: EnvironmentKey { static let defaultValue: (Bool) -> Void = { _ in } }
extension EnvironmentValues {
    var touchConfiguration: TouchConfiguration {
        get { self[TouchConfigurationKey.self] }
        set { self[TouchConfigurationKey.self] = newValue }
    }
    var touchContactChanged: (Bool) -> Void {
        get { self[TouchContactKey.self] }
        set { self[TouchContactKey.self] = newValue }
    }
}

@main
struct AdaptiveTouchApp: App {
    var body: some Scene { WindowGroup { AppRoot() } }
}

struct AppRoot: View {
    @StateObject private var motion = MotionSensorManager()
    @State private var demoMode: Bool? = nil
    @Environment(\.scenePhase) private var phase
    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
    @AppStorage("motionEnabled") private var motionEnabled = true
    @AppStorage("strength") private var strength = 0.5
    @AppStorage("maxOffset") private var maxOffset = 12.0
    @AppStorage("sensitivity") private var sensitivity = 1.0
    @AppStorage("margin") private var margin = 0.07
    @AppStorage("freezeTouch") private var freezeTouch = true
    @AppStorage("expansion") private var expansion = 6.0
    @AppStorage("tolerance") private var tolerance = 12.0
    @AppStorage("touchMode") private var touchMode = "protected"
    @AppStorage("holdDuration") private var holdDuration = 0.5
    @AppStorage("duplicates") private var duplicates = true
    @AppStorage("haptics") private var haptics = true
    @AppStorage("reduceMotion") private var reduceMotion = false
    @AppStorage("simulation") private var simulation = false
    @AppStorage("debugOverlay") private var debugOverlay = false

    private var configKey: String { "\(motionEnabled),\(strength),\(maxOffset),\(sensitivity),\(freezeTouch),\(reduceMotion),\(systemReduceMotion),\(simulation),\(String(describing: demoMode))" }
    private var touchConfig: TouchConfiguration {
        var config = TouchConfiguration()
        config.expansion = expansion; config.movementTolerance = tolerance
        config.mode = TouchActivationMode(rawValue: touchMode) ?? .protected
        config.holdDuration = holdDuration; config.duplicateInterval = duplicates ? 0.6 : 0
        config.haptics = haptics
        return config
    }
    var body: some View {
        GeometryReader { geometry in
            let horizontal = geometry.size.width * min(max(margin, 0.04), 0.12)
            let vertical = geometry.size.height * min(max(margin, 0.04), 0.12)
            let x = min(max(motion.state.offset.width, -horizontal), horizontal)
            let y = min(max(motion.state.offset.height, -vertical), vertical)
            ZStack {
                Color.black.ignoresSafeArea()
                HealthcareRootView(
                    settings: { AnyView(AccessibilitySettingsScreen(motion: motion)) },
                    calibration: { AnyView(CalibrationScreen(motion: motion)) },
                    demonstration: { AnyView(DemoScreen(onModeChange: { demoMode = $0 })) }
                )
                .environment(\.touchConfiguration, touchConfig)
                .environment(\.touchContactChanged, { motion.setTouchActive($0) })
                .frame(width: max(1, geometry.size.width - 2 * horizontal), height: max(1, geometry.size.height - 2 * vertical))
                .background(Color(uiColor: .systemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 18))
                .offset(x: x, y: y)
                if simulation || debugOverlay {
                    VStack { Text(simulation ? "Simulation Active" : motion.state.classification.rawValue)
                        .font(.caption.bold()).padding(6).background(.black).foregroundColor(.white)
                        .accessibilityLabel(simulation ? "Simulation Active" : motion.state.classification.rawValue)
                        Spacer() }
                    .allowsHitTesting(false)
                }
            }
        }
        .onAppear { configure(); updateLifecycle() }
        .onChange(of: configKey) { _ in configure(); updateLifecycle() }
        .onChange(of: phase) { _ in updateLifecycle() }
    }
    private func configure() {
        var config = MotionConfiguration()
        config.enabled = motionEnabled && demoMode != false && !reduceMotion && !systemReduceMotion
        config.strength = strength; config.maxOffset = maxOffset
        config.sensitivity = sensitivity; config.freezeDuringTouch = freezeTouch
        motion.updateConfiguration(config)
        motion.simulationEnabled = simulation
    }
    private func updateLifecycle() {
        if phase == .active && (motionEnabled || simulation) { motion.start() } else { motion.stop() }
    }
}
