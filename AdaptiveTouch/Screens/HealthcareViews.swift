import SwiftUI

private enum PortalRoute: Hashable {
    case dashboard, appointments, schedule, medications, information, settings, calibration, demo
}

/// Injects the shared accessibility screens so the motion and touch settings have one owner.
struct HealthcareRootView: View {
    @StateObject private var store = HealthcareStore()
    @State private var path: [PortalRoute] = []
    let settings: () -> AnyView
    let calibration: () -> AnyView
    let demonstration: () -> AnyView

    init(settings: @escaping () -> AnyView, calibration: @escaping () -> AnyView,
         demonstration: @escaping () -> AnyView) {
        self.settings = settings
        self.calibration = calibration
        self.demonstration = demonstration
    }

    var body: some View {
        NavigationStack(path: $path) {
            WelcomeScreen { path.append($0) }
                .navigationDestination(for: PortalRoute.self) { route in
                    switch route {
                    case .dashboard: DashboardScreen { path.append($0) }
                    case .appointments: AppointmentsScreen(store: store)
                    case .schedule: ScheduleScreen(store: store)
                    case .medications: MedicationsScreen()
                    case .information: HealthInformationScreen()
                    case .settings: settings()
                    case .calibration: calibration()
                    case .demo: demonstration()
                    }
                }
        }
        .tint(.blue)
    }
}

private struct PortalPage<Content: View>: View {
    let title: String
    let content: Content
    init(_ title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) { content }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(20)
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// Full-width native button; a minimum 56-point target and generous spacing help precision.
struct PortalButton: View {
    let title: String
    var symbol: String? = nil
    var secondary = false
    var risk: ActionRisk = .low
    let action: () -> Void

    @Environment(\.touchConfiguration) private var configuration
    @Environment(\.touchContactChanged) private var contactChanged

    private var effectiveConfiguration: TouchConfiguration {
        var value = configuration
        value.risk = risk
        return value
    }

    var body: some View {
        AccessibleTouchTarget(title: title, systemImage: symbol, settings: effectiveConfiguration,
                              onContactChanged: contactChanged, action: action)
            .frame(maxWidth: .infinity)
    }

}

private struct WelcomeScreen: View {
    let navigate: (PortalRoute) -> Void
    var body: some View {
        PortalPage("Welcome") {
            Image(systemName: "hand.tap.fill")
                .font(.largeTitle).foregroundStyle(.blue).accessibilityHidden(true)
            Text("Welcome to AdaptiveTouch").font(.largeTitle.bold())
            Text("An easier way to navigate, designed for people who have difficulty making precise touchscreen movements.")
                .font(.body)
            Text("This demonstration uses fictional healthcare information.")
                .font(.callout).foregroundStyle(.secondary)
            PortalButton(title: "Get Started", symbol: "arrow.right") { navigate(.dashboard) }
            PortalButton(title: "Calibrate", symbol: "scope", secondary: true) { navigate(.calibration) }
            PortalButton(title: "Accessibility Settings", symbol: "accessibility", secondary: true) { navigate(.settings) }
            PortalButton(title: "Skip Setup", secondary: true) { navigate(.dashboard) }
        }
    }
}

private struct DashboardScreen: View {
    let navigate: (PortalRoute) -> Void
    var body: some View {
        PortalPage("Home") {
            Text("How can we help?").font(.largeTitle.bold())
            Text("Explore your fictional healthcare portal.").foregroundStyle(.secondary)
            PortalButton(title: "My Appointments", symbol: "calendar") { navigate(.appointments) }
            PortalButton(title: "Schedule Appointment", symbol: "calendar.badge.plus") { navigate(.schedule) }
            PortalButton(title: "Medications", symbol: "pills") { navigate(.medications) }
            PortalButton(title: "Health Information", symbol: "heart.text.square") { navigate(.information) }
            PortalButton(title: "Accessibility Settings", symbol: "accessibility", secondary: true) { navigate(.settings) }
            PortalButton(title: "Calibration", symbol: "scope", secondary: true) { navigate(.calibration) }
            PortalButton(title: "Test AdaptiveTouch", symbol: "hand.tap", secondary: true) { navigate(.demo) }
        }
    }
}

private struct AppointmentCard: View {
    let appointment: DemoAppointment
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(appointment.doctor).font(.title3.bold())
            Text(appointment.specialty)
            Text(appointment.date, format: .dateTime.weekday(.wide).month().day().year())
            Text(appointment.date, format: .dateTime.hour().minute())
        }
        .frame(maxWidth: .infinity, alignment: .leading).padding(18)
        .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))
        .accessibilityElement(children: .combine)
    }
}

