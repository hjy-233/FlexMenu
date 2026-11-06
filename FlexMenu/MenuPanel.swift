//
//  MenuPanel.swift
//  FlexMenu
//
//  Created by hjy_666 on 2026/10/18.
//

import AppKit
import SwiftUI

final class MenuDragView: NSView {
    var onNormal: (() -> Void)?
    var onDragging: ((NSPasteboard) -> Void)?
    var onPointerMoved: ((NSPoint) -> Void)?
    var onSelect: (() -> Bool)?

    private var state: MenuState = .waiting
    private var mouseTrackingArea: NSTrackingArea?

    override init(frame: NSRect) {
        super.init(frame: frame)
        registerForDraggedTypes([.fileURL, .string])
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        registerForDraggedTypes([.fileURL, .string])
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
        if state == .waiting {
            state = .normal
            onNormal?()
        }

        let location = convert(event.locationInWindow, from: nil)
        onPointerMoved?(location)
    }

    override func mouseDown(with _: NSEvent) {
        guard state == .normal else { return }
        _ = onSelect?()
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

    override func performDragOperation(_: NSDraggingInfo) -> Bool {
        guard state == .dragging else { return false }
        return onSelect?() ?? false
    }
}

@MainActor
final class MenuPanelController {
    private var panel: NSPanel?
    private let model = MenuModel()

    func schedule() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
            self.show()
        }
    }

    private func show() {
        model.state = .waiting
        model.selectedIndex = -1
        let mouse = NSEvent.mouseLocation
        let size: CGFloat = 260

        let rect = NSRect(
            x: mouse.x - size / 2,
            y: mouse.y - size / 2,
            width: size,
            height: size
        )

        let panel = NSPanel(
            contentRect: rect,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces]
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.ignoresMouseEvents = false

        panel.acceptsMouseMovedEvents = true

        // 创建拖放检测 View
        let dragView = MenuDragView(
            frame: NSRect(
                x: 0, y: 0,
                width: size,
                height: size
            )
        )

        configure(dragView, size: size)

        let hostingView = PassthroughHostingView(
            rootView: ContentView(model: model)
        )

        hostingView.frame = dragView.bounds
        hostingView.autoresizingMask = [.width, .height]

        dragView.addSubview(hostingView)

        panel.contentView = dragView

        self.panel?.close()
        self.panel = panel

        panel.orderFrontRegardless()
    }

    private func configure(_ dragView: MenuDragView, size: CGFloat) {
        dragView.onNormal = { [weak self] in
            self?.model.state = .normal
        }

        dragView.onDragging = { [weak self] _ in
            self?.model.state = .dragging
        }

        dragView.onPointerMoved = { [weak self] location in
            guard let self else { return }

            let center = Double(size) / 2

            let deltaX = Double(location.x) - center
            let deltaY = center - Double(location.y)

            let distance = hypot(deltaX, deltaY)

            if distance < 45 || distance > 110 {
                self.model.selectedIndex = -1
                return
            }

            let degrees = atan2(deltaY, deltaX) * 180 / .pi

            let adjusted = (degrees + 450)
                .truncatingRemainder(dividingBy: 360)

            let count = self.model.menuItems.count
            guard count > 0 else {
                self.model.selectedIndex = -1
                return
            }

            self.model.selectedIndex = Int(
                adjusted / (360.0 / Double(count))
            )
        }

        dragView.onSelect = { [weak self] in
            DispatchQueue.main.async {
                if let panel = self?.panel, self?.model.selectedIndex != -1 {
                    panel.close()
                }
            }
            guard let self else { return false }
            let index = self.model.selectedIndex
            guard self.model.menuItems.indices.contains(index) else { return false }
            print("执行：\(self.model.menuItems[index].id)")
            return true
        }
    }
}

final class PassthroughHostingView<Content: View>: NSHostingView<Content> {
    override func hitTest(_: NSPoint) -> NSView? {
        nil
    }
}
