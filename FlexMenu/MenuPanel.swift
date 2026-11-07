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

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 {
            onCancel?()
        } else {
            super.keyDown(with: event)
        }
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
        state = .waiting
        onCancel?()
    }

    override func draggingEnded(_: NSDraggingInfo) {
        state = .waiting
        onCancel?()
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
    private let configuration: MenuConfiguration?
    private var requestID = 0

    init(configuration: MenuConfiguration? = try? ConfigurationStore.loadSnapshot()) {
        self.configuration = configuration
    }

    func schedule() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
            self.show()
        }
    }

    func show() {
        guard panel?.isVisible != true else { return }
        model.state = .waiting
        model.selectedIndex = -1
        model.menuItems = []
        model.menuDefinitions = []
        model.context = nil
        requestID += 1
        let mouse = NSEvent.mouseLocation
        let size: CGFloat = 260

        let rect = NSRect(
            x: mouse.x - size / 2,
            y: mouse.y - size / 2,
            width: size,
            height: size
        )

        let panel = MenuPanel(
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

        panel.makeFirstResponder(dragView)
        panel.makeKeyAndOrderFront(nil)
    }

    private func configure(_ dragView: MenuDragView, size: CGFloat) {
        dragView.onNormal = { [weak self] in
            self?.resolve(MenuContext.normal())
        }

        dragView.onDragging = { [weak self] pasteboard in
            self?.resolve(MenuContext.dragging(pasteboard))
        }

        dragView.onCancel = { [weak self] in
            self?.cancel()
        }

        dragView.onPointerMoved = { [weak self] location in
            self?.updateSelection(at: location, size: size)
        }

        dragView.onSelect = { [weak self] in
            DispatchQueue.main.async {
                if let panel = self?.panel, self?.model.selectedIndex != -1 {
                    panel.close()
                }
            }
            guard let self else { return false }
            let index = self.model.selectedIndex
            guard self.model.menuDefinitions.indices.contains(index),
                  let configuration = self.configuration,
                  let context = self.model.context else { return false }
            let item = self.model.menuDefinitions[index]
            Task.detached {
                do {
                    let result = try MenuScripts.run(
                        item: item,
                        configuration: configuration,
                        context: context
                    )
                    if result.status != 0 {
                        Self.log("动作失败（\(item.id)）：\(result.error)")
                    }
                } catch {
                    Self.log("动作失败（\(item.id)）：\(error.localizedDescription)")
                }
            }
            return true
        }
    }

    private func updateSelection(at location: NSPoint, size: CGFloat) {
        let center = Double(size) / 2
        let deltaX = Double(location.x) - center
        let deltaY = center - Double(location.y)
        let distance = hypot(deltaX, deltaY)
        guard (45 ... 110).contains(distance), !model.menuItems.isEmpty else {
            model.selectedIndex = -1
            return
        }
        let degrees = atan2(deltaY, deltaX) * 180 / .pi
        let adjusted = (degrees + 450).truncatingRemainder(dividingBy: 360)
        model.selectedIndex = Int(adjusted / (360.0 / Double(model.menuItems.count)))
    }

    private func resolve(_ context: MenuContext) {
        guard let configuration else {
            Self.log("配置未加载，请先运行 flexmenu service start")
            panel?.close()
            return
        }
        requestID += 1
        let currentRequest = requestID
        Task.detached { [weak self] in
            do {
                let items = try MenuScripts.resolve(
                    configuration: configuration,
                    context: context
                )
                await self?.finishResolve(items, context: context, request: currentRequest)
            } catch {
                await self?.failResolve(error, request: currentRequest)
            }
        }
    }

    private func finishResolve(
        _ items: [MenuItemDefinition],
        context: MenuContext,
        request: Int
    ) {
        guard requestID == request else { return }
        model.menuDefinitions = items
        model.context = context
        model.menuItems = items.map { MenuItem(id: $0.id, title: $0.title) }
        model.state = context.mode == "dragging" ? .dragging : .normal
        if items.isEmpty {
            panel?.close()
        }
    }

    private func failResolve(_ error: Error, request: Int) {
        guard requestID == request else { return }
        Self.log("菜单解析失败：\(error.localizedDescription)")
        panel?.close()
    }

    private func cancel() {
        requestID += 1
        model.selectedIndex = -1
        model.menuItems = []
        model.menuDefinitions = []
        model.context = nil
        panel?.close()
    }

    private nonisolated static func log(_ message: String) {
        FileHandle.standardError.write(Data("flexmenu: \(message)\n".utf8))
    }
}

private final class MenuPanel: NSPanel {
    override var canBecomeKey: Bool {
        true
    }
}

final class PassthroughHostingView<Content: View>: NSHostingView<Content> {
    override func hitTest(_: NSPoint) -> NSView? {
        nil
    }
}
