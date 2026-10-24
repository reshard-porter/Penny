import SwiftData
import SwiftUI

// MARK: - Goals list

struct GoalsSection: View {
    @Query(sort: \SavingsGoal.createdAt) private var goals: [SavingsGoal]
    @Query private var contributions: [GoalContribution]
    @AppStorage("currency") private var currencyRaw = CurrencyCode.usd.rawValue
    @State private var showNewGoal = false
    @State private var showArchived = false

    private var currency: CurrencyCode { CurrencyCode(rawValue: currencyRaw) ?? .usd }

    var body: some View {
        let saved = GoalMath.saved(contributions)
        let active = goals.filter { !$0.isArchived }
        let archived = goals.filter(\.isArchived)
        let totalSaved = active.reduce(0) { $0 + max(0, saved[$1.id] ?? 0) }
        let totalTarget = active.reduce(0) { $0 + $1.targetCents }

        VStack(spacing: 16) {
            if active.isEmpty {
                VStack(spacing: 16) {
                    Image("Coin")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 130, height: 130)
                        .shadow(color: Palette.limeDeep.opacity(0.4), radius: 24, y: 10)
                    Text("Save for what matters")
                        .font(.title2.weight(.bold)).foregroundStyle(.white)
                    Text("A trip, a rainy-day fund, something you’ve had your eye on. Set a target and watch it fill up.")
                        .font(.subheadline).foregroundStyle(Palette.heroText)
                        .multilineTextAlignment(.center)
                    Button("Create a goal") { showNewGoal = true }
                        .buttonStyle(PrimaryButtonStyle())
                        .padding(.top, 4)
                }
                .frame(maxWidth: .infinity)
                .heroCard(padding: 26)
            } else {
                overview(saved: totalSaved, target: totalTarget, count: active.count)
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                    ForEach(active) { goal in
                        NavigationLink {
                            GoalDetailView(goal: goal)
                        } label: {
                            GoalCard(goal: goal, saved: saved[goal.id] ?? 0, currency: currency)
                        }
                        .buttonStyle(PressableStyle())
                    }
                    Button { showNewGoal = true } label: {
                        VStack(spacing: 10) {
                            Image(systemName: "plus")
                                .font(.title2.weight(.bold))
                                .foregroundStyle(Palette.blue)
                                .frame(width: 54, height: 54)
                                .background(Palette.paleBlue, in: Circle())
                            Text("New goal").font(.subheadline.weight(.bold)).foregroundStyle(Palette.blue)
                        }
                        .frame(maxWidth: .infinity, minHeight: 196)
                        .background(RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .strokeBorder(Palette.blue.opacity(0.35), style: StrokeStyle(lineWidth: 1.5, dash: [6, 5])))
                    }
                    .buttonStyle(PressableStyle())
                }
            }

            if !archived.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    Button {
                        withAnimation(.snappy) { showArchived.toggle() }
                    } label: {
                        HStack {
                            Text("Archived (\(archived.count))").font(.subheadline.weight(.semibold))
                            Spacer()
                            Image(systemName: "chevron.down").rotationEffect(.degrees(showArchived ? 180 : 0))
                        }
                        .foregroundStyle(Palette.muted)
                    }
                    if showArchived {
                        ForEach(archived) { goal in
                            NavigationLink {
                                GoalDetailView(goal: goal)
                            } label: {
                                HStack(spacing: 12) {
                                    SymbolBadge(symbol: goal.symbol, color: goal.color.main, size: 36,
                                                gradient: goal.color.gradient)
                                    Text(goal.name).font(.subheadline.weight(.semibold)).foregroundStyle(Palette.ink)
                                    Spacer()
                                    Text(Money.short(saved[goal.id] ?? 0, currency: currency))
                                        .font(Typography.money(15, weight: .semibold)).foregroundStyle(Palette.muted)
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .card()
            }
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { showNewGoal = true } label: { Label("New goal", systemImage: "plus.circle.fill") }
            }
        }
        .sheet(isPresented: $showNewGoal) { GoalFormView(goal: nil) }
    }

