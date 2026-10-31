import XCTest
@testable import AdaptiveTouch

final class TouchAlgorithmsTests: XCTestCase {
    func testTranslationsRoundTrip() {
        for offset in [CGSize.zero, CGSize(width: 15, height: -8), CGSize(width: -23, height: 30)] {
            let point = CGPoint(x: 200, y: 500)
            XCTAssertEqual(TouchGeometry.contentPoint(fromScreen: TouchGeometry.screenPoint(fromContent: point, offset: offset), offset: offset), point)
        }
    }

    func testTargetPriorityAmbiguityAndRisk() {
        let left = TouchTarget(id: "left", visibleBounds: CGRect(x: 0, y: 0, width: 40, height: 40), expansion: 20)
        let right = TouchTarget(id: "right", visibleBounds: CGRect(x: 60, y: 0, width: 40, height: 40), expansion: 20)
        XCTAssertEqual(TouchTargetResolver.resolve(CGPoint(x: 39, y: 20), targets: [left, right]).targetID, "left")
        XCTAssertEqual(TouchTargetResolver.resolve(CGPoint(x: 44, y: 20), targets: [left, right]).targetID, "left")
        XCTAssertTrue(TouchTargetResolver.resolve(CGPoint(x: 50, y: 20), targets: [left, right]).ambiguous)
        var disabled = left; disabled.enabled = false
        XCTAssertNil(TouchTargetResolver.resolve(CGPoint(x: 20, y: 20), targets: [disabled]).targetID)
        var risky = left; risky.risk = .high
        XCTAssertNil(TouchTargetResolver.resolve(CGPoint(x: 45, y: 20), targets: [risky]).targetID)
    }

    func testTouchAnchoringAndScrollCancellation() {
        var processor = TouchIntentProcessor(tolerance: 12)
        processor.begin(at: .zero, time: 0, targetID: "first")
        processor.move(to: CGPoint(x: 6, y: 2))
        processor.move(to: CGPoint(x: 2, y: 3))
        XCTAssertEqual(processor.end(at: CGPoint(x: 4, y: 2), time: 0.2, withinTarget: true), "first")
        XCTAssertNil(processor.end(at: .zero, time: 0.3, withinTarget: true))
        processor.begin(at: .zero, time: 1, targetID: "first")
        processor.move(to: CGPoint(x: 0, y: 40))
        XCTAssertNil(processor.end(at: CGPoint(x: 0, y: 40), time: 1.2, withinTarget: true))
        processor.begin(at: .zero, time: 2, targetID: "first")
        processor.cancel()
        XCTAssertNil(processor.end(at: .zero, time: 2.2, withinTarget: true))
    }

    func testHoldAndDuplicateProtection() {
        var processor = TouchIntentProcessor()
        processor.begin(at: .zero, time: 1, targetID: "one")
        XCTAssertNil(processor.end(at: .zero, time: 1.2, withinTarget: true, minimumDuration: 0.5))
        processor.begin(at: .zero, time: 2, targetID: "one")
        XCTAssertEqual(processor.end(at: .zero, time: 2.6, withinTarget: true, minimumDuration: 0.5), "one")
        let protector = AccidentalTouchProtector()
        XCTAssertTrue(protector.allow(action: "book", time: 1, interval: 0.6))
        XCTAssertFalse(protector.allow(action: "book", time: 1.2, interval: 0.6))
        XCTAssertTrue(protector.allow(action: "back", time: 1.2, interval: 0.6))
        XCTAssertTrue(AccidentalTouchProtector.requiresConfirmation(.high))
    }
}
