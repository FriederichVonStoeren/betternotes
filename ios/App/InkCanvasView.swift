import UIKit

/// One point of a stroke on screen.
struct InkSample {
    var location: CGPoint
    var width: CGFloat
}

/// The custom ink engine of the latency spike (docs/DECISIONS.md, D2).
///
/// Finished strokes live in one bitmap. The stroke being drawn is a vector shape that
/// Core Animation draws on the GPU; every `chunkSize` points the finished part of it is
/// frozen into its own layer, so the part that changes with each touch stays short.
final class InkCanvasView: UIView {
    var allowsFingerDrawing = false
    var inkColor: UIColor = .label
    var baseWidth: CGFloat = 3

    /// After every batch of touches: age of the newest sample when we got it, time we spent
    /// drawing it, number of samples in the batch.
    var onMetrics: ((_ age: TimeInterval, _ work: TimeInterval, _ samples: Int) -> Void)?
    /// The touch that is drawing, for showing pressure, tilt and roll.
    var onTouch: ((UITouch) -> Void)?
    /// A stroke was added or everything was cleared.
    var onChange: (() -> Void)?

    private static let chunkSize = 48

    private let committedLayer = CALayer()
    private let liveLayer = CAShapeLayer()
    private let predictedLayer = CAShapeLayer()
    private var frozen: [CAShapeLayer] = []

    private var committed: [[InkSample]] = []
    private var committedImage: UIImage?
    private var bakedSize = CGSize.zero
    private var current: [InkSample] = []
    private var chunkStart = 0
    private weak var activeTouch: UITouch?

    override init(frame: CGRect) {
        super.init(frame: frame)
        // Palm and pencil touch at the same time; with single touch a resting palm would block the pencil.
        isMultipleTouchEnabled = true
        backgroundColor = .clear
        layer.addSublayer(committedLayer)
        layer.addSublayer(liveLayer)
        layer.addSublayer(predictedLayer)
    }

    required init?(coder: NSCoder) {
        fatalError("not used")
    }

    var strokeCount: Int { committed.count }

    func add(stroke: [InkSample]) {
        guard !stroke.isEmpty else { return }
        committed.append(stroke)
        bake([stroke], onto: committedImage)
        onChange?()
    }

    func clear() {
        committed = []
        committedImage = nil
        committedLayer.contents = nil
        resetLive()
        onChange?()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        committedLayer.frame = bounds
        committedLayer.contentsScale = window?.screen.scale ?? traitCollection.displayScale
        liveLayer.frame = bounds
        predictedLayer.frame = bounds
        CATransaction.commit()
        if bakedSize != bounds.size {
            bakedSize = bounds.size
            bake(committed, onto: nil)
        }
    }

    // MARK: Touches

    private func accepts(_ touch: UITouch) -> Bool {
        touch.type == .pencil || allowsFingerDrawing
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard activeTouch == nil, let touch = touches.first(where: accepts) else { return }
        resetLive() // also forgets the active touch, so it comes first
        activeTouch = touch
        let color = inkColor.resolvedColor(with: traitCollection).cgColor
        liveLayer.fillColor = color
        predictedLayer.fillColor = color
        append(touch, event)
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = activeTouch, touches.contains(touch) else { return }
        append(touch, event)
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = activeTouch, touches.contains(touch) else { return }
        append(touch, event)
        let stroke = current
        resetLive()
        add(stroke: stroke)
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        // The system cancels a touch it decides was a palm: drop what it drew.
        guard let touch = activeTouch, touches.contains(touch) else { return }
        resetLive()
    }

    private func sample(_ touch: UITouch) -> InkSample {
        let pressure: CGFloat = touch.type == .pencil && touch.maximumPossibleForce > 0
            ? touch.force / touch.maximumPossibleForce : 0.35
        return InkSample(location: touch.preciseLocation(in: self), width: baseWidth * (0.4 + 1.6 * pressure))
    }

    private func append(_ touch: UITouch, _ event: UIEvent?) {
        let started = CACurrentMediaTime()
        // The screen refreshes at 120 Hz but the pencil reports at 240 Hz: take every report.
        let reported = event?.coalescedTouches(for: touch) ?? [touch]
        current.append(contentsOf: reported.map(sample))

        CATransaction.begin()
        CATransaction.setDisableActions(true)
        if current.count - chunkStart > InkCanvasView.chunkSize {
            let chunk = CAShapeLayer()
            chunk.frame = bounds
            chunk.fillColor = liveLayer.fillColor
            chunk.path = InkCanvasView.outline(of: current[chunkStart...])
            layer.insertSublayer(chunk, below: liveLayer)
            frozen.append(chunk)
            chunkStart = current.count - 1
        }
        liveLayer.path = InkCanvasView.outline(of: current[chunkStart...])
        // Where the system expects the pencil to be next. Drawn now, replaced by real samples later.
        let predicted = (event?.predictedTouches(for: touch) ?? []).map(sample)
        if let last = current.last, !predicted.isEmpty {
            predictedLayer.path = InkCanvasView.outline(of: ([last] + predicted)[...])
        } else {
            predictedLayer.path = nil
        }
        CATransaction.commit()

        onTouch?(touch)
        onMetrics?(ProcessInfo.processInfo.systemUptime - touch.timestamp, CACurrentMediaTime() - started, reported.count)
    }

    private func resetLive() {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        frozen.forEach { $0.removeFromSuperlayer() }
        frozen = []
        liveLayer.path = nil
        predictedLayer.path = nil
        CATransaction.commit()
        current = []
        chunkStart = 0
        activeTouch = nil
    }

    // MARK: Drawing

    private func bake(_ strokes: [[InkSample]], onto base: UIImage?) {
        guard bounds.width > 0, bounds.height > 0 else { return }
        let color = inkColor.resolvedColor(with: traitCollection).cgColor
        let image = UIGraphicsImageRenderer(size: bounds.size).image { context in
            base?.draw(at: .zero)
            context.cgContext.setFillColor(color)
            for stroke in strokes {
                context.cgContext.addPath(InkCanvasView.outline(of: stroke[...]))
                context.cgContext.fillPath()
            }
        }
        committedImage = image
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        committedLayer.contents = image.cgImage
        CATransaction.commit()
    }

    /// The filled outline of a stroke with changing width: a disc at every sample and a
    /// four-cornered piece between neighbours. All pieces run in the same direction, so
    /// where they overlap they add up instead of cutting holes.
    private static func outline(of samples: ArraySlice<InkSample>) -> CGPath {
        let path = CGMutablePath()
        var previous: InkSample?
        for s in samples {
            let r = s.width / 2
            path.addArc(center: s.location, radius: r, startAngle: 0, endAngle: 2 * .pi, clockwise: false)
            path.closeSubpath()
            if let p = previous {
                let dx = s.location.x - p.location.x
                let dy = s.location.y - p.location.y
                let length = (dx * dx + dy * dy).squareRoot()
                if length > 0 {
                    let nx = -dy / length
                    let ny = dx / length
                    let pr = p.width / 2
                    path.move(to: CGPoint(x: p.location.x + nx * pr, y: p.location.y + ny * pr))
                    path.addLine(to: CGPoint(x: p.location.x - nx * pr, y: p.location.y - ny * pr))
                    path.addLine(to: CGPoint(x: s.location.x - nx * r, y: s.location.y - ny * r))
                    path.addLine(to: CGPoint(x: s.location.x + nx * r, y: s.location.y + ny * r))
                    path.closeSubpath()
                }
            }
            previous = s
        }
        return path
    }
}
