//
//  ScrollDownHint.swift
//  Cira
//

import SwiftUI

struct ScrollDownHint: View {
    var body: some View {
        Image(systemName: "chevron.compact.down")
            .font(.system(size: 28, weight: .bold))
            .foregroundStyle(.black.opacity(0.7))
            .allowsHitTesting(false)
    }
}
