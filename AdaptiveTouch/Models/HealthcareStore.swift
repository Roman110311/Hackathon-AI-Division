import Foundation
import Combine

struct DemoAppointment: Codable, Identifiable, Equatable {
    var id: UUID = UUID()
    var doctor: String
    var specialty: String
    var date: Date
}

/// Stores only fictional bookings on this device.
final class HealthcareStore: ObservableObject {
    @Published private(set) var bookings: [DemoAppointment] = []
    private let key = "adaptiveTouch.demoBookings.v1"
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: key),
           let saved = try? JSONDecoder().decode([DemoAppointment].self, from: data) {
            bookings = saved
        }
    }

    @discardableResult
    func book(_ appointment: DemoAppointment) -> Bool {
        // The same doctor and time cannot be booked twice, even after relaunch.
        guard !bookings.contains(where: { $0.doctor == appointment.doctor && $0.date == appointment.date }) else { return false }
        bookings.append(appointment)
        persist()
        return true
    }

    func remove(_ appointment: DemoAppointment) {
        bookings.removeAll { $0.id == appointment.id }
        persist()
    }

    func restore(_ appointment: DemoAppointment) {
        guard !bookings.contains(where: { $0.id == appointment.id }) else { return }
        bookings.append(appointment)
        persist()
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(bookings) { defaults.set(data, forKey: key) }
    }
}
