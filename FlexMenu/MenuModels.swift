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
    var menuItems: [MenuItem] = [
        MenuItem(id: "terminal", title: "终端"),
        MenuItem(id: "copy", title: "复制"),
        MenuItem(id: "convert", title: "转换"),
        MenuItem(id: "compress", title: "压缩"),
        MenuItem(id: "more", title: "更多")
    ]
}
