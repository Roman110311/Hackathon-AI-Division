import Foundation
import Combine
import CoreMotion

/// Owns Core Motion for the foreground. Sensor processing runs on a serial queue;
/// published values are delivered on the main queue. No samples are saved to disk.
@MainActor
final class MotionSensorManager: ObservableObject {
    @Published private(set) var state = MotionOutput()
    @Published private(set) var isAvailable = false
    @Published private(set) var isRunning = false
    @Published var simulationEnabled = false {
        didSet {
            if oldValue != simulationEnabled && isRunning { stop(); start() }
        }
    }

    private let motionManager = CMMotionManager()
    private let queue = DispatchQueue(label: "AdaptiveTouch.motion.processing", qos: .userInitiated)
    private let operationQueue: OperationQueue
    private let processor = MotionWorker()
    private var timer: DispatchSourceTimer?
    private var generation = 0
    private var configuration = MotionConfiguration()

    init() {
        operationQueue = OperationQueue()
        operationQueue.name = "AdaptiveTouch.motion.samples"
        operationQueue.maxConcurrentOperationCount = 1
        operationQueue.underlyingQueue = queue
        isAvailable = motionManager.isDeviceMotionAvailable
    }

    func updateConfiguration(_ configuration: MotionConfiguration) {
        let frequencyChanged = self.configuration.updateFrequency != configuration.updateFrequency
        self.configuration = configuration
        queue.async { [processor] in processor.configuration = configuration }
        if frequencyChanged && isRunning { stop(); start() }
    }

    func setTouchActive(_ active: Bool) {
        queue.async { [processor] in processor.touchActive = active }
    }

    func recenter() {
        queue.async { [processor] in processor.engine.recenter() }
    }

    func start() {
        guard !isRunning else { return }
        isAvailable = simulationEnabled || motionManager.isDeviceMotionAvailable
        guard isAvailable else { state = MotionOutput(); return }
        isRunning = true
        generation += 1
        let token = generation
        let interval = 1 / min(max(configuration.updateFrequency, 10), 60)
        queue.async { [processor, configuration] in
            processor.configuration = configuration
            processor.engine.reset()
            processor.touchActive = false
        }
        if simulationEnabled {
            let source = DispatchSource.makeTimerSource(queue: queue)
            let start = ProcessInfo.processInfo.systemUptime
            source.schedule(deadline: .now(), repeating: interval)
            source.setEventHandler { [weak self, processor] in
                let now = ProcessInfo.processInfo.systemUptime
                let t = now - start
                let omega = 2 * Double.pi * 4
                let sample = MotionSample(timestamp: now, rotationX: 0.02 * omega * cos(omega * t), rotationY: 0.01 * omega * cos(omega * t), rotationZ: 0, roll: 0.01 * sin(omega * t), pitch: 0.02 * sin(omega * t), yaw: 0, accelerationX: 0, accelerationY: 0, accelerationZ: 0)
                let output = processor.process(sample)
                Task { @MainActor [weak self] in self?.publish(output, generation: token) }
            }
            timer = source
            source.resume()
        } else {
            motionManager.deviceMotionUpdateInterval = interval
            motionManager.startDeviceMotionUpdates(to: operationQueue) { [weak self, processor] motion, error in
                guard let motion = motion else {
                    if error != nil {
                        Task { @MainActor [weak self] in self?.handleFailure(generation: token) }
                    }
                    return
                }
                let r = motion.rotationRate, a = motion.userAcceleration, g = motion.gravity, attitude = motion.attitude
                let sample = MotionSample(timestamp: motion.timestamp, rotationX: r.x, rotationY: r.y, rotationZ: r.z, roll: attitude.roll, pitch: attitude.pitch, yaw: attitude.yaw, accelerationX: a.x, accelerationY: a.y, accelerationZ: a.z, gravityX: g.x, gravityY: g.y, gravityZ: g.z)
                let output = processor.process(sample)
                Task { @MainActor [weak self] in self?.publish(output, generation: token) }
            }
        }
    }

    func stop() {
        generation += 1
        isRunning = false
        motionManager.stopDeviceMotionUpdates()
        timer?.cancel()
        timer = nil
        state = MotionOutput()
        queue.async { [processor] in processor.engine.reset(); processor.touchActive = false }
    }

    private func publish(_ output: MotionOutput, generation: Int) {
        guard isRunning && generation == self.generation else { return }
        state = output
    }

    private func handleFailure(generation: Int) {
        guard generation == self.generation else { return }
        stop()
        isAvailable = false
    }
}

/// Accessed only from the serial processing queue.
private final class MotionWorker: @unchecked Sendable {
    var engine = StabilizationEngine()
    var configuration = MotionConfiguration()
    var touchActive = false
    func process(_ sample: MotionSample) -> MotionOutput {
        engine.process(sample, configuration: configuration, touchActive: touchActive)
    }
}
