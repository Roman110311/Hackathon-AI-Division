import SwiftUI

/// The same sequence and grid are used in both runs; these are not clinical measurements.
struct DemoScreen: View {
    private struct Result {
        var successes: Int
        var wrong: Int
        var misses: Int
        var durations: [TimeInterval]
        var elapsed: TimeInterval
        var mean: TimeInterval { durations.isEmpty ? 0 : durations.reduce(0, +) / Double(durations.count) }
        var median: TimeInterval {
            let values = durations.sorted()
            guard !values.isEmpty else { return 0 }
            let middle = values.count / 2
            return values.count.isMultiple(of: 2) ? (values[middle - 1] + values[middle]) / 2 : values[middle]
        }
    }
    private let sequence = [0, 8, 2, 6, 4, 1]
    /// Pass false for standard, true for assisted, nil when leaving the exercise.
    var onModeChange: (Bool?) -> Void = { _ in }
    @Environment(\.touchConfiguration) private var touchConfiguration
    @Environment(\.touchContactChanged) private var contactChanged
    @State private var adaptive = false
    @State private var running = false
    @State private var trial = 0
    @State private var wrong = 0
    @State private var misses = 0
    @State private var durations: [TimeInterval] = []
    @State private var runStart = Date()
    @State private var trialStart = Date()
    @State private var standardResult: Result?
    @State private var adaptiveResult: Result?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Touch comparison").font(.largeTitle.bold())
                Text("Tap the highlighted target. Each run uses the same six target positions. This is a demonstration, not a clinical assessment.")
                if !running {
                    PortalButton(title: "Start Standard Mode", symbol: "hand.tap") { start(adaptive: false) }
                    PortalButton(title: "Start AdaptiveTouch Mode", symbol: "hand.tap.fill") { start(adaptive: true) }
                    if let standardResult { resultView("Standard Mode", result: standardResult) }
                    if let adaptiveResult { resultView("AdaptiveTouch Mode", result: adaptiveResult) }
                    Text("An incorrect selection is a tap on another labeled target. A miss is a tap on an empty grid cell. Selection time includes retries. Touches outside the grid and canceled gestures are not measured.")
                        .font(.footnote).foregroundStyle(.secondary)
                } else {
                    Text(adaptive ? "AdaptiveTouch Mode" : "Standard Mode").font(.headline)
                    Text("Target \(trial + 1) of \(sequence.count)")
                    Text("Tap the highlighted target").font(.headline)
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 8) {
                        ForEach(0..<9, id: \.self) { index in
                            if index.isMultiple(of: 2) || index == sequence[min(trial, sequence.count - 1)] {
                                target(index)
                            } else {
                                Button { misses += 1 } label: {
                                    Text("Empty").font(.caption).foregroundStyle(.secondary)
                                        .frame(maxWidth: .infinity, minHeight: 64)
                                        .background(Color(uiColor: .tertiarySystemFill), in: RoundedRectangle(cornerRadius: 12))
                                }.buttonStyle(.plain).accessibilityLabel("Empty area")
                            }
                        }
                    }
                    PortalButton(title: "End Exercise", secondary: true) { running = false; onModeChange(nil) }
                }
            }
            .padding(20).frame(maxWidth: .infinity, alignment: .leading)
        }
        .navigationTitle("Test AdaptiveTouch")
        .navigationBarTitleDisplayMode(.inline)
        .onDisappear { onModeChange(nil) }
    }

    @ViewBuilder private func target(_ index: Int) -> some View {
        let selected = index == sequence[min(trial, sequence.count - 1)]
        if adaptive {
            AccessibleTouchTarget(title: selected ? "Target" : "Other", settings: touchConfiguration, highlighted: selected,
                                  onContactChanged: contactChanged) { choose(index) }
                .overlay {
                    RoundedRectangle(cornerRadius: 14)
                        .strokeBorder(selected ? Color.orange : Color.clear, lineWidth: 5)
                        .allowsHitTesting(false)
                }
                .accessibilityHint(selected ? "Highlighted target" : "Not the highlighted target")
        } else {
            Button { choose(index) } label: {
                Text(selected ? "Target" : "Other").font(.headline)
                    .frame(maxWidth: .infinity, minHeight: 64)
                    .foregroundStyle(selected ? Color.white : Color.primary)
                    .background(selected ? Color.blue : Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
            }.buttonStyle(.plain).accessibilityHint(selected ? "Highlighted target" : "Not the highlighted target")
        }
    }
    private func start(adaptive: Bool) {
        self.adaptive = adaptive; trial = 0; wrong = 0; misses = 0; durations = []
        runStart = Date(); trialStart = runStart; running = true; onModeChange(adaptive)
    }
    private func choose(_ index: Int) {
        guard running else { return }
        guard index == sequence[min(trial, sequence.count - 1)] else { wrong += 1; return }
        let now = Date()
        durations.append(now.timeIntervalSince(trialStart))
        trial += 1; trialStart = now
        if trial == sequence.count {
            let result = Result(successes: trial, wrong: wrong, misses: misses, durations: durations, elapsed: now.timeIntervalSince(runStart))
            if adaptive { adaptiveResult = result } else { standardResult = result }
            running = false; onModeChange(nil)
        }
    }
    private func resultView(_ title: String, result: Result) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.title3.bold())
            Text("Successful selections: \(result.successes)")
            Text("Incorrect selections: \(result.wrong)")
            Text("Missed selections: \(result.misses)")
            Text("Average selection time: \(result.mean, specifier: "%.2f") seconds")
            Text("Median selection time: \(result.median, specifier: "%.2f") seconds")
            Text("Total time: \(result.elapsed, specifier: "%.2f") seconds")
        }
        .frame(maxWidth: .infinity, alignment: .leading).padding(16)
        .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))
    }
}
