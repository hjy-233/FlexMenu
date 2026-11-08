//
//  MenuModels.swift
//  FlexMenu
//
//  Created by hjy_666 on 2026/10/18.
//

import CoreGraphics
import Observation

enum MenuState {
    case waiting
    case normal
    case dragging
    case feedback
}

struct MenuItem: Identifiable {
    let id: String
    let title: String
}

@MainActor
@Observable
final class MenuModel {
    var state: MenuState = .waiting
    var selectedIndex: Int = -1
    var feedbackTitle: String?
    var menuItems: [MenuItem] = []
    var menuDefinitions: [MenuItemDefinition] = []
    var context: MenuContext?
}

enum MenuWheelGeometry {
    static let size: CGFloat = 200
    static let innerRadius: CGFloat = 56
    static let outerRadius: CGFloat = 100
    static let hitInnerRadius: Double = 45
    static let hitOuterRadius: Double = 110
    static let gapDegrees: Double = 3

    static func angle(for index: Int, count: Int) -> Double {
        -90 + Double(index) * 360 / Double(count)
    }
}
