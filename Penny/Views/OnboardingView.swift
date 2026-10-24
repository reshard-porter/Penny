import SwiftData
import SwiftUI

/// First-launch welcome tour: what Penny does, then currency and sample-data choice.
struct OnboardingView: View {
    @Environment(\.modelContext) private var context
    @AppStorage("hasOnboarded") private var hasOnboarded = false
    @AppStorage("didSeedSample") private var didSeedSample = false
    @AppStorage("currency") private var currencyRaw = CurrencyCode.usd.rawValue

    var isReplay = false
    let onFinish: () -> Void

    @State private var page = 0
    @State private var floating = false
    @State private var withSamples = true

    private let pageCount = 3

    var body: some View {
        ZStack {
            HeroBackground(rings: false).ignoresSafeArea()
            VStack(spacing: 0) {
                HStack {
                    pageDots
                    Spacer()
                    if page < pageCount - 1 {
                        Button(isReplay ? "Close" : "Skip") {
                            if isReplay { onFinish() } else { withAnimation(.snappy) { page = pageCount - 1 } }
                        }
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Palette.heroText)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 12)
                .frame(height: 44)

                TabView(selection: $page) {
                    welcomePage.tag(0)
                    featuresPage.tag(1)
                    setupPage.tag(2)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.snappy, value: page)

                Button {
                    Haptics.tap()
                    if page < pageCount - 1 {
                        withAnimation(.snappy) { page += 1 }
                    } else {
                        finish()
                    }
                } label: {
                    HStack {
                        Text(page < pageCount - 1 ? "Continue" : (isReplay ? "Done" : "Get started"))
                        Image(systemName: "arrow.right")
                    }
                }
                .buttonStyle(PrimaryButtonStyle())
                .padding(.horizontal, 24)
                .padding(.bottom, 16)
            }
        }
        .environment(\.colorScheme, .dark)
        .onAppear {
            withAnimation(.easeInOut(duration: 2.6).repeatForever(autoreverses: true)) { floating = true }
        }
    }

