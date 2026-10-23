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

@MainActor
@Observable
final class MenuModel {
    var state: MenuState = .waiting
    var selectedIndex: Int = -1
}
