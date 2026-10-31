import XCTest
@testable import AdaptiveTouch

final class MotionProcessingTests: XCTestCase {
    private func sample(_ time: Double, rate: Double = 0, roll: Double = 0, pitch: Double = 0) -> MotionSample {
        MotionSample(timestamp: time, rotationX: rate, rotationY: 0, rotationZ: 0, roll: roll, pitch: pitch, yaw: 0, accelerationX: 0, accelerationY: 0, accelerationZ: 0)
    }

    func testStillAndSudden() {
        var classifier = MotionClassifier()
        for index in 0..<40 { _ = classifier.classify(sample(Double(index) / 50), sensitivity: 1) }
        XCTAssertEqual(classifier.classification, .still)
        _ = classifier.classify(sample(0.82, rate: 3), sensitivity: 1)
        XCTAssertEqual(classifier.classification, .sudden)
    }

    func testOscillationAndDeliberateMovement() {
        var classifier = MotionClassifier()
        for index in 0..<100 {
            let t = Double(index) / 50
            _ = classifier.classify(sample(t, rate: 0.3 * sin(t * 2 * .pi * 4)), sensitivity: 1)
        }
        XCTAssertEqual(classifier.classification, .tremorLike)
        for index in 100..<160 {
            _ = classifier.classify(sample(Double(index) / 50, rate: 0.3), sensitivity: 1)
        }
        XCTAssertEqual(classifier.classification, .deliberate)
    }

    func testOffsetsBoundedAndDisabledReturnsToCenter() {
        var engine = StabilizationEngine()
        var config = MotionConfiguration()
        config.maxOffset = 3
        var result = MotionOutput()
        for index in 0..<200 {
            let t = Double(index) / 50
            result = engine.process(sample(t, rate: 0.4 * cos(t * 2 * .pi * 4), roll: 0.1 * sin(t * 2 * .pi * 4)), configuration: config, touchActive: false)
            XCTAssertLessThanOrEqual(abs(result.offset.width), 3)
            XCTAssertLessThanOrEqual(abs(result.offset.height), 3)
        }
        config.enabled = false
        for index in 200..<260 {
            result = engine.process(sample(Double(index) / 50), configuration: config, touchActive: false)
        }
        XCTAssertLessThan(abs(result.offset.width), 0.01)
        XCTAssertFalse(result.isActive)
    }

    func testTouchFreezesAndRecenterIsBounded() {
        var engine = StabilizationEngine()
        let config = MotionConfiguration()
        var before = MotionOutput()
        for index in 0..<100 {
            let t = Double(index) / 50
            before = engine.process(sample(t, rate: 0.4 * cos(t * 2 * .pi * 4), roll: 0.04 * sin(t * 2 * .pi * 4)), configuration: config, touchActive: false)
        }
        let during = engine.process(sample(2, rate: 0.2, roll: 0.01), configuration: config, touchActive: true)
        XCTAssertEqual(before.offset.width, during.offset.width, accuracy: 0.0001)
        engine.recenter()
        let after = engine.process(sample(2.02, rate: 0, roll: 0.01), configuration: config, touchActive: false)
        XCTAssertLessThanOrEqual(abs(after.offset.width), config.maxOffset)
    }
}
