import Foundation
import CoreGraphics

/// Device coordinates: angular rates in radians/second, attitude in radians,
/// acceleration in g, timestamp in seconds. The portrait screen uses +x right, +y down.
struct MotionSample {
    var timestamp: TimeInterval
    var rotationX: Double
    var rotationY: Double
    var rotationZ: Double
    var roll: Double
    var pitch: Double
    var yaw: Double
    var accelerationX: Double
    var accelerationY: Double
    var accelerationZ: Double
    var gravityX: Double = 0
    var gravityY: Double = 0
    var gravityZ: Double = 0
}

enum MotionClassification: String {
    case still = "Still"
    case tremorLike = "Tremor-like"
    case deliberate = "Deliberate movement"
    case sudden = "Sudden movement"
    case uncertain = "Uncertain"
}

struct MotionConfiguration {
    var enabled = true
    /// Multiplier applied to the short-term acceleration response.
    var strength: Double = 0.75
    /// Points; the container must additionally clamp this to available margins.
    var maxOffset: Double = 28
    /// Higher values detect smaller oscillations; not a diagnosis.
    var sensitivity: Double = 1
    var updateFrequency: Double = 50
    var freezeDuringTouch = true
    /// Presentation mode makes the lateral acceleration response more visible.
    var presentationMode = true
}

struct MotionOutput {
    var offset: CGSize = .zero
    var classification: MotionClassification = .uncertain
    var confidence: Double = 0
    var isActive = false
    var sample: MotionSample?
    var actualFrequency: Double = 0
}

/// Lightweight classifier over a bounded, timestamped 0.8 second window.
/// Thresholds are conservative engineering defaults, not clinical measurements.
struct MotionClassifier {
    private var samples: [MotionSample] = []
    private(set) var classification: MotionClassification = .uncertain
    private var pending: MotionClassification = .uncertain
    private var pendingCount = 0

    mutating func reset() { self = MotionClassifier() }

    mutating func classify(_ sample: MotionSample, sensitivity: Double) -> (MotionClassification, Double) {
        if let last = samples.last, sample.timestamp <= last.timestamp { return (classification, 0) }
        if let last = samples.last, sample.timestamp - last.timestamp > 0.5 { reset() }
        samples.append(sample)
        samples.removeAll { sample.timestamp - $0.timestamp > 0.8 }
        if samples.count > 100 { samples.removeFirst(samples.count - 100) }
        let rates = samples.map { hypot($0.rotationX, $0.rotationY) }
        let peak = rates.max() ?? 0
        let mean = rates.reduce(0, +) / Double(rates.count)
        let accel = hypot(hypot(sample.accelerationX, sample.accelerationY), sample.accelerationZ)
        let scale = min(max(sensitivity, 0.5), 2)
        let candidate: MotionClassification
        let confidence: Double
        if peak > 2.2 || accel > 0.8 {
            candidate = .sudden; confidence = 0.95
        } else if samples.count < 8 || (samples.last!.timestamp - samples.first!.timestamp) < 0.25 {
            candidate = .uncertain; confidence = 0.2
        } else {
            // Count significant sign reversals on the dominant screen-relevant axis.
            let xEnergy = samples.reduce(0.0) { $0 + abs($1.rotationX) }
            let yEnergy = samples.reduce(0.0) { $0 + abs($1.rotationY) }
            let values = samples.map { xEnergy >= yEnergy ? $0.rotationX : $0.rotationY }
            let threshold = 0.035 / scale
            var previous = 0, reversals = 0
            for value in values {
                let sign = value > threshold ? 1 : (value < -threshold ? -1 : 0)
                if sign != 0 {
                    if previous != 0 && previous != sign { reversals += 1 }
                    previous = sign
                }
            }
            let duration = max(0.001, samples.last!.timestamp - samples.first!.timestamp)
            let reversalFrequency = Double(reversals) / (2 * duration)
            if mean < 0.025 / scale && peak < 0.09 / scale {
                candidate = .still; confidence = 0.9
            } else if mean > 0.65 || (mean > 0.12 && reversals < 2) {
                candidate = .deliberate; confidence = 0.75
            } else if reversals >= 3 && reversalFrequency >= 1.2 && reversalFrequency <= 12 && mean > 0.035 / scale {
                candidate = .tremorLike; confidence = min(0.9, 0.5 + Double(reversals) * 0.05)
            } else {
                candidate = .uncertain; confidence = 0.3
            }
        }
        // Abrupt movement immediately suspends compensation; other states need persistence.
        if candidate == .sudden {
            classification = candidate; pending = candidate; pendingCount = 0
        } else {
            if candidate == pending { pendingCount += 1 } else { pending = candidate; pendingCount = 1 }
            if pendingCount >= 4 { classification = candidate }
        }
        return (classification, candidate == classification ? confidence : 0.25)
    }
}

