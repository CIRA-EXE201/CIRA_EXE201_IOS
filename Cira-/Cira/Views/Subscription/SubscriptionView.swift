//
//  SubscriptionView.swift
//  Cira
//
//  Subscription plans popup
//

import SwiftUI

// MARK: - Subscription Plan Model
struct SubscriptionPlan: Identifiable {
    let id = UUID()
    let name: String
    let targetUsers: String
    let monthlyPrice: Int
    let yearlyPrice: Int
    let storage: String
    let aiVoice: String
    let sharing: String
    let duration: String
    let isPopular: Bool
    let accentColor: Color
    
    var monthlyPriceText: String {
        monthlyPrice == 0 ? "Free" : "$\(monthlyPrice / 23000)/mo"
    }
    
    var yearlyPriceText: String {
        yearlyPrice == 0 ? "" : "$\(yearlyPrice / 23000)/yr"
    }
    
    private func formatPrice(_ price: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = "."
        return formatter.string(from: NSNumber(value: price)) ?? "\(price)"
    }
    
    static let allPlans: [SubscriptionPlan] = [
        SubscriptionPlan(
            name: "Starter",
            targetUsers: "New users",
            monthlyPrice: 0,
            yearlyPrice: 0,
            storage: "20 photos / 1 story",
            aiVoice: "1 auto story",
            sharing: "3 chapters",
            duration: "30 days",
            isPopular: false,
            accentColor: .gray
        ),
        SubscriptionPlan(
            name: "Personal",
            targetUsers: "Individual",
            monthlyPrice: 79000,
            yearlyPrice: 899000,
            storage: "200 photos / 10 stories",
            aiVoice: "Warm AI storytelling",
            sharing: "Family feed",
            duration: "Forever",
            isPopular: false,
            accentColor: .blue
        ),
        SubscriptionPlan(
            name: "Family",
            targetUsers: "Family of 2-5",
            monthlyPrice: 179000,
            yearlyPrice: 2040000,
            storage: "1,000 photos",
            aiVoice: "Personalized voice",
            sharing: "Family feed",
            duration: "Forever",
            isPopular: true,
            accentColor: .orange
        ),
        SubscriptionPlan(
            name: "Premium",
            targetUsers: "Large family",
            monthlyPrice: 499000,
            yearlyPrice: 5599000,
            storage: "Unlimited",
            aiVoice: "Personalized voice",
            sharing: "Family feed",
            duration: "Lifetime",
            isPopular: false,
            accentColor: .purple
        )
    ]
}

