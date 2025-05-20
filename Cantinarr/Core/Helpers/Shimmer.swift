import SwiftUI

/// A simple shimmer overlay you can apply to any View.
struct Shimmer: ViewModifier {
    @State private var phase: CGFloat = -0.5

    func body(content: Content) -> some View {
        content
            .overlay(
                // gradient band
                LinearGradient(
                    gradient: Gradient(stops: [
                        .init(color: .white.opacity(0.25), location: 0),
                        .init(color: .white.opacity(0.6), location: 0.5),
                        .init(color: .white.opacity(0.25), location: 1),
                    ]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .rotationEffect(.degrees(30))
                .offset(x: phase * 300) // animate across
                .mask(content)
            )
            .onAppear {
                withAnimation(
                    .linear(duration: 1.2)
                        .repeatForever(autoreverses: false)
                ) {
                    phase = 0.5
                }
            }
    }
}

extension View {
    func shimmer() -> some View {
        modifier(Shimmer())
    }
}
