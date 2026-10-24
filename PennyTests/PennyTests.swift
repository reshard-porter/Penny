import Foundation
import Testing
@testable import Penny

struct MoneyTests {
    @Test func parsesExactCents() {
        #expect(Money.parse("0.29") == 29)
        #expect(Money.parse(".50") == 50)
        #expect(Money.parse("12") == 1_200)
        #expect(Money.parse("1,234.56") == 123_456)
        #expect(Money.parse("12,5") == 1_250)   // decimal-comma keypads
        #expect(Money.parse("1,2") == 120)
        #expect(Money.parse("9999999.99") == Money.maxCents)
    }

    @Test(arguments: ["1.234", "-1", "0", "", "10000000", "NaN", "12..3", "1,23,456"])
    func rejectsAmbiguousInput(_ input: String) {
        #expect(Money.parse(input) == nil)
    }

    @Test func zeroOnlyWhereAllowed() {
        #expect(Money.parse("0") == nil)
        #expect(Money.parse("0", allowZero: true) == 0)
    }

    @Test func formatsCurrencies() {
        #expect(Money.format(123_456, currency: .jmd) == "J$1,234.56")
        #expect(Money.format(5, currency: .usd) == "$0.05")
        #expect(Money.format(-1_000_000, currency: .gbp) == "−£10,000.00")
        #expect(Money.inputText(1_234) == "12.34")
        #expect(Money.inputText(1_205) == "12.05")
    }
}

struct RecurrenceTests {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Jamaica") ?? .current
        return calendar
    }

    private func day(_ year: Int, _ month: Int, _ day: Int) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: 12)) ?? Date()
    }

    @Test func monthlyScheduleDoesNotDrift() {
        let start = day(2026, 1, 31)
        let schedule = (0..<3).map { RepeatFrequency.monthly.date(occurrence: $0, from: start, calendar: calendar) }
        #expect(calendar.component(.day, from: schedule[1]) == 28) // February
        #expect(calendar.component(.day, from: schedule[2]) == 31) // back to March 31
    }

    @Test func weeklyAndYearly() {
        let start = day(2026, 10, 18)
        #expect(RepeatFrequency.weekly.date(occurrence: 2, from: start, calendar: calendar) == day(2026, 11, 1))
        #expect(RepeatFrequency.yearly.date(occurrence: 1, from: start, calendar: calendar) == day(2027, 10, 18))
    }
}

struct BudgetTests {
    @Test func limitsCarryForwardUntilChanged() {
        let records = [
            BudgetResolver.Record(monthKey: "2026-08", category: .groceries, cents: 40_000),
            BudgetResolver.Record(monthKey: "2026-10", category: .groceries, cents: 30_000),
        ]
        #expect(BudgetResolver.limits(forMonthKey: "2026-07", records: records)[.groceries] == 55_000)
        #expect(BudgetResolver.limits(forMonthKey: "2026-09", records: records)[.groceries] == 40_000)
        #expect(BudgetResolver.limits(forMonthKey: "2026-12", records: records)[.groceries] == 30_000)
        #expect(BudgetResolver.limits(forMonthKey: "2026-12", records: records)[.dining] == 20_000)
    }
}

struct CSVTests {
    @Test func neutralizesFormulasAndEscapesQuotes() {
        #expect(CSVExport.cell("=SUM(1,2)") == "\"'=SUM(1,2)\"")
        #expect(CSVExport.cell("A \"quoted\" note") == "\"A \"\"quoted\"\" note\"")
        #expect(CSVExport.cell("Groceries") == "\"Groceries\"")
    }
}

struct MoneyFormattingTests {
    @Test func shortAndCompact() {
        #expect(Money.short(120_000, currency: .usd) == "$1,200")
        #expect(Money.short(1_250, currency: .usd) == "$12.50")
        #expect(Money.compact(95_000, currency: .usd) == "$950")
        #expect(Money.compact(123_456, currency: .usd) == "$1.2k")
        #expect(Money.compact(340_000_000, currency: .eur) == "€3.4M")
        #expect(Money.signed(500, kind: .income, currency: .usd) == "+$5.00")
        #expect(Money.signed(500, kind: .expense, currency: .usd) == "−$5.00")
    }