    private func overview(saved: Int, target: Int, count: Int) -> some View {
        let progress = GoalMath.progress(saved: saved, target: target)
        return HStack(spacing: 18) {
            VStack(alignment: .leading, spacing: 8) {
                Eyebrow(text: "Saved across \(count) \(count == 1 ? "goal" : "goals")")
                Text(Money.short(saved, currency: currency))
                    .font(Typography.money(34, weight: .heavy))
                    .foregroundStyle(.white)
                    .lineLimit(1).minimumScaleFactor(0.5)
                Text("of \(Money.short(target, currency: currency)) · \(Int((progress * 100).rounded()))% there")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Palette.lime)
            }
            Spacer(minLength: 0)
            Image("Coin")
                .resizable()
                .scaledToFit()
                .frame(width: 92, height: 92)
                .rotationEffect(.degrees(-8))
                .shadow(color: Palette.limeDeep.opacity(0.45), radius: 18, y: 8)
        }
        .heroCard()
        .accessibilityElement(children: .combine)
    }
}

struct GoalCard: View {
    let goal: SavingsGoal
    let saved: Int
    let currency: CurrencyCode

    var body: some View {
        let progress = GoalMath.progress(saved: saved, target: goal.targetCents)
        let done = progress >= 1
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                ZStack {
                    RingProgress(value: progress, lineWidth: 8, colors: goal.color.colors, track: Palette.surfaceRaised)
                    Image(systemName: done ? "checkmark" : goal.symbol)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(goal.color.main)
                }
                .frame(width: 64, height: 64)
                Spacer()
                Text("\(Int((min(progress, 9.99) * 100).rounded()))%")
                    .font(Typography.money(15, weight: .heavy))
                    .foregroundStyle(goal.color.main)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(goal.name)
                    .font(.headline).foregroundStyle(Palette.ink)
                    .lineLimit(1)
                Text(Money.short(saved, currency: currency))
                    .font(Typography.money(20, weight: .bold)).foregroundStyle(Palette.ink)
                    .lineLimit(1).minimumScaleFactor(0.6)
                Text("of \(Money.short(goal.targetCents, currency: currency))")
                    .font(.caption).foregroundStyle(Palette.muted)
            }
            Text(caption)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(done ? Palette.green : Palette.muted)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(minHeight: 164, alignment: .top)
        .card(padding: 16)
        .accessibilityElement(children: .combine)
    }

    private var caption: String {
        if saved >= goal.targetCents { return "Goal reached 🎉" }
        if let monthly = GoalMath.monthlyNeeded(saved: saved, target: goal.targetCents, deadline: goal.deadline),
           let deadline = goal.deadline {
            return "\(Money.compact(monthly, currency: currency))/mo · by \(deadline.formatted(.dateTime.month(.abbreviated).year(.twoDigits)))"
        }
        return "No deadline"
    }
}

// MARK: - Goal detail

