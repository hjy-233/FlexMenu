//
//  MenuPanel.swift
//  FlexMenu
//
//  Created by hjy_666 on 2026/10/18.
//

import AppKit
import SwiftUI

@MainActor
final class MenuPanelController {
    private var panel: NSPanel?
    private let model = MenuModel()
    private var configuration: MenuConfiguration?
    private var requestID = 0

    init(configuration: MenuConfiguration? = try? ConfigurationStore.loadSnapshot()) {
        self.configuration = configuration
    }

    func updateConfiguration(_ configuration: MenuConfiguration) {
        cancel()
        self.configuration = configuration
    }

    func schedule() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
            self.show()
        }
    }

    func show() {
        guard panel?.isVisible != true else { return }
        clearMenu()
        requestID += 1
        let mouse = NSEvent.mouseLocation
        let size: CGFloat = 260

        let rect = NSRect(
            x: mouse.x - size / 2,
            y: mouse.y - size / 2,
            width: size,
            height: size
        )

        if showExistingPanel(at: rect) {
            return
        }

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

        self.panel = panel

        panel.makeFirstResponder(dragView)
        panel.makeKeyAndOrderFront(nil)
        dragView.activateNormal()
    }

    private func showExistingPanel(at rect: NSRect) -> Bool {
        guard let panel, let dragView = panel.contentView as? MenuDragView else { return false }
        dragView.reset()
        panel.setFrame(rect, display: false)
        panel.makeFirstResponder(dragView)
        panel.makeKeyAndOrderFront(nil)
        dragView.activateNormal()
        return true
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

        dragView.onSelect = { [weak self, weak dragView] in
            guard let self else { return false }
            return self.select(self.model.selectedIndex, dragView: dragView)
        }

        dragView.onSelectNumber = { [weak self, weak dragView] index in
            self?.select(index, dragView: dragView) ?? false
        }
    }

    private func select(_ index: Int, dragView: MenuDragView?) -> Bool {
        guard model.state == .normal || model.state == .dragging,
              model.menuDefinitions.indices.contains(index),
              let configuration,
              let context = model.context else { return false }
        let item = model.menuDefinitions[index]
        requestID += 1
        let feedbackRequest = requestID
        model.selectedIndex = index
        model.feedbackTitle = item.title
        model.state = .feedback
        dragView?.showFeedback()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            guard let self, self.requestID == feedbackRequest else { return }
            self.panel?.orderOut(nil)
        }

        Task.detached {
            do {
                let result = try MenuScripts.run(
                    item: item,
                    configuration: configuration,
                    context: context
                )
                if result.status != 0 {
                    Self.log(L10n.format("动作失败（%@）：%@", item.id, result.error))
                }
            } catch {
                Self.log(L10n.format("动作失败（%@）：%@", item.id, error.localizedDescription))
            }
        }
        return true
    }

    private func updateSelection(at location: NSPoint, size: CGFloat) {
        let center = Double(size) / 2
        let deltaX = Double(location.x) - center
        let deltaY = center - Double(location.y)
        let distance = hypot(deltaX, deltaY)
        guard model.state != .feedback,
              (MenuWheelGeometry.hitInnerRadius ... MenuWheelGeometry.hitOuterRadius)
                  .contains(distance), !model.menuItems.isEmpty
        else {
            model.selectedIndex = -1
            return
        }
        let degrees = atan2(deltaY, deltaX) * 180 / .pi
        let segmentAngle = 360.0 / Double(model.menuItems.count)
        let adjusted = (degrees + 450 + segmentAngle / 2)
            .truncatingRemainder(dividingBy: 360)
        model.selectedIndex = Int(adjusted / segmentAngle)
    }

    private func resolve(_ context: MenuContext) {
        guard let configuration else {
            Self.log(L10n.text("配置未加载，请先运行 flexmenu service start"))
            panel?.orderOut(nil)
            return
        }
        if context.mode == "dragging" {
            clearMenu()
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
        model.feedbackTitle = nil
        model.menuItems = items.map { MenuItem(id: $0.id, title: $0.title) }
        model.state = context.mode == "dragging" ? .dragging : .normal
        if items.isEmpty {
            panel?.orderOut(nil)
        }
    }

    private func failResolve(_ error: Error, request: Int) {
        guard requestID == request else { return }
        Self.log(L10n.format("菜单解析失败：%@", error.localizedDescription))
        panel?.orderOut(nil)
    }

    private func cancel() {
        requestID += 1
        clearMenu()
        panel?.orderOut(nil)
    }

    private func clearMenu() {
        model.state = .waiting
        model.selectedIndex = -1
        model.feedbackTitle = nil
        model.menuItems = []
        model.menuDefinitions = []
        model.context = nil
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