    @Test func decimalAmountsFromSiri() {
        #expect(Money.cents(fromDecimal: 12.34) == 1_234)
        #expect(Money.cents(fromDecimal: 0.1 + 0.2) == 30)
        #expect(Money.cents(fromDecimal: 0) == nil)
        #expect(Money.cents(fromDecimal: -5) == nil)
        #expect(Money.cents(fromDecimal: .infinity) == nil)
    }
}

struct CategoryTests {
    @Test func categoriesStayConsistentWithKind() {
        #expect(LedgerCategory.normalized(.groceries, for: .income) == .income)
        #expect(LedgerCategory.normalized(.business, for: .expense) == .other)
        #expect(LedgerCategory.normalized(.business, for: .income) == .business)
        #expect(LedgerCategory.expenseCases.allSatisfy { !$0.isIncome })
        #expect(Set(LedgerCategory.expenseCases).isDisjoint(with: LedgerCategory.incomeCases))
        #expect(LedgerCategory.allCases.count == LedgerCategory.expenseCases.count + LedgerCategory.incomeCases.count)
    }

    @Test func legacyIncomeRawValueStillReadsAsSalary() {
        #expect(LedgerCategory(rawValue: "income") == .income)
        #expect(LedgerCategory.income.label == "Salary")
    }
}

struct FrequencyTests {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Jamaica") ?? .current
        return calendar
    }

    @Test func biweeklyAndQuarterly() {
        let start = calendar.date(from: DateComponents(year: 2026, month: 1, day: 31, hour: 12)) ?? Date()
        let biweekly = RepeatFrequency.biweekly.date(occurrence: 2, from: start, calendar: calendar)
        #expect(calendar.component(.month, from: biweekly) == 2)
        #expect(calendar.component(.day, from: biweekly) == 28)
        let quarterly = RepeatFrequency.quarterly.date(occurrence: 1, from: start, calendar: calendar)
        #expect(calendar.component(.month, from: quarterly) == 4)
        #expect(calendar.component(.day, from: quarterly) == 30)
    }

    @Test func monthlyEquivalents() {
        let rule = RecurringRule(title: "Gym", amountCents: 1_000, kind: .expense, category: .health,
                                 note: "", frequency: .weekly, startDate: Date())
        #expect(rule.monthlyCents == 4_333)
        #expect(abs(RepeatFrequency.yearly.perMonth * 12 - 1) < 0.000_001)
    }
}

struct BudgetRemovalTests {
    @Test func negativeRecordRemovesBudgetFromThatMonthOn() {
        let records = [
            BudgetResolver.Record(monthKey: "2026-05", category: .dining, cents: 30_000),
            BudgetResolver.Record(monthKey: "2026-08", category: .dining, cents: -1),
        ]
        #expect(BudgetResolver.limits(forMonthKey: "2026-07", records: records)[.dining] == 30_000)
        #expect(BudgetResolver.limits(forMonthKey: "2026-08", records: records)[.dining] == nil)
        #expect(BudgetResolver.limits(forMonthKey: "2027-01", records: records)[.dining] == nil)
    }
}

struct SummaryTests {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Jamaica") ?? .current
        return calendar
    }

    private func day(_ value: Int) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 9, day: value, hour: 12)) ?? Date()
    }

    @Test func totalsAndDailySeries() {
        let entries = [
            LedgerEntry(title: "Pay", amountCents: 100_000, kind: .income, category: .income, date: day(1)),
            LedgerEntry(title: "Food", amountCents: 2_000, kind: .expense, category: .groceries, date: day(1)),
            LedgerEntry(title: "Food", amountCents: 3_000, kind: .expense, category: .groceries, date: day(3)),
            LedgerEntry(title: "Bus", amountCents: 500, kind: .expense, category: .transport, date: day(3)),
            LedgerEntry(title: "Old", amountCents: 9_999, kind: .expense, category: .other,
                        date: calendar.date(byAdding: .month, value: -1, to: day(3)) ?? Date()),
        ]
        let summary = MonthSummary(month: day(15), allEntries: entries, budgets: [], calendar: calendar)
        #expect(summary.income == 100_000)
        #expect(summary.expenses == 5_500)
        #expect(summary.net == 94_500)
        #expect(summary.spent(.groceries) == 5_000)
        #expect(summary.dailySpending.count == 30)
        #expect(summary.dailySpending[0] == 2_000)
        #expect(summary.dailySpending[2] == 3_500)
        #expect(summary.cumulativeSpending.last == 5_500)
        #expect(summary.rankedCategories == [.groceries, .transport])
        #expect(summary.savingsRate.map { ($0 * 1000).rounded() } == 945)
    }
}