struct GoalDetailView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var state
    @Bindable var goal: SavingsGoal
    @Query private var allContributions: [GoalContribution]
    @AppStorage("currency") private var currencyRaw = CurrencyCode.usd.rawValue
    @State private var contribution: ContributionKind?
    @State private var editing = false
    @State private var confirmDelete = false

    private var currency: CurrencyCode { CurrencyCode(rawValue: currencyRaw) ?? .usd }

    var body: some View {
        let contributions = allContributions.filter { $0.goalID == goal.id }.sorted { $0.date > $1.date }
        let saved = contributions.reduce(0) { $0 + $1.amountCents }
        let progress = GoalMath.progress(saved: saved, target: goal.targetCents)
        let monthly = GoalMath.monthlyNeeded(saved: saved, target: goal.targetCents, deadline: goal.deadline)
        let finish = GoalMath.projectedFinish(saved: saved, target: goal.targetCents, createdAt: goal.createdAt)

        ScrollView {
            VStack(spacing: 18) {
                VStack(spacing: 18) {
                    ZStack {
                        RingProgress(value: progress, lineWidth: 18, colors: goal.color.colors, track: Palette.heroTrack)
                        VStack(spacing: 4) {
                            Image(systemName: goal.symbol)
                                .font(.system(size: 26, weight: .bold))
                                .foregroundStyle(goal.color.colors[0])
                            Text("\(Int((min(progress, 9.99) * 100).rounded()))%")
                                .font(Typography.money(40, weight: .heavy))
                                .foregroundStyle(.white)
                                .contentTransition(.numericText())
                        }
                    }
                    .frame(width: 190, height: 190)
                    .padding(.top, 6)

                    VStack(spacing: 4) {
                        Text(Money.format(saved, currency: currency))
                            .font(Typography.money(30, weight: .heavy)).foregroundStyle(.white)
                            .contentTransition(.numericText())
                        Text(saved >= goal.targetCents
                             ? "You reached your \(Money.short(goal.targetCents, currency: currency)) goal!"
                             : "\(Money.short(goal.targetCents - saved, currency: currency)) to go of \(Money.short(goal.targetCents, currency: currency))")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Palette.heroText)
                    }

                    HStack(spacing: 12) {
                        Button { contribution = .deposit } label: {
                            Label("Add money", systemImage: "plus")
                        }
                        .buttonStyle(PrimaryButtonStyle(fill: AnyShapeStyle(goal.color.gradient), foreground: .white))
                        Button { contribution = .withdrawal } label: {
                            Label("Withdraw", systemImage: "minus")
                        }
                        .buttonStyle(PrimaryButtonStyle(fill: AnyShapeStyle(Color.white.opacity(0.14)), foreground: .white))
                        .disabled(saved <= 0)
                    }
                }
                .frame(maxWidth: .infinity)
                .heroCard(padding: 24)

                HStack(spacing: 12) {
                    detailTile("Monthly to stay on track",
                               monthly.map { Money.short($0, currency: currency) } ?? "—",
                               symbol: "calendar", tint: goal.color.main)
                    detailTile(goal.deadline == nil ? "Projected finish" : "Deadline",
                               (goal.deadline ?? finish).map { $0.formatted(.dateTime.month(.abbreviated).year()) } ?? "—",
                               symbol: "flag.checkered", tint: goal.color.main)
                }

                VStack(alignment: .leading, spacing: 10) {
                    SectionHeader(title: "History", subtitle: contributions.isEmpty ? "No deposits yet" : nil)
                    ForEach(Array(contributions.enumerated()), id: \.element.id) { index, item in
                        if index > 0 { Divider() }
                        HStack(spacing: 12) {
                            Image(systemName: item.amountCents >= 0 ? "arrow.down.to.line" : "arrow.up.forward")
                                .font(.subheadline.weight(.bold))
                                .foregroundStyle(item.amountCents >= 0 ? Palette.green : Palette.orange)
                                .frame(width: 34, height: 34)
                                .background((item.amountCents >= 0 ? Palette.green : Palette.orange).opacity(0.12), in: Circle())
                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.note.isEmpty ? (item.amountCents >= 0 ? "Deposit" : "Withdrawal") : item.note)
                                    .font(.subheadline.weight(.semibold)).foregroundStyle(Palette.ink)
                                Text(DateText.relativeDay(item.date)).font(.caption).foregroundStyle(Palette.muted)
                            }
                            Spacer()
                            Text((item.amountCents >= 0 ? "+" : "") + Money.format(item.amountCents, currency: currency))
                                .font(Typography.money(15, weight: .bold))
                                .foregroundStyle(item.amountCents >= 0 ? Palette.green : Palette.ink)
                        }
                        .contextMenu {
                            Button(role: .destructive) {
                                context.delete(item)
                                try? context.save()
                            } label: { Label("Delete", systemImage: "trash") }
                        }
                    }
                }
                .card()
            }
            .padding(.horizontal)
            .padding(.bottom, 40)
        }
        .pennyBackground()
        .navigationTitle(goal.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button { editing = true } label: { Label("Edit goal", systemImage: "pencil") }
                    Button {
                        goal.isArchived.toggle()
                        try? context.save()
                        state.show(goal.isArchived ? "Goal archived." : "Goal restored.", symbol: "archivebox.fill")
                    } label: {
                        Label(goal.isArchived ? "Restore" : "Archive", systemImage: "archivebox")
                    }
                    Divider()
                    Button(role: .destructive) { confirmDelete = true } label: { Label("Delete goal", systemImage: "trash") }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .sheet(item: $contribution) { kind in
            ContributionForm(goal: goal, kind: kind, saved: saved)
                .presentationDetents([.medium])
                .presentationCornerRadius(28)
        }
        .sheet(isPresented: $editing) { GoalFormView(goal: goal) }
        .confirmationDialog("Delete \(goal.name)?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Delete goal", role: .destructive) { deleteGoal(contributions) }
        } message: {
            Text("Its history is removed too. Your transactions are not affected.")
        }
    }

    private func detailTile(_ label: String, _ value: String, symbol: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            SymbolBadge(symbol: symbol, color: tint, size: 32)
            Text(label).font(.caption).foregroundStyle(Palette.muted).lineLimit(2)
            Text(value).font(Typography.money(18, weight: .bold)).foregroundStyle(Palette.ink)
                .lineLimit(1).minimumScaleFactor(0.6)
        }
        .card(padding: 14, radius: 20)
        .accessibilityElement(children: .combine)
    }

    private func deleteGoal(_ contributions: [GoalContribution]) {
        contributions.forEach { context.delete($0) }
        let name = goal.name
        context.delete(goal)
        try? context.save()
        state.show("“\(name)” deleted.", symbol: "trash.fill")
        dismiss()
    }
}

