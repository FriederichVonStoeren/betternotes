import BetterNotesCore
import PencilKit
import UIKit

/// Milestone (b): compare three ways of drawing and show what the Pencil reports.
///
///  - PencilKit: Apple's canvas, the reference for latency and feel.
///  - Custom: our own engine (InkCanvasView).
///  - Hybrid: PencilKit draws the stroke while the pencil is down; on lift-off the stroke
///    is converted and redrawn by our engine. Watch whether the stroke visibly changes.
final class SpikeViewController: UIViewController, PKCanvasViewDelegate, UIPencilInteractionDelegate {
    private let ink = InkCanvasView()
    private let pencilKit = PKCanvasView()
    private let modes = UISegmentedControl(items: [
        "PencilKit", String(localized: "mode.custom"), String(localized: "mode.hybrid"),
    ])
    private let fingerSwitch = UISwitch()
    private let hud = UILabel()

    // Measurements since the label was last refreshed
    private var ageSum: TimeInterval = 0
    private var workSum: TimeInterval = 0
    private var batches = 0
    private var samples = 0
    private var windowStart = CACurrentMediaTime()
    private var metricsText = "–"
    private var pencilText = "–"
    private var hoverText = "–"
    private var gestureText = "–"

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground

        pencilKit.backgroundColor = .clear
        pencilKit.isOpaque = false
        pencilKit.delegate = self
        pencilKit.tool = PKInkingTool(.pen, color: .label, width: 3)
        for canvas in [ink, pencilKit] as [UIView] {
            canvas.frame = view.bounds
            canvas.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            view.addSubview(canvas)
        }

        ink.onMetrics = { [weak self] age, work, count in self?.record(age: age, work: work, count: count) }
        ink.onTouch = { [weak self] touch in self?.record(touch) }

        modes.selectedSegmentIndex = 1
        modes.addTarget(self, action: #selector(applySettings), for: .valueChanged)
        #if targetEnvironment(simulator)
        fingerSwitch.isOn = true // no Pencil in the simulator
        #endif
        fingerSwitch.accessibilityIdentifier = "finger"
        fingerSwitch.addTarget(self, action: #selector(applySettings), for: .valueChanged)
        let fingerLabel = UILabel()
        fingerLabel.text = String(localized: "finger.draws")
        fingerLabel.font = .preferredFont(forTextStyle: .footnote)
        var clearConfiguration = UIButton.Configuration.gray()
        clearConfiguration.title = String(localized: "clear")
        let clear = UIButton(configuration: clearConfiguration, primaryAction: UIAction { [weak self] _ in self?.clearAll() })
        clear.accessibilityIdentifier = "clear"

        let bar = UIStackView(arrangedSubviews: [modes, fingerLabel, fingerSwitch, clear])
        bar.spacing = 12
        bar.alignment = .center
        bar.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(bar)

        hud.numberOfLines = 0
        hud.font = .monospacedDigitSystemFont(ofSize: 12, weight: .regular)
        hud.textColor = .secondaryLabel
        hud.accessibilityIdentifier = "hud"
        hud.isUserInteractionEnabled = false
        hud.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(hud)

        NSLayoutConstraint.activate([
            bar.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 8),
            bar.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            hud.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 12),
            hud.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -12),
        ])

        view.addGestureRecognizer(UIHoverGestureRecognizer(target: self, action: #selector(hover(_:))))
        let pencil = UIPencilInteraction()
        pencil.delegate = self
        view.addInteraction(pencil)

        applySettings()
        refreshHUD()
    }

    @objc private func applySettings() {
        let mode = modes.selectedSegmentIndex
        pencilKit.isHidden = mode == 1
        ink.isHidden = mode == 0
        pencilKit.drawingPolicy = fingerSwitch.isOn ? .anyInput : .pencilOnly
        ink.allowsFingerDrawing = fingerSwitch.isOn
        refreshHUD()
    }

    private func clearAll() {
        ink.clear()
        pencilKit.drawing = PKDrawing()
        refreshHUD()
    }

    // MARK: Hybrid mode

    func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
        guard modes.selectedSegmentIndex == 2, let stroke = canvasView.drawing.strokes.last else { return }
        let converted = stroke.path.interpolatedPoints(by: .distance(2)).map { point in
            InkSample(location: point.location.applying(stroke.transform), width: point.size.width)
        }
        ink.add(stroke: converted)
        canvasView.drawing = PKDrawing() // calls this method again; the guard above ends it
        refreshHUD()
    }

    // MARK: What the Pencil reports

    private func record(age: TimeInterval, work: TimeInterval, count: Int) {
        ageSum += age
        workSum += work
        batches += 1
        samples += count
        let now = CACurrentMediaTime()
        // Refreshing a label costs time; four times a second does not disturb the measurement.
        guard now - windowStart >= 0.25 else { return }
        metricsText = String(format: String(localized: "hud.metrics"),
                             ageSum / Double(batches) * 1000, workSum / Double(batches) * 1000,
                             Double(samples) / (now - windowStart))
        ageSum = 0
        workSum = 0
        batches = 0
        samples = 0
        windowStart = now
        refreshHUD()
    }

    private func record(_ touch: UITouch) {
        guard touch.type == .pencil else { return }
        pencilText = String(format: String(localized: "hud.pencil"),
                            Double(touch.force), degrees(touch.altitudeAngle),
                            degrees(touch.azimuthAngle(in: view)), degrees(touch.rollAngle))
    }

    @objc private func hover(_ recognizer: UIHoverGestureRecognizer) {
        switch recognizer.state {
        case .began, .changed:
            hoverText = String(format: String(localized: "hud.hover"),
                               Double(recognizer.zOffset), degrees(recognizer.altitudeAngle), degrees(recognizer.rollAngle))
        default:
            hoverText = "–"
        }
        refreshHUD()
    }

    func pencilInteraction(_ interaction: UIPencilInteraction, didReceiveTap tap: UIPencilInteraction.Tap) {
        gestureText = String(localized: "gesture.doubleTap")
        refreshHUD()
    }

    func pencilInteraction(_ interaction: UIPencilInteraction, didReceiveSqueeze squeeze: UIPencilInteraction.Squeeze) {
        let phase: String
        switch squeeze.phase {
        case .began: phase = "began"
        case .changed: phase = "changed"
        case .ended: phase = "ended"
        case .cancelled: phase = "cancelled"
        @unknown default: phase = "?"
        }
        gestureText = String(format: String(localized: "gesture.squeeze"), phase)
        refreshHUD()
    }

    private func degrees(_ radians: CGFloat) -> Double {
        Double(radians) * 180 / .pi
    }

    private func refreshHUD() {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
        hud.text = [
            String(localized: "hud.engine") + " " + metricsText,
            String(localized: "hud.pencil.title") + " " + pencilText,
            String(localized: "hud.hover.title") + " " + hoverText,
            String(localized: "hud.gesture.title") + " " + gestureText,
            String(format: String(localized: "hud.footer"), ink.strokeCount, version, Format.version),
        ].joined(separator: "\n")
    }
}