/// Maps gravity-compensated device-frame acceleration to short-lived screen offsets.
/// No velocity or position is integrated. Axis signs require device testing.
struct StabilizationEngine {
    private var classifier = MotionClassifier()
    private var baselineX: Double?
    private var baselineY: Double?
    private var previousTime: TimeInterval?
    private var output = MotionOutput()
    private var needsRecenter = true

    mutating func recenter() { needsRecenter = true }
    mutating func reset() { self = StabilizationEngine() }

    mutating func process(_ sample: MotionSample, configuration: MotionConfiguration, touchActive: Bool) -> MotionOutput {
        let dt = previousTime.map { sample.timestamp - $0 } ?? 0.02
        guard dt > 0, dt.isFinite else { return output }
        if dt > 0.5 { classifier.reset(); needsRecenter = true; output.offset = .zero }
        previousTime = sample.timestamp
        if needsRecenter || baselineX == nil || baselineY == nil {
            baselineX = sample.accelerationX; baselineY = sample.accelerationY; needsRecenter = false
        }
        let (state, confidence) = classifier.classify(sample, sensitivity: configuration.sensitivity)
        // Remove slow sensor bias; these are short-lived acceleration cues, not
        // displacement estimates. Device X points right and Y points up in portrait.
        let baselineAlpha = 1 - exp(-min(dt, 0.1) * 1.5)
        baselineX! += (sample.accelerationX - baselineX!) * baselineAlpha
        baselineY! += (sample.accelerationY - baselineY!) * baselineAlpha
        let ax = sample.accelerationX - baselineX!
        let ay = sample.accelerationY - baselineY!
        let threshold = 0.012 / min(max(configuration.sensitivity, 0.5), 2)
        func deadzone(_ value: Double) -> Double {
            guard abs(value) > threshold else { return 0 }
            return value > 0 ? value - threshold : value + threshold
        }
        let active = configuration.enabled && state != .sudden
        let limit = max(0, min(configuration.maxOffset, 40))
        // Points per g. Presentation mode is stronger but still clamped.
        let gain = (configuration.presentationMode ? 350.0 : 180.0) * min(max(configuration.strength, 0), 1)
        let x = active ? clamp(-deadzone(ax) * gain, limit) : 0
        let y = active ? clamp(deadzone(ay) * gain, limit) : 0
        if !(touchActive && configuration.freezeDuringTouch && configuration.enabled && state != .sudden) {
            let alpha = 1 - exp(-min(dt, 0.1) * 12)
            output.offset.width += (x - output.offset.width) * alpha
            output.offset.height += (y - output.offset.height) * alpha
        }
        // Clamp even when settings change during an active touch.
        output.offset.width = clamp(output.offset.width, limit)
        output.offset.height = clamp(output.offset.height, limit)
        output.classification = state
        output.confidence = confidence
        output.isActive = active
        output.sample = sample
        output.actualFrequency = dt < 0.5 ? 1 / dt : 0
        return output
    }

    private func clamp(_ value: Double, _ limit: Double) -> Double { min(max(value, -limit), limit) }
}