enum ContributionKind: String, Identifiable {
    case deposit, withdrawal
    var id: String { rawValue }
}

struct ContributionForm: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Environment(AppState.self) private var state
    @AppStorage("currency") private var currencyRaw = CurrencyCode.usd.rawValue
    @FocusState private var focused: Bool

    let goal: SavingsGoal
    let kind: ContributionKind
    let saved: Int

    @State private var text = ""
    @State private var note = ""
    @State private var error: String?

    private var currency: CurrencyCode { CurrencyCode(rawValue: currencyRaw) ?? .usd }

    var body: some View {
        NavigationStack {
            VStack(spacing: 18) {
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(currency.symbol).font(Typography.money(28, weight: .bold)).foregroundStyle(Palette.muted)
                    TextField("0", text: $text)
                        .keyboardType(.decimalPad)
                        .font(Typography.money(48, weight: .heavy))
                        .fixedSize()
                        .focused($focused)
                        .accessibilityLabel("Amount")
                }
                .padding(.top, 12)
                if let error {
                    Text(error).font(.footnote).foregroundStyle(Palette.red)
                }
                if kind == .deposit && saved < goal.targetCents {
                    Button {
                        text = Money.inputText(goal.targetCents - saved)
                    } label: {
                        Text("Fill the rest · \(Money.format(goal.targetCents - saved, currency: currency))")
                            .font(.footnote.weight(.semibold))
                            .padding(.horizontal, 12).padding(.vertical, 7)
                            .background(Palette.paleBlue, in: Capsule())
                    }
                }
                TextField("Note (optional)", text: $note)
                    .padding(14)
                    .background(Palette.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                Spacer()
            }
            .padding(.horizontal, 24)
            .pennyBackground()
            .navigationTitle(kind == .deposit ? "Add to \(goal.name)" : "Withdraw from \(goal.name)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Save", action: save).fontWeight(.bold) }
            }
            .onAppear { focused = true }
        }
        .lockGuard()
    }

    private func save() {
        guard let cents = Money.parse(text) else {
            error = "Enter an amount from 0.01 to 9,999,999.99."
            Haptics.warning()
            return
        }
        if kind == .withdrawal && cents > saved {
            error = "You can withdraw up to \(Money.format(saved, currency: currency))."
            Haptics.warning()
            return
        }
        let signed = kind == .deposit ? cents : -cents
        context.insert(GoalContribution(goalID: goal.id, amountCents: signed,
                                        note: note.trimmingCharacters(in: .whitespacesAndNewlines)))
        try? context.save()
        let reached = kind == .deposit && saved < goal.targetCents && saved + cents >= goal.targetCents
        dismiss()
        if reached {
            state.celebrate()
            state.show("You reached “\(goal.name)”! 🎉", symbol: "trophy.fill")
        } else {
            Haptics.success()
            state.show(kind == .deposit ? "\(Money.format(cents, currency: currency)) added." : "Withdrawal saved.")
        }
    }
}

// MARK: - Goal form

