//
//  MenuModels.swift
//  FlexMenu
//
//  Created by hjy_666 on 2026/10/18.
//

import Observation

enum MenuState {
    case waiting
    case normal
    case dragging
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
    var menuItems: [MenuItem] = []
    var menuDefinitions: [MenuItemDefinition] = []
    var context: MenuContext?
}
