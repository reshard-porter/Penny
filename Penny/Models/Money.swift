import Foundation

/// All amounts are whole cents (Int) so totals never suffer floating-point rounding.
enum Money {
    static let maxCents = 999_999_999

    /// Parses user input such as "12", "12.5", ".50", "1,234.56" (or "12,50" with a
    /// decimal comma) into cents. Returns nil for anything ambiguous or out of range.
    static func parse(_ input: String, allowZero: Bool = false) -> Int? {
        var value = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return nil }

        // Locales whose keypad shows "," as the decimal separator: "12,5" or "12,50".
        if !value.contains("."),
           value.range(of: #"^\d{1,7},\d{1,2}$"#, options: .regularExpression) != nil {
            value = value.replacingOccurrences(of: ",", with: ".")
        }

        let pattern = #"^(?:\d{1,7}|\d{1,3}(?:,\d{3})+)?(?:\.\d{1,2})?$"#
        guard value.range(of: pattern, options: .regularExpression) != nil else { return nil }

        let parts = value.replacingOccurrences(of: ",", with: "")
            .split(separator: ".", omittingEmptySubsequences: false)
        let wholeText = parts.first.map(String.init) ?? ""
        guard let whole = Int(wholeText.isEmpty ? "0" : wholeText) else { return nil }
        var fraction = parts.count > 1 ? String(parts[1]) : "00"
        while fraction.count < 2 { fraction += "0" }
        guard let fractionValue = Int(fraction) else { return nil }

        let (product, overflow) = whole.multipliedReportingOverflow(by: 100)
        guard !overflow else { return nil }
        let cents = product + fractionValue
        if cents > maxCents || cents < (allowZero ? 0 : 1) { return nil }
        return cents
    }

    /// "J$1,234.56", "−$12.00" (true minus sign for negatives).
    static func format(_ cents: Int, currency: CurrencyCode) -> String {
        let absolute = cents.magnitude
        let whole = grouped(absolute / 100)
        let fraction = absolute % 100
        let fractionText = fraction < 10 ? "0\(fraction)" : "\(fraction)"
        return "\(cents < 0 ? "−" : "")\(currency.symbol)\(whole).\(fractionText)"
    }

    /// Plain editable form, e.g. 1234 -> "12.34".
    static func inputText(_ cents: Int) -> String {
        let fraction = cents % 100
        return "\(cents / 100).\(fraction < 10 ? "0" : "")\(fraction)"
    }

    private static func grouped(_ value: UInt) -> String {
        let digits = Array(String(value))
        var result = ""
        for (index, digit) in digits.enumerated() {
            if index > 0 && (digits.count - index) % 3 == 0 { result.append(",") }
            result.append(digit)
        }
        return result
    }
}