struct GoalFormView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Environment(AppState.self) private var state
    @AppStorage("currency") private var currencyRaw = CurrencyCode.usd.rawValue

    let goal: SavingsGoal?

    @State private var name = ""
    @State private var targetText = ""
    @State private var symbol = "star.fill"
    @State private var color: GoalColor = .lime
    @State private var hasDeadline = false
    @State private var deadline = Calendar.current.date(byAdding: .month, value: 6, to: Date()) ?? Date()
    @State private var startingText = ""
    @State private var showErrors = false
    @State private var loaded = false

    static let symbols = [
        "star.fill", "airplane", "house.fill", "car.fill", "laptopcomputer", "iphone", "camera.fill",
        "gift.fill", "graduationcap.fill", "heart.fill", "shield.lefthalf.filled", "beach.umbrella.fill",
        "bicycle", "gamecontroller.fill", "music.note", "pawprint.fill", "figure.2.and.child.holdinghands",
        "sparkles", "leaf.fill", "bag.fill", "ring", "tent.fill", "sailboat.fill", "banknote.fill",
    ]

    private var currency: CurrencyCode { CurrencyCode(rawValue: currencyRaw) ?? .usd }
    private var trimmedName: String { name.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var target: Int? { Money.parse(targetText) }
    private var starting: Int? { startingText.isEmpty ? 0 : Money.parse(startingText) }
    private var isValid: Bool { !trimmedName.isEmpty && trimmedName.count <= 40 && target != nil && starting != nil }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        Spacer()
                        ZStack {
                            Circle().fill(color.gradient).frame(width: 92, height: 92)
                                .shadow(color: color.main.opacity(0.4), radius: 14, y: 6)
                            Image(systemName: symbol)
                                .font(.system(size: 38, weight: .bold))
                                .foregroundStyle(.white)
                                .contentTransition(.symbolEffect(.replace))
                        }
                        Spacer()
                    }
                    .listRowBackground(Color.clear)
                }

                Section("Goal") {
                    TextField("Name, e.g. Summer trip", text: $name)
                    HStack {
                        Text(currency.symbol).foregroundStyle(Palette.muted)
                        TextField("Target amount", text: $targetText).keyboardType(.decimalPad)
                    }
                    if goal == nil {
                        HStack {
                            Text(currency.symbol).foregroundStyle(Palette.muted)
                            TextField("Already saved (optional)", text: $startingText).keyboardType(.decimalPad)
                        }
                    }
                    if showErrors && !isValid {
                        Text("Add a name (up to 40 characters) and a target from 0.01 to 9,999,999.99.")
                            .font(.footnote).foregroundStyle(Palette.red)
                    }
                }

                Section("Color") {
                    HStack(spacing: 10) {
                        ForEach(GoalColor.allCases) { option in
                            Button {
                                Haptics.selection()
                                color = option
                            } label: {
                                Circle()
                                    .fill(option.gradient)
                                    .frame(width: 34, height: 34)
                                    .overlay(Circle().strokeBorder(.white, lineWidth: color == option ? 3 : 0))
                                    .overlay(Circle().strokeBorder(option.main, lineWidth: color == option ? 1.5 : 0).padding(-3))
                            }
                            .buttonStyle(.plain)
                            .frame(maxWidth: .infinity)
                            .accessibilityLabel(option.rawValue.capitalized)
                            .accessibilityAddTraits(color == option ? .isSelected : [])
                        }
                    }
                    .padding(.vertical, 4)
                }

                Section("Icon") {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 6), spacing: 10) {
                        ForEach(Self.symbols, id: \.self) { option in
                            Button {
                                Haptics.selection()
                                symbol = option
                            } label: {
                                Image(systemName: option)
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundStyle(symbol == option ? .white : Palette.ink)
                                    .frame(width: 42, height: 42)
                                    .background {
                                        if symbol == option {
                                            Circle().fill(color.gradient)
                                        } else {
                                            Circle().fill(Palette.surfaceRaised)
                                        }
                                    }
                            }
                            .buttonStyle(.plain)
                            .accessibilityAddTraits(symbol == option ? .isSelected : [])
                        }
                    }
                    .padding(.vertical, 4)
                }

                Section {
                    Toggle("Target date", isOn: $hasDeadline.animation())
                    if hasDeadline {
                        DatePicker("By", selection: $deadline, in: Date()..., displayedComponents: .date)
                    }
                } footer: {
                    if hasDeadline, let target {
                        let monthly = GoalMath.monthlyNeeded(saved: starting ?? 0, target: target, deadline: deadline)
                        if let monthly {
                            Text("That’s about \(Money.format(monthly, currency: currency)) a month.")
                        }
                    }
                }
            }
            .navigationTitle(goal == nil ? "New goal" : "Edit goal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Save", action: save).fontWeight(.bold) }
            }
            .onAppear(perform: load)
        }
        .lockGuard()
    }

    private func load() {
        guard !loaded else { return }
        loaded = true
        guard let goal else { return }
        name = goal.name
        targetText = Money.inputText(goal.targetCents)
        symbol = goal.symbol
        color = goal.color
        if let date = goal.deadline {
            hasDeadline = true
            deadline = date
        }
    }

    private func save() {
        guard isValid, let target else {
            showErrors = true
            Haptics.warning()
            return
        }
        if let goal {
            goal.name = trimmedName
            goal.targetCents = target
            goal.symbol = symbol
            goal.color = color
            goal.deadline = hasDeadline ? deadline : nil
            goal.isSample = false
            state.show("Goal updated.")
        } else {
            let newGoal = SavingsGoal(name: trimmedName, targetCents: target, symbol: symbol, color: color,
                                      deadline: hasDeadline ? deadline : nil)
            context.insert(newGoal)
            if let starting, starting > 0 {
                context.insert(GoalContribution(goalID: newGoal.id, amountCents: starting, note: "Starting balance"))
            }
            state.show("“\(trimmedName)” created. You’ve got this!", symbol: "flag.fill")
        }
        try? context.save()
        Haptics.success()
        dismiss()
    }
}
