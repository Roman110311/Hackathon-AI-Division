import SwiftUI
import UIKit

/// A touch target owns its padded space, so its invisible area cannot overlap an
/// adjacent control's layout area. Native scroll views may cancel its tracking.
struct AccessibleTouchTarget: UIViewRepresentable {
    let title: String
    var systemImage: String? = nil
    var settings = TouchConfiguration()
    var highlighted = false
    var onContactChanged: ((Bool) -> Void)? = nil
    let action: () -> Void

    func makeUIView(context: Context) -> TouchControl { TouchControl() }

    func updateUIView(_ view: TouchControl, context: Context) {
        view.configure(title: title, image: systemImage, settings: settings, highlighted: highlighted,
                       contact: onContactChanged, action: action)
    }

    func sizeThatFits(_ proposal: ProposedViewSize, uiView: TouchControl, context: Context) -> CGSize? {
        let width = proposal.width ?? 280
        return CGSize(width: width, height: uiView.preferredHeight(width: width))
    }
}

final class TouchControl: UIControl {
    private static weak var activeControl: TouchControl?
    private let background = UIView()
    private let label = UILabel()
    private let symbol = UIImageView()
    private let stack = UIStackView()
    private var config = TouchConfiguration()
    private var processor = TouchIntentProcessor()
    private var currentTouch: UITouch?
    private var invalidMultipleTouches = false
    private var isContact = false
    private var action: (() -> Void)?
    private var contact: ((Bool) -> Void)?
    private let protector = AccidentalTouchProtector()
    private var targetTitle = ""

    override init(frame: CGRect) {
        super.init(frame: frame)
        isMultipleTouchEnabled = true
        isAccessibilityElement = true
        accessibilityTraits = .button
        background.isUserInteractionEnabled = false
        background.backgroundColor = UIColor(red: 0.05, green: 0.31, blue: 0.36, alpha: 1)
        background.layer.cornerRadius = 16
        addSubview(background)
        label.font = .preferredFont(forTextStyle: .headline)
        label.adjustsFontForContentSizeCategory = true
        label.numberOfLines = 0
        label.textColor = .white
        label.textAlignment = .center
        symbol.tintColor = .white
        symbol.contentMode = .scaleAspectFit
        stack.axis = .horizontal
        stack.spacing = 10
        stack.alignment = .center
        stack.addArrangedSubview(symbol)
        stack.addArrangedSubview(label)
        background.addSubview(stack)
        stack.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(greaterThanOrEqualTo: background.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(lessThanOrEqualTo: background.trailingAnchor, constant: -16),
            stack.topAnchor.constraint(greaterThanOrEqualTo: background.topAnchor, constant: 12),
            stack.bottomAnchor.constraint(lessThanOrEqualTo: background.bottomAnchor, constant: -12),
            stack.centerXAnchor.constraint(equalTo: background.centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: background.centerYAnchor),
            symbol.widthAnchor.constraint(lessThanOrEqualToConstant: 28),
            symbol.heightAnchor.constraint(lessThanOrEqualToConstant: 28)
        ])
    }
    required init?(coder: NSCoder) { nil }

    func configure(title: String, image: String?, settings: TouchConfiguration, highlighted: Bool,
                   contact: ((Bool) -> Void)?, action: @escaping () -> Void) {
        targetTitle = title; label.text = title; accessibilityLabel = title
        background.backgroundColor = highlighted ? UIColor(red: 0.54, green: 0.22, blue: 0.02, alpha: 1) : UIColor(red: 0.05, green: 0.31, blue: 0.36, alpha: 1)
        symbol.image = image.flatMap { UIImage(systemName: $0) }
        symbol.isHidden = image == nil
        config = settings; self.contact = contact; self.action = action
        isEnabled = settings.enabled
        accessibilityTraits = settings.enabled ? .button : [.button, .notEnabled]
        alpha = settings.enabled ? 1 : 0.55
        setNeedsLayout()
    }

    func preferredHeight(width: CGFloat) -> CGFloat {
        let padding = min(max(config.expansion, 0), 20)
        let textWidth = max(40, width - padding * 2 - 68)
        let measured = label.sizeThatFits(CGSize(width: textWidth, height: .greatestFiniteMagnitude)).height
        return max(60, measured + 24) + padding * 2
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let inset = min(max(config.expansion, 0), min(bounds.width, bounds.height) / 4, 20)
        background.frame = bounds.insetBy(dx: inset, dy: inset)
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard isEnabled else { return }
        if currentTouch != nil || touches.count != 1 {
            invalidMultipleTouches = true; processor.cancel(); setContact(false); return
        }
        guard let touch = touches.first else { return }
        currentTouch = touch; invalidMultipleTouches = false
        if config.risk == .high && !background.frame.contains(touch.location(in: self)) {
            invalidMultipleTouches = true
            return
        }
        if let active = Self.activeControl, active !== self {
            active.invalidateContact()
            invalidMultipleTouches = true
            return
        }
        Self.activeControl = self
        processor = TouchIntentProcessor(tolerance: max(2, config.movementTolerance))
        processor.begin(at: touch.location(in: self), time: touch.timestamp, targetID: targetTitle)
        setContact(true); background.alpha = 0.7
    }
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = currentTouch, touches.contains(touch), !invalidMultipleTouches else { return }
        processor.move(to: touch.location(in: self))
        if processor.state == .intentionalGesture { background.alpha = 1 }
    }
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = currentTouch, touches.contains(touch) else { return }
        defer {
            if Self.activeControl === self { Self.activeControl = nil }
            currentTouch = nil; background.alpha = 1; setContact(false)
        }
        guard !invalidMultipleTouches else { processor.cancel(); return }
        let point = touch.location(in: self)
        // Protected mode filters extremely brief brushes. Hold is opt-in.
        let duration: TimeInterval = config.mode == .hold ? max(0.1, config.holdDuration) : (config.mode == .protected ? 0.04 : 0)
        let within = bounds.insetBy(dx: -config.movementTolerance, dy: -config.movementTolerance).contains(point)
        if processor.end(at: point, time: touch.timestamp, withinTarget: within, minimumDuration: duration) != nil { activate() }
    }
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        if Self.activeControl === self { Self.activeControl = nil }
        processor.cancel(); currentTouch = nil; invalidMultipleTouches = false
        background.alpha = 1; setContact(false)
    }
    override func accessibilityActivate() -> Bool {
        guard isEnabled else { return false }
        activate(); return true
    }
    private func setContact(_ active: Bool) {
        guard active != isContact else { return }
        isContact = active; contact?(active)
    }
    private func invalidateContact() {
        invalidMultipleTouches = true
        processor.cancel()
        background.alpha = 1
        setContact(false)
    }
    private func activate() {
        guard protector.allow(action: targetTitle, time: ProcessInfo.processInfo.systemUptime, interval: config.duplicateInterval) else { return }
        if config.haptics { UIImpactFeedbackGenerator(style: .light).impactOccurred() }
        action?()
    }
}
