//
//  ContentView.swift
//  FlexMenu
//
//  Created by hjy_666 on 2026/10/18.
//

import SwiftUI

struct ContentView: View {
    let model: MenuModel

    var body: some View {
        let count = model.menuItems.count

        ZStack {
            if model.state != .waiting && count > 0 {
                ForEach(model.menuItems.indices, id: \.self) { index in
                    let color: Color = model.selectedIndex == index
                        ? .accentColor
                        : .blue

                    Circle()
                        .trim(
                            from: Double(index) / Double(count),
                            to: Double(index + 1) / Double(count)
                        )
                        .stroke(color, lineWidth: 40)
                        .frame(width: 160, height: 160)
                        .rotationEffect(.degrees(-90))
                }

                if count > 1 {
                    ForEach(model.menuItems.indices, id: \.self) { index in
                        Rectangle()
                            .fill(.black)
                            .frame(width: 8, height: 50)
                            .offset(y: -80)
                            .frame(width: 200, height: 200)
                            .rotationEffect(
                                .degrees(Double(index) * 360.0 / Double(count))
                            )
                            .blendMode(.destinationOut)
                    }
                }

                ForEach(model.menuItems.indices, id: \.self) { index in
                    let degrees = -90.0 + (Double(index) + 0.5) * 360.0 / Double(count)
                    let radians = degrees * .pi / 180

                    let offsetX = cos(radians) * 80
                    let offsetY = sin(radians) * 80

                    Text(model.menuItems[index].title)
                        .font(.system(size: 12))
                        .offset(x: offsetX, y: offsetY)
                }
            }
        }
        .frame(width: 200, height: 200)
        .compositingGroup()
        .contentShape(Rectangle())
    }
}

#Preview {
    let model = MenuModel()

    ContentView(model: model)
        .onAppear {
            model.state = .normal
        }
}
