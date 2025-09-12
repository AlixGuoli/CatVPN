import SwiftUI

struct RatingGuideCardView: View {
    @State private var selectedStars: Int = 0
    @State private var animationOffset: [Double] = [0, 0, 0, 0, 0]
    @Environment(\.colorScheme) private var colorScheme
    
    let onTap: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("FirstRating_Title".localstr())
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(.textGreen)
                .padding(.top, 45)
            Text("FirstRating_Description".localstr())
                .font(.body)
                .foregroundColor(.primary)
                .lineLimit(nil)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)

            Spacer() // 将星星固定到底部

            HStack(spacing: 25) {
                ForEach(1...5, id: \.self) { index in
                    let filled = index <= selectedStars
                    (filled ? Image(.starFill) : Image(.star))
                        .resizable()
                        .scaledToFit()
                        .frame(width: 32, height: 32)
                        .offset(y: animationOffset[index - 1])
                        .opacity(selectedStars == 0 ? 0.7 : 1.0)
                        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: selectedStars)
                        .onAppear {
                            startStarAnimation(for: index)
                        }
                        .onTapGesture {
                            selectedStars = index
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                                onTap()
                            }
                        }
                }
            }
            .padding(.bottom, 20)
            .frame(maxWidth: .infinity, alignment: .center)
        }
        .padding(.horizontal, 30)
        .padding(.vertical, 22)
        .frame(maxWidth: .infinity, minHeight: 260, maxHeight: 270)
        .background(
            (colorScheme == .dark ? Image(.bgRateDark) : Image(.bgRate))
                .resizable()
                .frame(maxWidth: .infinity, minHeight: 260, maxHeight: 270)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            onTap()
        }
    }
    
    private func startStarAnimation(for index: Int) {
        let delay = Double(index - 1) * 0.15
        
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            startJumpAnimation(for: index)
        }
    }
    
    private func startJumpAnimation(for index: Int) {
        // 向上跳
        withAnimation(
            .easeOut(duration: 0.2)
        ) {
            animationOffset[index - 1] = -8
        }
        
        // 落回原位
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            withAnimation(
                .easeIn(duration: 0.2)
            ) {
                animationOffset[index - 1] = 0
            }
        }
        
        // 循环跳，间隔1.2秒
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            startJumpAnimation(for: index)
        }
    }
}

#Preview {
    RatingGuideCardView {
        print("Rating card tapped!")
    }
    .padding()
}
