//
//  FlexMenuApp.swift
//  FlexMenu
//
//  Created by hjy_666 on 2026/10/18.
//

import SwiftUI

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
                if let configuration = try? ConfigurationStore.loadSnapshot() {
                    let context = MenuContext.normal()
                    Task.detached {
                        let items = try? MenuScripts.resolve(
                            configuration: configuration,
                            context: context
                        )
                        await MainActor.run {
                            previewModel.menuItems = items?.map {
                                MenuItem(id: $0.id, title: $0.title)
                            } ?? []
                        }
                    }
                }
                previewModel.state = .normal
            }
        }
    }
}