    private var pageDots: some View {
        HStack(spacing: 6) {
            ForEach(0..<pageCount, id: \.self) { index in
                Capsule()
                    .fill(index == page ? Palette.lime : Color.white.opacity(0.25))
                    .frame(width: index == page ? 22 : 7, height: 7)
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: page)
        .accessibilityElement()
        .accessibilityLabel("Page \(page + 1) of \(pageCount)")
    }

    // MARK: Pages

    private var welcomePage: some View {
        VStack(spacing: 28) {
            Spacer(minLength: 0)
            ZStack {
                Circle()
                    .fill(Palette.lime.opacity(0.35))
                    .frame(width: 240)
                    .blur(radius: 60)
                Image("Coin")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 200, height: 200)
                    .rotationEffect(.degrees(floating ? -6 : 4))
                    .offset(y: floating ? -10 : 10)
                    .shadow(color: .black.opacity(0.35), radius: 24, y: 18)
                floatingCard(symbol: "briefcase.fill", color: Color(hex: 0x15803D), title: "Salary",
                             amount: "+4,200.00", positive: true)
                    .offset(x: -96, y: floating ? -112 : -100)
                floatingCard(symbol: "cart.fill", color: Color(hex: 0x0E9F6E), title: "Groceries",
                             amount: "−84.76", positive: false)
                    .offset(x: 100, y: floating ? 104 : 116)
                ZStack {
                    RingProgress(value: 0.68, lineWidth: 6, track: .white.opacity(0.15))
                    Text("68%").font(Typography.money(13, weight: .heavy)).foregroundStyle(.white)
                }
                .frame(width: 58, height: 58)
                .padding(10)
                .background(.ultraThinMaterial, in: Circle())
                .offset(x: 118, y: floating ? -70 : -82)
            }
            .frame(height: 320)
            .accessibilityHidden(true)

            VStack(spacing: 12) {
                Text("Meet Penny")
                    .font(.system(size: 40, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                Text("Small habits. Clearer money.\nTrack spending, plan budgets and grow your savings — beautifully.")
                    .font(.body)
                    .foregroundStyle(Palette.heroText)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 28)
            Spacer(minLength: 0)
        }
    }

    private func floatingCard(symbol: String, color: Color, title: String, amount: String, positive: Bool) -> some View {
        HStack(spacing: 8) {
            SymbolBadge(symbol: symbol, color: color, size: 30)
            VStack(alignment: .leading, spacing: 0) {
                Text(title).font(.caption2.weight(.semibold)).foregroundStyle(Palette.heroText)
                Text(amount).font(Typography.money(14, weight: .bold))
                    .foregroundStyle(positive ? Palette.lime : .white)
            }
        }
        .padding(.leading, 8)
        .padding(.trailing, 12)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(.white.opacity(0.15)))
    }

    private var featuresPage: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 26) {
                VStack(alignment: .leading, spacing: 10) {
                    Eyebrow(text: "Everything in one place", color: Palette.lime)
                    Text("Your money,\nfinally in focus.")
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                }
                feature("plus.circle.fill", Color(hex: 0x3552F2), "Log in seconds",
                        "Smart suggestions, receipts, repeats — or just ask Siri.")
                feature("target", Color(hex: 0x0E9F6E), "Budgets & goals",
                        "Plan each category and watch savings goals fill up.")
                feature("chart.xyaxis.line", Color(hex: 0xDB2777), "Insights that click",
                        "Pace, trends, weekly rhythm and where your money really goes.")
                feature("bell.badge.fill", Color(hex: 0xEA580C), "Gentle reminders",
                        "A daily nudge and a heads-up before bills are due.")
                feature("faceid", Color(hex: 0x7C3AED), "Private by design",
                        "Face ID lock. Everything stays on your iPhone — no account.")
            }
            .padding(.horizontal, 28)
            .padding(.vertical, 24)
        }
        .scrollBounceBehavior(.basedOnSize)
    }

    private func feature(_ symbol: String, _ color: Color, _ title: String, _ detail: String) -> some View {
        HStack(alignment: .top, spacing: 16) {
            SymbolBadge(symbol: symbol, color: color, size: 46)
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.headline).foregroundStyle(.white)
                Text(detail).font(.subheadline).foregroundStyle(Palette.heroText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var setupPage: some View {
        let popular: [CurrencyCode] = [.usd, .jmd, .eur, .gbp, .cad, .ttd]
        return ScrollView {
            VStack(alignment: .leading, spacing: 26) {
                VStack(alignment: .leading, spacing: 10) {
                    Eyebrow(text: "Almost there", color: Palette.lime)
                    Text("Make it yours")
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                }

                VStack(alignment: .leading, spacing: 12) {
                    Text("Currency").font(.headline).foregroundStyle(.white)
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 3), spacing: 10) {
                        ForEach(popular) { code in
                            currencyButton(code)
                        }
                    }
                    Menu {
                        Picker("Currency", selection: $currencyRaw) {
                            ForEach(CurrencyCode.allCases) { code in
                                Text("\(code.rawValue) · \(code.name)").tag(code.rawValue)
                            }
                        }
                    } label: {
                        HStack {
                            Text("More currencies")
                            Spacer()
                            Text(CurrencyCode(rawValue: currencyRaw)?.name ?? "")
                                .foregroundStyle(Palette.heroText)
                            Image(systemName: "chevron.up.chevron.down").font(.caption)
                        }
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                        .padding(14)
                        .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                }

                if !isReplay {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("How would you like to start?").font(.headline).foregroundStyle(.white)
                        startOption(title: "Explore with sample data",
                                    detail: "Six months of example spending, goals and bills. Clear it anytime.",
                                    symbol: "wand.and.stars", selected: withSamples) { withSamples = true }
                        startOption(title: "Start fresh",
                                    detail: "A clean slate. Add your first transaction right away.",
                                    symbol: "leaf.fill", selected: !withSamples) { withSamples = false }
                    }
                }
            }
            .padding(.horizontal, 28)
            .padding(.vertical, 24)
        }
        .scrollBounceBehavior(.basedOnSize)
    }

    private func currencyButton(_ code: CurrencyCode) -> some View {
        let selected = currencyRaw == code.rawValue
        return Button {
            Haptics.selection()
            currencyRaw = code.rawValue
        } label: {
            VStack(spacing: 2) {
                Text(code.symbol.trimmingCharacters(in: .whitespaces))
                    .font(Typography.money(20, weight: .heavy))
                Text(code.rawValue).font(.caption2.weight(.semibold)).opacity(0.75)
            }
            .foregroundStyle(selected ? Palette.navy : .white)
            .frame(maxWidth: .infinity, minHeight: 62)
            .background {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(selected ? AnyShapeStyle(Gradients.lime) : AnyShapeStyle(Color.white.opacity(0.08)))
            }
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(.white.opacity(selected ? 0 : 0.12)))
        }
        .buttonStyle(PressableStyle(scale: 0.95))
        .accessibilityLabel(code.name)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private func startOption(title: String, detail: String, symbol: String, selected: Bool,
                             action: @escaping () -> Void) -> some View {
        Button {
            Haptics.selection()
            withAnimation(.snappy) { action() }
        } label: {
            HStack(spacing: 14) {
                Image(systemName: symbol)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(selected ? Palette.navy : Palette.lime)
                    .frame(width: 44, height: 44)
                    .background(selected ? AnyShapeStyle(Gradients.lime) : AnyShapeStyle(Color.white.opacity(0.08)),
                                in: Circle())
                VStack(alignment: .leading, spacing: 3) {
                    Text(title).font(.subheadline.weight(.bold)).foregroundStyle(.white)
                    Text(detail).font(.caption).foregroundStyle(Palette.heroText)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
                Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(selected ? Palette.lime : .white.opacity(0.3))
            }
            .padding(14)
            .background(.white.opacity(selected ? 0.12 : 0.05), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(selected ? Palette.lime.opacity(0.6) : .white.opacity(0.1)))
        }
        .buttonStyle(PressableStyle())
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private func finish() {
        if !isReplay {
            hasOnboarded = true
            didSeedSample = true
            if withSamples && !SampleData.hasSamples(in: context) {
                SampleData.insert(into: context)
                RecurringEngine.run(context: context)
            }
        }
        Haptics.success()
        onFinish()
    }
}
