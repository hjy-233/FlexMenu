//
//  ContentView.swift
//  FlexMenu
//
//  Created by hjy_666 on 2026/10/18.
//

import SwiftUI

struct ContentView: View {
    @State private var selectedIndex = -1
    
    var body: some View {
        let items = ["终端", "复制", "转换", "压缩", "更多"]
        let count = items.count

        ZStack {
            ForEach(0..<count, id: \.self) { i in
                let color: Color = selectedIndex == i
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
        .frame(width: 200, height: 200)
        .compositingGroup()
        .contentShape(Rectangle())
        .onContinuousHover { phase in
            switch phase {
            case .ended:
                selectedIndex = -1
                break
            case .active(let location):
                let dx = Double(location.x - 100)
                let dy = Double(location.y - 100)

                let distance = hypot(dx, dy)
                let radians = atan2(dy, dx)
                var degrees = radians * 180 / .pi

                if degrees < 0 {
                    degrees += 360
                }
                
                let adjusted = (degrees + 90)
                    .truncatingRemainder(dividingBy: 360)
                selectedIndex = Int(adjusted / (360 / Double(count)))
                
                if distance < 45 {
                    selectedIndex = -1
                }

                print("距离圆心：\(distance)， 角度：\(degrees)，当前选中：\(selectedIndex)")
            }
        }
        .onTapGesture {
            if selectedIndex != -1 {
                print("被点击了！")
            } else {
                print("未选择")
            }
        }
    }
}

#Preview {
    ContentView()
}
