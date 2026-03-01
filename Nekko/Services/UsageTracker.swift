//
//  UsageTracker.swift
//  Nekko
//
//  Created by 湯川昇平 on 2026/02/28.
//

import Foundation

@Observable
final class UsageTracker {
    static let shared = UsageTracker()

    static let monthlyLimitSeconds: TimeInterval = 36_000  // 600 minutes

    private let defaults = UserDefaults.standard
    private let usageKey = "nekko_monthly_usage_seconds"
    private let monthKey = "nekko_usage_month"

    private(set) var usedSecondsThisMonth: TimeInterval = 0

    var usedMinutesThisMonth: Int {
        Int(usedSecondsThisMonth / 60)
    }

    var remainingMinutes: Int {
        max(0, 600 - usedMinutesThisMonth)
    }

    var usageRatio: Double {
        min(1.0, usedSecondsThisMonth / Self.monthlyLimitSeconds)
    }

    var isLimitReached: Bool {
        usedSecondsThisMonth >= Self.monthlyLimitSeconds
    }

    private init() {
        resetIfNewMonth()
        usedSecondsThisMonth = defaults.double(forKey: usageKey)
    }

    func addUsage(seconds: TimeInterval) {
        resetIfNewMonth()
        usedSecondsThisMonth += seconds
        defaults.set(usedSecondsThisMonth, forKey: usageKey)
    }

    private func resetIfNewMonth() {
        let currentMonth = Self.currentMonthString()
        let storedMonth = defaults.string(forKey: monthKey)

        if storedMonth != currentMonth {
            defaults.set(0.0, forKey: usageKey)
            defaults.set(currentMonth, forKey: monthKey)
            usedSecondsThisMonth = 0
        }
    }

    private static func currentMonthString() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM"
        return formatter.string(from: Date())
    }
}
