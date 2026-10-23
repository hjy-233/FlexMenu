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
        let items = ["终端", "复制", "转换", "压缩", "更多"]
        let count = items.count

        ZStack {
            if model.state != .waiting {
                ForEach(0..<count, id: \.self) { i in
                    let color: Color = model.selectedIndex == i
                    ? .accentColor
                    : .blue
                    
                    Circle()
                        .trim(
                            from: Double(i) / Double(count),
                            to: Double(i + 1) / Double(count)
                        )
                        .stroke(color, lineWidth: 40)
                        .frame(width: 160, height: 160)
                        .rotationEffect(.degrees(-90))
                }
                
                ForEach(0..<count, id: \.self) { i in
                    Rectangle()
                        .fill(.black)
                        .frame(width: 8, height: 50)
                        .offset(y: -80)
                        .frame(width: 200, height: 200)
                        .rotationEffect(
                            .degrees(Double(i) * 360.0 / Double(count))
                        )
                        .blendMode(.destinationOut)
                }
                
                ForEach(0..<count, id: \.self) { i in
                    let degrees = -90.0 + (Double(i) + 0.5) * 360.0 / Double(count)
                    let radians = degrees * .pi / 180
                    
                    let x = cos(radians) * 80
                    let y = sin(radians) * 80
                    
                    Text(items[i])
                        .font(.system(size: 12))
                        .offset(x: x, y: y)
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
