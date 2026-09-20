import SwiftUI
import UIKit

/// One UIKit gesture surface arbitrates capture, swipes, and multi-touch menus.
/// A three-finger tap or long press can never also trigger a photo capture.
struct CanvasGestures: UIViewRepresentable {
    var onCapture: () -> Void
    var onStep: (Int) -> Void
    var onPicker: () -> Void
    var onRecord: () -> Void = {}

    func makeUIView(context: Context) -> Surface {
        let view = Surface()
        updateUIView(view, context: context)
        return view
    }

    func updateUIView(_ view: Surface, context: Context) {
        view.onCapture = onCapture
        view.onStep = onStep
        view.onPicker = onPicker
        view.onRecord = onRecord
    }

    final class Surface: UIView {
        var onCapture: (() -> Void)?
        var onStep: ((Int) -> Void)?
        var onPicker: (() -> Void)?
        var onRecord: (() -> Void)?

        override init(frame: CGRect) {
            super.init(frame: frame)
            backgroundColor = .clear
            isMultipleTouchEnabled = true
            isAccessibilityElement = false

            let menu = UITapGestureRecognizer(target: self, action: #selector(showPicker))
            menu.numberOfTouchesRequired = 3
            let record = UITapGestureRecognizer(target: self, action: #selector(toggleRecording))
            record.numberOfTouchesRequired = 2
            record.require(toFail: menu)
            let hold = UILongPressGestureRecognizer(target: self, action: #selector(held(_:)))
            hold.minimumPressDuration = 0.6
            hold.numberOfTouchesRequired = 1
            let left = UISwipeGestureRecognizer(target: self, action: #selector(swiped(_:)))
            left.direction = .left
            let right = UISwipeGestureRecognizer(target: self, action: #selector(swiped(_:)))
            right.direction = .right
            let tap = UITapGestureRecognizer(target: self, action: #selector(capture))
            tap.numberOfTouchesRequired = 1
            for recognizer in [menu, record, hold, left, right] {
                tap.require(toFail: recognizer)
            }
            left.require(toFail: menu)
            right.require(toFail: menu)
            [menu, record, hold, left, right, tap].forEach(addGestureRecognizer)
        }

        required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
        @objc private func toggleRecording() { onRecord?() }
        @objc private func capture() { onCapture?() }
        @objc private func showPicker() { onPicker?() }
        @objc private func held(_ gesture: UILongPressGestureRecognizer) {
            if gesture.state == .began { onPicker?() }
        }
        @objc private func swiped(_ gesture: UISwipeGestureRecognizer) {
            onStep?(gesture.direction == .left ? 1 : -1)
        }
    }
}