// MARK: - Subscription View
struct SubscriptionView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var selectedPlan: SubscriptionPlan? = nil
    @State private var billingCycle: BillingCycle = .yearly
    
    enum BillingCycle: String, CaseIterable {
        case monthly = "Monthly"
        case yearly = "Yearly"
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Handle bar
            handleBar
            
            // Header
            headerSection
            
            // Billing toggle
            billingToggle
                .padding(.top, 16)
            
            // Plans
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(SubscriptionPlan.allPlans) { plan in
                        PlanCard(
                            plan: plan,
                            isSelected: selectedPlan?.id == plan.id,
                            billingCycle: billingCycle
                        ) {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                selectedPlan = plan
                            }
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            }
            
            // Subscribe button
            subscribeButton
                .padding(.horizontal, 20)
                .padding(.bottom, 16)
            
            // Terms
            termsText
                .padding(.bottom, 20)
        }
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
        .shadow(color: .black.opacity(0.15), radius: 20, y: -5)
        .onAppear {
            // Default select Family plan
            selectedPlan = SubscriptionPlan.allPlans.first { $0.isPopular }
        }
    }
    
    // MARK: - Handle Bar
    private var handleBar: some View {
        RoundedRectangle(cornerRadius: 3)
            .fill(Color.gray.opacity(0.3))
            .frame(width: 40, height: 5)
            .padding(.top, 12)
            .padding(.bottom, 8)
    }
    
    // MARK: - Header
    private var headerSection: some View {
        VStack(spacing: 8) {
            HStack {
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: 32, height: 32)
                        .background(Circle().fill(Color.gray.opacity(0.1)))
                }
                
                Spacer()
                
                // Gold badge
                HStack(spacing: 4) {
                    Image(systemName: "star.fill")
                        .font(.system(size: 12))
                    Text("CIRA")
                        .font(.system(size: 14, weight: .bold))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    LinearGradient(
                        colors: [.yellow, .orange],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .clipShape(Capsule())
                
                Spacer()
                
                // Invisible placeholder for balance
                Color.clear.frame(width: 32, height: 32)
            }
            .padding(.horizontal, 20)
            
            Text("Preserve memories\nforever")
                .font(.system(size: 28, weight: .bold))
                .multilineTextAlignment(.center)
                .padding(.top, 8)
            
            Text("Choose the plan that fits your family")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }
    
    // MARK: - Billing Toggle
    private var billingToggle: some View {
        HStack(spacing: 0) {
            ForEach(BillingCycle.allCases, id: \.self) { cycle in
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        billingCycle = cycle
                    }
                }) {
                    VStack(spacing: 2) {
                        Text(cycle.rawValue)
                            .font(.system(size: 14, weight: billingCycle == cycle ? .semibold : .medium))
                        
                        if cycle == .yearly {
                            Text("Save 15%")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle(.green)
                        }
                    }
                    .foregroundStyle(billingCycle == cycle ? .black : .secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(billingCycle == cycle ? Color.white : Color.clear)
                            .shadow(color: billingCycle == cycle ? .black.opacity(0.08) : .clear, radius: 4, y: 2)
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.gray.opacity(0.1))
        )
        .padding(.horizontal, 20)
    }
    
    // MARK: - Subscribe Button
    private var subscribeButton: some View {
        Button(action: {
            // Handle subscription
        }) {
            HStack {
                if let plan = selectedPlan {
                    Text(plan.monthlyPrice == 0 ? "Start for free" : "Subscribe to \(plan.name)")
                        .font(.system(size: 17, weight: .semibold))
                } else {
                    Text("Select a plan")
                        .font(.system(size: 17, weight: .semibold))
                }
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(selectedPlan?.accentColor ?? .gray)
            )
        }
        .buttonStyle(.plain)
        .disabled(selectedPlan == nil)
    }
    
    // MARK: - Terms
    private var termsText: some View {
        Text("By subscribing, you agree to our [Terms](terms) and [Privacy Policy](privacy)")
            .font(.caption)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
    }
}

// MARK: - Plan Card
struct PlanCard: View {
    let plan: SubscriptionPlan
    let isSelected: Bool
    let billingCycle: SubscriptionView.BillingCycle
    let onTap: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(plan.name)
                        .font(.system(size: 18, weight: .bold))
                    
                    Text(plan.targetUsers)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                if plan.isPopular {
                    Text("Popular")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(plan.accentColor))
                }
            }
            
            // Price
            VStack(alignment: .leading, spacing: 2) {
                if billingCycle == .monthly {
                    Text(plan.monthlyPriceText)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(plan.accentColor)
                } else {
                    if plan.yearlyPrice > 0 {
                        Text(plan.yearlyPriceText)
                            .font(.system(size: 20, weight: .bold))
                            .foregroundStyle(plan.accentColor)
                    } else {
                        Text("Free")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundStyle(plan.accentColor)
                    }
                }
            }
            
            Divider()
            
            // Features
            VStack(alignment: .leading, spacing: 8) {
                FeatureRow(icon: "photo.stack", text: plan.storage)
                FeatureRow(icon: "waveform", text: plan.aiVoice)
                FeatureRow(icon: "person.2", text: plan.sharing)
                FeatureRow(icon: "clock", text: plan.duration)
            }
            
            Spacer()
        }
        .padding(16)
        .frame(width: 200, height: 280)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.white)
                .shadow(color: isSelected ? plan.accentColor.opacity(0.3) : .black.opacity(0.08), 
                       radius: isSelected ? 12 : 8, 
                       y: isSelected ? 4 : 2)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(isSelected ? plan.accentColor : Color.gray.opacity(0.2), lineWidth: isSelected ? 2 : 1)
        )
        .scaleEffect(isSelected ? 1.02 : 1)
        .onTapGesture(perform: onTap)
    }
}

// MARK: - Feature Row
struct FeatureRow: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .frame(width: 16)
            
            Text(text)
                .font(.system(size: 12))
                .foregroundStyle(.primary)
                .lineLimit(2)
        }
    }
}

#Preview {
    ZStack {
        Color.gray.opacity(0.3).ignoresSafeArea()
        
        VStack {
            Spacer()
            SubscriptionView()
                .frame(height: 580)
        }
    }
}
