import AppKit

final class MenuDragView: NSView {
    var onNormal: (() -> Void)?
    var onDragging: ((NSPasteboard) -> Void)?
    var onPointerMoved: ((NSPoint) -> Void)?
    var onSelect: (() -> Bool)?
    var onSelectNumber: ((Int) -> Bool)?
    var onCancel: (() -> Void)?

    private var state: MenuState = .waiting
    private var mouseTrackingArea: NSTrackingArea?

    override var acceptsFirstResponder: Bool {
        true
    }

    override init(frame: NSRect) {
        super.init(frame: frame)
        registerForDraggedTypes([.fileURL, .string])
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        registerForDraggedTypes([.fileURL, .string])
    }

    func reset() {
        state = .waiting
    }

    func showFeedback() {
        state = .feedback
    }

    func activateNormal() {
        guard state == .waiting else { return }
        state = .normal
        onNormal?()
    }

    // MARK: - Mouse Tracking

    override func updateTrackingAreas() {
        super.updateTrackingAreas()

        if let mouseTrackingArea {
            removeTrackingArea(mouseTrackingArea)
        }

        let area = NSTrackingArea(
            rect: .zero,
            options: [
                .mouseMoved,
                .activeAlways,
                .inVisibleRect
            ],
            owner: self,
            userInfo: nil
        )

        addTrackingArea(area)
        mouseTrackingArea = area
    }

    override func mouseMoved(with event: NSEvent) {
        guard state != .feedback else { return }
        if state == .waiting {
            activateNormal()
        }

        let location = convert(event.locationInWindow, from: nil)
        onPointerMoved?(location)
    }

    override func mouseDown(with _: NSEvent) {
        guard state == .normal else { return }
        _ = onSelect?()
    }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 {
            onCancel?()
            return
        }
        let canSelect = state == .normal || state == .dragging
        let unmodified = event.modifierFlags.isDisjoint(with: [.command, .option, .control])
        let number = event.charactersIgnoringModifiers.flatMap { Int($0) }
        if canSelect, unmodified, let number, (1 ... 9).contains(number) {
            _ = onSelectNumber?(number - 1)
            return
        }
        super.keyDown(with: event)
    }

    override func cancelOperation(_: Any?) {
        onCancel?()
    }

    // MARK: - Dragging

    override func draggingEntered(
        _ sender: NSDraggingInfo
    ) -> NSDragOperation {
        state = .dragging

        let pasteboard = sender.draggingPasteboard
        onDragging?(pasteboard)

        let location = convert(sender.draggingLocation, from: nil)
        onPointerMoved?(location)

        return .copy
    }

    override func prepareForDragOperation(
        _: NSDraggingInfo
    ) -> Bool {
        true
    }

    override func draggingUpdated(
        _ sender: NSDraggingInfo
    ) -> NSDragOperation {
        let location = convert(sender.draggingLocation, from: nil)
        onPointerMoved?(location)

        return .copy
    }

    override func draggingExited(_: NSDraggingInfo?) {
        guard state != .feedback else { return }
        state = .waiting
        onCancel?()
    }

    override func draggingEnded(_: NSDraggingInfo) {
        guard state != .feedback else { return }
        state = .waiting
        onCancel?()
    }

    override func performDragOperation(_: NSDraggingInfo) -> Bool {
        guard state == .dragging else { return false }
        return onSelect?() ?? false
    }
}