struct GoalMathTests {
    private var calendar: Calendar { Calendar(identifier: .gregorian) }

    @Test func savedAndProgress() {
        let id = UUID()
        let other = UUID()
        let contributions = [
            GoalContribution(goalID: id, amountCents: 10_000),
            GoalContribution(goalID: id, amountCents: -2_500),
            GoalContribution(goalID: other, amountCents: 1_000),
        ]
        let saved = GoalMath.saved(contributions)
        #expect(saved[id] == 7_500)
        #expect(saved[other] == 1_000)
        #expect(GoalMath.progress(saved: 7_500, target: 10_000) == 0.75)
        #expect(GoalMath.progress(saved: 1, target: 0) == 0)
    }

    @Test func monthlyNeededCountsThisMonth() {
        let now = calendar.date(from: DateComponents(year: 2026, month: 10, day: 24)) ?? Date()
        let deadline = calendar.date(from: DateComponents(year: 2027, month: 1, day: 15)) ?? Date()
        // Oct, Nov, Dec, Jan = 4 months for 1,000.00 remaining
        #expect(GoalMath.monthlyNeeded(saved: 0, target: 100_000, deadline: deadline, now: now, calendar: calendar) == 25_000)
        #expect(GoalMath.monthlyNeeded(saved: 100_000, target: 100_000, deadline: deadline, now: now, calendar: calendar) == nil)
        #expect(GoalMath.monthlyNeeded(saved: 0, target: 100_000, deadline: nil, now: now, calendar: calendar) == nil)
    }
}

struct InsightsMathTests {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.firstWeekday = 1
        return calendar
    }

    @Test func merchantsRankedBySpend() {
        let now = Date()
        let entries = [
            LedgerEntry(title: "Fresh Market", amountCents: 3_000, kind: .expense, category: .groceries, date: now),
            LedgerEntry(title: "fresh market", amountCents: 2_000, kind: .expense, category: .groceries, date: now),
            LedgerEntry(title: "Cinema", amountCents: 4_000, kind: .expense, category: .leisure, date: now),
            LedgerEntry(title: "Salary", amountCents: 90_000, kind: .income, category: .income, date: now),
        ]
        let top = InsightsMath.topMerchants(entries)
        #expect(top.count == 2)
        #expect(top[0].cents == 5_000)
        #expect(top[0].count == 2)
        #expect(top[1].title == "Cinema")
    }

    @Test func weekdayAveragesCoverEveryDay() {
        // 2026-10-04 is a Sunday.
        let sunday = calendar.date(from: DateComponents(year: 2026, month: 10, day: 4, hour: 12)) ?? Date()
        let entries = [LedgerEntry(title: "Brunch", amountCents: 7_000, kind: .expense, category: .dining, date: sunday)]
        let end = calendar.date(byAdding: .day, value: 13, to: sunday) ?? sunday // two full weeks
        let values = InsightsMath.weekdayAverages(entries, endingAt: end, days: 14, calendar: calendar)
        #expect(values.count == 7)
        #expect(values[0].weekday == 1)
        #expect(values[0].averageCents == 3_500)
        #expect(values.dropFirst().allSatisfy { $0.averageCents == 0 })
    }

    @Test func percentChange() {
        #expect(InsightsMath.change(from: 10_000, to: 8_000) == -20)
        #expect(InsightsMath.change(from: 0, to: 8_000) == nil)
    }
}
