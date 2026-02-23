import Foundation

let screenHeight: CGFloat = 896 // e.g., iPhone 11 Pro Max
let top: CGFloat = 47 + 60
let bottom: CGFloat = 34 + 100
let standardGap: CGFloat = 16
let interactionHeight: CGFloat = 110
let minVerticalSpacing: CGFloat = 24

let available = screenHeight - top - bottom - standardGap - interactionHeight - (minVerticalSpacing * 2)
let cardH = min(screenHeight * 0.58, available)
print("cardH: \(cardH)")

let totalContentH = cardH + standardGap + interactionHeight
let availableH = screenHeight - top - bottom
let centering = max((availableH - totalContentH) / 2, 0)
print("centering: \(centering)")