private struct AppointmentsScreen: View {
    @ObservedObject var store: HealthcareStore
    @State private var removed: DemoAppointment?
    @State private var pendingRemoval: DemoAppointment?
    private var examples: [DemoAppointment] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        return [
            DemoAppointment(doctor: "Dr. Avery Taylor", specialty: "Primary Care", date: calendar.date(byAdding: .day, value: 7, to: today) ?? today),
            DemoAppointment(doctor: "Dr. Morgan Lee", specialty: "Cardiology", date: calendar.date(byAdding: .day, value: 21, to: today) ?? today)
        ]
    }

    var body: some View {
        PortalPage("My Appointments") {
            Text("Demonstration data only").font(.callout).foregroundStyle(.secondary)
            Text("Example upcoming appointments").font(.headline)
            ForEach(examples) { appointment in
                AppointmentCard(appointment: appointment)
                NavigationLink("View Details") {
                    PortalPage("Appointment Details") {
                        Text("Fictional example").foregroundStyle(.secondary)
                        AppointmentCard(appointment: appointment)
                    }
                }
                .font(.headline).frame(maxWidth: .infinity, minHeight: 48, alignment: .leading)
            }
            Text("Your demo bookings").font(.headline)
            if store.bookings.isEmpty { Text("No demo appointments booked yet.") }
            ForEach(store.bookings.sorted { $0.date < $1.date }) { appointment in
                AppointmentCard(appointment: appointment)
                NavigationLink("View Details") {
                    PortalPage("Appointment Details") {
                        AppointmentCard(appointment: appointment)
                        PortalButton(title: "Remove demo appointment", symbol: "trash", secondary: true) {
                            pendingRemoval = appointment
                        }
                        if let removed {
                            PortalButton(title: "Undo removal", secondary: true) {
                                store.restore(removed)
                                self.removed = nil
                            }
                        }
                    }
                    .confirmationDialog("Remove this demonstration appointment?", isPresented: Binding(
                        get: { pendingRemoval != nil }, set: { if !$0 { pendingRemoval = nil } })) {
                        Button("Remove appointment", role: .destructive) {
                            if let item = pendingRemoval { store.remove(item); removed = item }
                            pendingRemoval = nil
                        }
                        Button("Cancel", role: .cancel) { pendingRemoval = nil }
                    } message: { Text("You can undo this removal on this screen.") }
                }
                .font(.headline).frame(maxWidth: .infinity, minHeight: 48, alignment: .leading)
            }
        }
    }
}

private struct ScheduleScreen: View {
    @ObservedObject var store: HealthcareStore
    @State private var specialty = "Primary Care"
    @State private var date = Calendar.current.startOfDay(for: Date())
    @State private var doctorIndex = 0
    @State private var hour = 9
    @State private var review = false
    @State private var saved = false
    @State private var duplicate = false
    private let specialties = ["Primary Care", "Cardiology", "Dermatology"]
    private var doctors: [String] {
        switch specialty {
        case "Cardiology": return ["Dr. Morgan Lee", "Dr. Riley Chen"]
        case "Dermatology": return ["Dr. Jordan Patel", "Dr. Casey Kim"]
        default: return ["Dr. Avery Taylor", "Dr. Robin Diaz"]
        }
    }
    private var doctor: String { doctors[min(doctorIndex, doctors.count - 1)] }
    private var selectedDate: Date { Calendar.current.date(bySettingHour: hour, minute: 0, second: 0, of: date) ?? date }
    var body: some View {
        PortalPage("Schedule Appointment") {
            Text("Fictional booking demonstration").foregroundStyle(.secondary)
            Text("Choose a specialty").font(.headline)
            ForEach(specialties, id: \.self) { item in
                PortalButton(title: (specialty == item ? "✓ " : "") + item, secondary: specialty != item) { specialty = item; doctorIndex = 0 }
                    .accessibilityAddTraits(specialty == item ? .isSelected : [])
            }
            Text("Choose a doctor").font(.headline)
            ForEach(Array(doctors.enumerated()), id: \.offset) { index, name in
                PortalButton(title: (doctorIndex == index ? "✓ " : "") + name, secondary: doctorIndex != index) { doctorIndex = index }
                    .accessibilityAddTraits(doctorIndex == index ? .isSelected : [])
            }
            DatePicker("Choose a date", selection: $date, in: Calendar.current.startOfDay(for: Date())..., displayedComponents: .date)
                .datePickerStyle(.compact).frame(minHeight: 56)
            Text("Choose a time").font(.headline)
            ForEach([9, 11, 14, 16], id: \.self) { value in
                PortalButton(title: (hour == value ? "✓ " : "") + timeLabel(value), secondary: hour != value) { hour = value }
                    .accessibilityAddTraits(hour == value ? .isSelected : [])
            }
            NavigationLink(isActive: $review) {
                PortalPage("Review Appointment") {
                    Text("Please check the details before confirming.").font(.headline)
                    AppointmentCard(appointment: DemoAppointment(doctor: doctor, specialty: specialty, date: selectedDate))
                    if saved {
                        Text("Your demonstration appointment was saved on this device.").font(.headline)
                    } else if duplicate {
                        Text("This demonstration appointment is already booked.").font(.headline)
                    } else {
                        PortalButton(title: "Confirm Booking", symbol: "checkmark.circle", risk: .high) {
                            let appointment = DemoAppointment(doctor: doctor, specialty: specialty, date: selectedDate)
                            if store.book(appointment) { saved = true } else { duplicate = true }
                        }
                    }
                    PortalButton(title: "Back to scheduling", secondary: true) { review = false }
                }
            } label: { EmptyView() }.hidden()
            PortalButton(title: "Review Appointment", symbol: "arrow.right") { saved = false; duplicate = false; review = true }
        }
    }
    private func timeLabel(_ hour: Int) -> String {
        let date = Calendar.current.date(bySettingHour: hour, minute: 0, second: 0, of: Date()) ?? Date()
        return date.formatted(date: .omitted, time: .shortened)
    }
}

private struct MedicationsScreen: View {
    var body: some View {
        PortalPage("Medications") {
            Text("Fictional demonstration data; not prescription management or medical advice.")
                .foregroundStyle(.secondary)
            ForEach(["Example medication A", "Example medication B"], id: \.self) { name in
                VStack(alignment: .leading, spacing: 8) {
                    Text(name).font(.title3.bold())
                    Text("Example information only")
                }
                .frame(maxWidth: .infinity, alignment: .leading).padding(18)
                .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))
            }
        }
    }
}

private struct HealthInformationScreen: View {
    var body: some View {
        PortalPage("Health Information") {
            Text("Demonstration information").font(.title2.bold())
            Text("This application does not connect to medical providers or store real patient records.")
        }
    }
}
