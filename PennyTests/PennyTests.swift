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
