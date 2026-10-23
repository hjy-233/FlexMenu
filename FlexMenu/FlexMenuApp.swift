//
//  FlexMenuApp.swift
//  FlexMenu
//
//  Created by hjy_666 on 2026/10/18.
//

import SwiftUI

@main
struct FlexMenuApp: App {
    @State private var panelController = MenuPanelController()
    @State private var previewModel = MenuModel()

    var body: some Scene {
        WindowGroup {
            VStack {
                ContentView(model: previewModel)

                Button("5 秒后测试") {
                    panelController.schedule()
                }
            }
            .onAppear {
                previewModel.state = .normal
            }
        }
    }
}
