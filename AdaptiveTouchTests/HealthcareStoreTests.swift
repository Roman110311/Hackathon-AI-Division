import XCTest
@testable import AdaptiveTouch

final class HealthcareStoreTests: XCTestCase {
    func testBookingPersistsAndRejectsDuplicates() {
        let suite = "AdaptiveTouchTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let appointment = DemoAppointment(doctor: "Dr. Taylor", specialty: "Primary Care", date: Date(timeIntervalSince1970: 2_000_000_000))
        let first = HealthcareStore(defaults: defaults)
        XCTAssertTrue(first.book(appointment))
        XCTAssertFalse(first.book(appointment))
        let reloaded = HealthcareStore(defaults: defaults)
        XCTAssertEqual(reloaded.bookings.count, 1)
        reloaded.remove(appointment)
        XCTAssertTrue(reloaded.bookings.isEmpty)
        reloaded.restore(appointment)
        XCTAssertEqual(reloaded.bookings, [appointment])
    }
}
