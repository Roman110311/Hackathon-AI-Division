import Foundation
import CoreGraphics

/// Coordinates are in UIKit/SwiftUI points, with x right and y down.
enum TouchGeometry {
    static func contentPoint(fromScreen point: CGPoint, offset: CGSize) -> CGPoint {
        CGPoint(x: point.x - offset.width, y: point.y - offset.height)
    }
    static func screenPoint(fromContent point: CGPoint, offset: CGSize) -> CGPoint {
        CGPoint(x: point.x + offset.width, y: point.y + offset.height)
    }
}

enum ActionRisk: Int, Codable { case low, medium, high }

struct TouchTarget {
    let id: String
    let visibleBounds: CGRect
    let expansion: CGFloat
    var enabled = true
    var risk: ActionRisk = .low
    var label = ""
    var effectiveBounds: CGRect { visibleBounds.insetBy(dx: -max(0, expansion), dy: -max(0, expansion)) }
}

struct TargetResolution {
    let targetID: String?
    let candidateCount: Int
    let corrected: Bool
    let ambiguous: Bool
}

/// Resolve in the same coordinate space as registered bounds. A direct hit wins;
/// similarly close expanded hits are rejected rather than selected by array order.
enum TouchTargetResolver {
    static func resolve(_ point: CGPoint, targets: [TouchTarget], ambiguityMargin: CGFloat = 6) -> TargetResolution {
        let candidates = targets.filter { $0.enabled && $0.effectiveBounds.contains(point) }
        let direct = candidates.filter { $0.visibleBounds.contains(point) }
        if direct.count == 1 {
            return TargetResolution(targetID: direct[0].id, candidateCount: candidates.count, corrected: false, ambiguous: false)
        }
        if direct.count > 1 {
            return TargetResolution(targetID: nil, candidateCount: candidates.count, corrected: false, ambiguous: true)
        }
        let ranked = candidates.map { ($0, distance(point, to: $0.visibleBounds)) }.sorted { $0.1 < $1.1 }
        guard let first = ranked.first else {
            return TargetResolution(targetID: nil, candidateCount: 0, corrected: false, ambiguous: false)
        }
        let ambiguous = ranked.count > 1 && ranked[1].1 - first.1 < max(0, ambiguityMargin)
        // High-risk selections require a direct, unambiguous touch.
        guard !ambiguous, first.0.risk != .high else {
            return TargetResolution(targetID: nil, candidateCount: candidates.count, corrected: false, ambiguous: ambiguous)
        }
        return TargetResolution(targetID: first.0.id, candidateCount: candidates.count, corrected: true, ambiguous: false)
    }

    private static func distance(_ p: CGPoint, to r: CGRect) -> CGFloat {
        let dx = max(r.minX - p.x, 0, p.x - r.maxX)
        let dy = max(r.minY - p.y, 0, p.y - r.maxY)
        return hypot(dx, dy)
    }
}

enum TouchIntentState: Equatable { case idle, targetLocked, intentionalGesture, cancelled, confirmed }

/// One instance per finger. No raw samples are retained; path length and net
/// displacement are accumulated in points, time in seconds.
struct TouchIntentProcessor {
    private(set) var state: TouchIntentState = .idle
    private(set) var start = CGPoint.zero
    private(set) var current = CGPoint.zero
    private(set) var pathLength: CGFloat = 0
    private(set) var startTime: TimeInterval = 0
    private(set) var targetID: String?
    var tolerance: CGFloat = 12

    init(tolerance: CGFloat = 12) { self.tolerance = tolerance }

    var displacement: CGFloat { hypot(current.x - start.x, current.y - start.y) }

    mutating func begin(at point: CGPoint, time: TimeInterval, targetID: String) {
        start = point; current = point; pathLength = 0; startTime = time
        self.targetID = targetID; state = .targetLocked
    }
    mutating func move(to point: CGPoint) {
        guard state == .targetLocked else { return }
        pathLength += hypot(point.x - current.x, point.y - current.y)
        current = point
        // A sustained directional movement is likely a scroll. Tremulous paths
        // can be longer than their net displacement, but are still bounded.
        if displacement > tolerance && (displacement > tolerance * 2 || displacement / max(pathLength, 1) > 0.65) {
            state = .intentionalGesture
        }
    }
    mutating func end(at point: CGPoint, time: TimeInterval, withinTarget: Bool, minimumDuration: TimeInterval = 0) -> String? {
        move(to: point)
        guard state == .targetLocked, withinTarget, time - startTime >= minimumDuration else {
            state = .cancelled; return nil
        }
        state = .confirmed
        return targetID
    }
    mutating func cancel() { state = .cancelled; targetID = nil }
}

enum TouchActivationMode: String, Codable, CaseIterable { case normal, protected, hold }

struct TouchConfiguration {
    var expansion: CGFloat = 6
    var movementTolerance: CGFloat = 12
    var mode: TouchActivationMode = .protected
    var holdDuration: TimeInterval = 0.5
    var duplicateInterval: TimeInterval = 0.6
    var haptics = true
    var risk: ActionRisk = .low
    var enabled = true
}

/// Deliberately scoped by action identifier, never a global input lock.
final class AccidentalTouchProtector {
    private var lastActivation: [String: TimeInterval] = [:]
    func allow(action: String, time: TimeInterval, interval: TimeInterval) -> Bool {
        if let last = lastActivation[action], time >= last, time - last < max(0, interval) { return false }
        lastActivation[action] = time
        return true
    }
    static func requiresConfirmation(_ risk: ActionRisk) -> Bool { risk == .high }
}
