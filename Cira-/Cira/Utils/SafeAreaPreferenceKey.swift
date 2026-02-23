import SwiftUI

struct SafeAreaPreferenceKey: PreferenceKey {
    static var defaultValue: EdgeInsets = .init()
    
    static func reduce(value: inout EdgeInsets, nextValue: () -> EdgeInsets) {
        value = nextValue()
    }
}

extension View {
    func onSafeAreaChanged(_ action: @escaping (EdgeInsets) -> Void) -> some View {
        background(
            GeometryReader { proxy in
                Color.clear
                    .preference(key: SafeAreaPreferenceKey.self, value: proxy.safeAreaInsets)
            }
        )
        .onPreferenceChange(SafeAreaPreferenceKey.self, perform: action)
    }
}
