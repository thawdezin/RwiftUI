import SwiftUI

// MARK: - TabItem Model
struct TabItem: Identifiable {
    let id = UUID()
    let iconName: String
    let label: String
}

// MARK: - ContentView
struct ContentView: View {
    @State private var selectedIndex: Int = 0
    let tabItems: [TabItem] = [
        TabItem(iconName: "phone.fill", label: "Calls"),
        TabItem(iconName: "person.fill", label: "Contacts"),
        TabItem(iconName: "entry.lever.keypad", label: "Keypad"),
        TabItem(iconName: "magnifyingglass", label: "Search")
    ]

    var body: some View {
        ZStack {
            Color.white
                .edgesIgnoringSafeArea(.all)

            VStack {
                Spacer()
                pageView
                Spacer()
            }

            VStack {
                Spacer()
                GlassmorphicBottomNavBar(
                    selectedIndex: $selectedIndex,
                    tabItems: tabItems
                )
                .padding(.horizontal, 16)
                .padding(.vertical, 20)
            }
        }
        .preferredColorScheme(.light)
    }

    @ViewBuilder
    private var pageView: some View {
        switch selectedIndex {
        case 0:
            Text("Calls Page")
        case 1:
            Text("Contacts Page")
        case 2:
            Text("Keypad Page")
        default:
            Text("Search Page")
        }
        
    }
}

// MARK: - GlassmorphicBottomNavBar
struct GlassmorphicBottomNavBar: View {
    @Binding var selectedIndex: Int
    let tabItems: [TabItem]

    @State private var dragOffset: CGFloat = 0
    @State private var pillScale: CGFloat = 1

    private let barHeight: CGFloat = 70
    private let pillHeight: CGFloat = 80
    private let pillWidthMultiplier: CGFloat = 1.2

    var body: some View {
        GeometryReader { geo in
            let totalWidth = geo.size.width
            let itemWidth = totalWidth / CGFloat(tabItems.count)
            let pillWidth = itemWidth * pillWidthMultiplier
            let pillXOffset = calculatePillXOffset(
                itemWidth: itemWidth,
                pillWidth: pillWidth,
                totalWidth: totalWidth
            )

            ZStack {
                backgroundBar
                    .frame(height: barHeight)

                navigationItems(itemWidth: itemWidth)

                pillIndicator(width: pillWidth, xOffset: pillXOffset)
            }
            .frame(maxWidth: .infinity, maxHeight: pillHeight)
            .offset(y: (geo.size.height - barHeight) / 2 - (pillHeight - barHeight) / 2)
            .gesture(dragGesture(itemWidth: itemWidth))
        }
        .frame(height: pillHeight + 20)
    }

    private var backgroundBar: some View {
        RoundedRectangle(cornerRadius: 35)
            .fill(Material.ultraThinMaterial)
            .stroke(Color.black.opacity(0.1), lineWidth: 1)
            .shadow(color: Color.black.opacity(0.05), radius: 15, x: 0, y: 5)
    }

    private func navigationItems(itemWidth: CGFloat) -> some View {
        HStack(spacing: 0) {
            ForEach(tabItems.indices, id: \.self) { idx in
                Button {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        selectedIndex = idx
                        dragOffset = 0
                        pillScale = 1
                    }
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: tabItems[idx].iconName)
                            .font(.system(size: 24))
                            .foregroundColor(iconColor(for: idx))
                        Text(tabItems[idx].label)
                            .font(.system(size: 12))
                            .foregroundColor(iconColor(for: idx))
                    }
                    .frame(width: itemWidth, height: barHeight)
                }
            }
        }
    }

    /// Updated pillIndicator to include icon + label
    private func pillIndicator(width: CGFloat, xOffset: CGFloat) -> some View {
        ZStack {
            // Pill background
            RoundedRectangle(cornerRadius: 30)
                .fill(Material.regularMaterial)
                .stroke(Color.blue.opacity(0.3), lineWidth: 1)
                .shadow(color: Color.blue.opacity(0.3), radius: 20, x: 0, y: 3)
                .frame(width: width, height: pillHeight)

            // Icon + Label inside pill
            VStack(spacing: 8) {
                Image(systemName: tabItems[selectedIndex].iconName)
                    .font(.system(size: 24))
                Text(tabItems[selectedIndex].label)
                    .font(.system(size: 14))
            }
            .foregroundColor(.black.opacity(0.7))
        }
        .offset(x: xOffset + dragOffset)
        .scaleEffect(pillScale)
        .gesture(
            LongPressGesture(minimumDuration: 0.1)
                .onChanged { pressing in
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                        pillScale = pressing ? 1.1 : 1.0
                    }
                }
        )
    }

    private func dragGesture(itemWidth: CGFloat) -> _EndedGesture<_ChangedGesture<DragGesture>> {
        DragGesture()
            .onChanged { val in
                dragOffset = val.translation.width
                    .clamped(-CGFloat(selectedIndex) * itemWidth,
                             CGFloat(tabItems.count - 1 - selectedIndex) * itemWidth)
                withAnimation(.easeInOut(duration: 0.1)) {
                    pillScale = 1.02
                }
            }
            .onEnded { val in
                let delta = (val.predictedEndTranslation.width / itemWidth).rounded()
                let newIndex = (selectedIndex + Int(delta))
                    .clamped(0, tabItems.count - 1)
                withAnimation(.easeInOut(duration: 0.3)) {
                    selectedIndex = newIndex
                    dragOffset = 0
                    pillScale = 1
                }
            }
    }

    private func calculatePillXOffset(itemWidth: CGFloat, pillWidth: CGFloat, totalWidth: CGFloat) -> CGFloat {
        let baseX = CGFloat(selectedIndex) * itemWidth + itemWidth / 2
        let centered = baseX - pillWidth / 2
        let centerOffset = totalWidth / 2 - pillWidth / 2
        return centered - centerOffset
    }

    private func iconColor(for index: Int) -> Color {
        selectedIndex == index
            ? Color.black.opacity(0.2)
            : Color.black.opacity(0.6)
    }
}

// MARK: - Clamping Extension
extension Comparable {
    func clamped(_ lower: Self, _ upper: Self) -> Self {
        max(lower, min(self, upper))
    }
}

