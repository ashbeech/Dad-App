//
//  UserExecutionProfile.swift
//  Dad App
//
//  Phase 3: Computed behavioral metrics from task observations
//

import Foundation

// MARK: - Time Block Stats

struct TimeBlockStats: Codable {
    let timeBlock: TimeBlock
    let completionCount: Int
    let totalCount: Int
    let completionRate: Double      // 0.0 - 1.0
    let weightedCompletionRate: Double  // Recent observations weighted higher
}

// MARK: - Day Stats

struct DayStats: Codable {
    let dayOfWeek: Int              // 1 = Sunday, 7 = Saturday
    let completionCount: Int
    let totalCount: Int
    let completionRate: Double
    let weightedCompletionRate: Double
    
    var dayName: String {
        let days = ["", "Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]
        return days[dayOfWeek]
    }
}

// MARK: - User Execution Profile

struct UserExecutionProfile: Codable {
    // Overall metrics
    let overallCompletionRate: Double           // 0.0 - 1.0
    let weightedCompletionRate: Double          // Recent weighted higher
    let averageDurationMultiplier: Double       // actual/estimated (1.0 = accurate, 1.5 = takes 50% longer)
    
    // Time-based patterns
    let timeBlockStats: [TimeBlockStats]
    let bestTimeBlock: TimeBlock?
    let worstTimeBlock: TimeBlock?
    
    // Day-based patterns
    let dayStats: [DayStats]
    let mostProductiveDay: Int?                 // 1-7
    let leastProductiveDay: Int?                // 1-7
    
    // Task size patterns
    let preferredTaskDuration: Int?             // minutes - what they actually complete
    let averageCompletedTaskDuration: Int?
    let completionRateByDuration: [String: Double]  // "short" (<30), "medium" (30-60), "long" (>60)
    
    // Behavior patterns
    let rescheduleRate: Double                  // How often tasks get rescheduled
    let editRate: Double                        // How often task titles/durations get edited
    let skipRate: Double                        // How often tasks get skipped
    let onTimeCompletionRate: Double            // Completed on scheduled day
    
    // Meta
    let observationCount: Int
    let completionCount: Int
    let dateRange: DateInterval?
    let lastUpdated: Date
    
    // MARK: - Initialization
    
    init(
        overallCompletionRate: Double = 0,
        weightedCompletionRate: Double = 0,
        averageDurationMultiplier: Double = 1.0,
        timeBlockStats: [TimeBlockStats] = [],
        bestTimeBlock: TimeBlock? = nil,
        worstTimeBlock: TimeBlock? = nil,
        dayStats: [DayStats] = [],
        mostProductiveDay: Int? = nil,
        leastProductiveDay: Int? = nil,
        preferredTaskDuration: Int? = nil,
        averageCompletedTaskDuration: Int? = nil,
        completionRateByDuration: [String: Double] = [:],
        rescheduleRate: Double = 0,
        editRate: Double = 0,
        skipRate: Double = 0,
        onTimeCompletionRate: Double = 0,
        observationCount: Int = 0,
        completionCount: Int = 0,
        dateRange: DateInterval? = nil,
        lastUpdated: Date = Date()
    ) {
        self.overallCompletionRate = overallCompletionRate
        self.weightedCompletionRate = weightedCompletionRate
        self.averageDurationMultiplier = averageDurationMultiplier
        self.timeBlockStats = timeBlockStats
        self.bestTimeBlock = bestTimeBlock
        self.worstTimeBlock = worstTimeBlock
        self.dayStats = dayStats
        self.mostProductiveDay = mostProductiveDay
        self.leastProductiveDay = leastProductiveDay
        self.preferredTaskDuration = preferredTaskDuration
        self.averageCompletedTaskDuration = averageCompletedTaskDuration
        self.completionRateByDuration = completionRateByDuration
        self.rescheduleRate = rescheduleRate
        self.editRate = editRate
        self.skipRate = skipRate
        self.onTimeCompletionRate = onTimeCompletionRate
        self.observationCount = observationCount
        self.completionCount = completionCount
        self.dateRange = dateRange
        self.lastUpdated = lastUpdated
    }
    
    /// Empty profile for new users
    static var empty: UserExecutionProfile {
        UserExecutionProfile()
    }
    
    /// Whether we have enough data for meaningful insights
    var hasEnoughData: Bool {
        observationCount >= 10
    }
    
    // MARK: - Calculate from Observations
    
    /// Build a profile from a list of observations
    static func calculate(from observations: [TaskObservation]) -> UserExecutionProfile {
        guard !observations.isEmpty else { return .empty }
        
        let completions = observations.filter { $0.eventType == .completed }
        let reschedules = observations.filter { $0.eventType == .rescheduled }
        let edits = observations.filter { $0.eventType == .edited }
        let skips = observations.filter { $0.eventType == .skipped }
        
        // Count unique tasks that were assigned (completed + skipped gives us total assigned)
        let uniqueTaskIds = Set(observations.map { $0.taskId })
        let totalTasks = uniqueTaskIds.count
        
        // Overall completion rate
        let completedTaskIds = Set(completions.map { $0.taskId })
        let overallCompletionRate = totalTasks > 0 ? Double(completedTaskIds.count) / Double(totalTasks) : 0
        
        // Weighted completion rate (recent observations matter more)
        let weightedCompletionRate = calculateWeightedCompletionRate(observations: observations)
        
        // Duration multiplier (actual vs estimated)
        let durationMultiplier = calculateDurationMultiplier(completions: completions)
        
        // Time block stats
        let timeBlockStats = calculateTimeBlockStats(observations: observations)
        let bestTimeBlock = timeBlockStats.max(by: { $0.weightedCompletionRate < $1.weightedCompletionRate })?.timeBlock
        let worstTimeBlock = timeBlockStats.min(by: { $0.weightedCompletionRate < $1.weightedCompletionRate })?.timeBlock
        
        // Day stats
        let dayStats = calculateDayStats(observations: observations)
        let mostProductiveDay = dayStats.max(by: { $0.weightedCompletionRate < $1.weightedCompletionRate })?.dayOfWeek
        let leastProductiveDay = dayStats.min(by: { $0.weightedCompletionRate < $1.weightedCompletionRate })?.dayOfWeek
        
        // Task duration patterns
        let (preferredDuration, avgCompletedDuration) = calculateDurationPatterns(completions: completions)
        let completionByDuration = calculateCompletionByDuration(observations: observations)
        
        // Behavior rates
        let rescheduleRate = totalTasks > 0 ? Double(reschedules.count) / Double(totalTasks) : 0
        let editRate = totalTasks > 0 ? Double(edits.count) / Double(totalTasks) : 0
        let skipRate = totalTasks > 0 ? Double(skips.count) / Double(totalTasks) : 0
        
        // On-time completion rate
        let onTimeCompletions = completions.filter { $0.wasOnTime == true }.count
        let onTimeRate = completions.count > 0 ? Double(onTimeCompletions) / Double(completions.count) : 0
        
        // Date range
        let sortedByDate = observations.sorted { $0.timestamp < $1.timestamp }
        let dateRange: DateInterval? = {
            if let first = sortedByDate.first, let last = sortedByDate.last {
                return DateInterval(start: first.timestamp, end: last.timestamp)
            }
            return nil
        }()
        
        return UserExecutionProfile(
            overallCompletionRate: overallCompletionRate,
            weightedCompletionRate: weightedCompletionRate,
            averageDurationMultiplier: durationMultiplier,
            timeBlockStats: timeBlockStats,
            bestTimeBlock: bestTimeBlock,
            worstTimeBlock: worstTimeBlock,
            dayStats: dayStats,
            mostProductiveDay: mostProductiveDay,
            leastProductiveDay: leastProductiveDay,
            preferredTaskDuration: preferredDuration,
            averageCompletedTaskDuration: avgCompletedDuration,
            completionRateByDuration: completionByDuration,
            rescheduleRate: rescheduleRate,
            editRate: editRate,
            skipRate: skipRate,
            onTimeCompletionRate: onTimeRate,
            observationCount: observations.count,
            completionCount: completions.count,
            dateRange: dateRange,
            lastUpdated: Date()
        )
    }
    
    // MARK: - Private Calculation Helpers
    
    private static func calculateWeightedCompletionRate(observations: [TaskObservation]) -> Double {
        let completions = observations.filter { $0.eventType == .completed }
        let skips = observations.filter { $0.eventType == .skipped }
        
        // Only consider completed and skipped for completion rate
        let relevantObs = completions + skips
        guard !relevantObs.isEmpty else { return 0 }
        
        var weightedCompleted = 0.0
        var totalWeight = 0.0
        
        for obs in relevantObs {
            let weight = obs.weight(halfLifeDays: 30)
            totalWeight += weight
            if obs.eventType == .completed {
                weightedCompleted += weight
            }
        }
        
        return totalWeight > 0 ? weightedCompleted / totalWeight : 0
    }
    
    private static func calculateDurationMultiplier(completions: [TaskObservation]) -> Double {
        let withDurations = completions.filter { 
            $0.estimatedMinutes != nil && $0.actualMinutes != nil &&
            $0.estimatedMinutes! > 0 && $0.actualMinutes! > 0
        }
        
        guard !withDurations.isEmpty else { return 1.0 }
        
        var totalWeightedMultiplier = 0.0
        var totalWeight = 0.0
        
        for obs in withDurations {
            let multiplier = Double(obs.actualMinutes!) / Double(obs.estimatedMinutes!)
            let weight = obs.weight(halfLifeDays: 30)
            totalWeightedMultiplier += multiplier * weight
            totalWeight += weight
        }
        
        return totalWeight > 0 ? totalWeightedMultiplier / totalWeight : 1.0
    }
    
    private static func calculateTimeBlockStats(observations: [TaskObservation]) -> [TimeBlockStats] {
        var stats: [TimeBlock: (completed: Double, total: Double, weightedCompleted: Double, weightedTotal: Double)] = [:]
        
        // Initialize all time blocks
        for block in TimeBlock.allCases {
            stats[block] = (0, 0, 0, 0)
        }
        
        // Count completions and totals by time block
        let relevantObs = observations.filter { $0.eventType == .completed || $0.eventType == .skipped }
        
        for obs in relevantObs {
            guard let block = obs.timeBlock else { continue }
            var current = stats[block]!
            let weight = obs.weight(halfLifeDays: 30)
            
            current.total += 1
            current.weightedTotal += weight
            
            if obs.eventType == .completed {
                current.completed += 1
                current.weightedCompleted += weight
            }
            
            stats[block] = current
        }
        
        return TimeBlock.allCases.compactMap { block in
            guard let data = stats[block], data.total > 0 else { return nil }
            return TimeBlockStats(
                timeBlock: block,
                completionCount: Int(data.completed),
                totalCount: Int(data.total),
                completionRate: data.completed / data.total,
                weightedCompletionRate: data.weightedTotal > 0 ? data.weightedCompleted / data.weightedTotal : 0
            )
        }
    }
    
    private static func calculateDayStats(observations: [TaskObservation]) -> [DayStats] {
        var stats: [Int: (completed: Double, total: Double, weightedCompleted: Double, weightedTotal: Double)] = [:]
        
        // Initialize all days
        for day in 1...7 {
            stats[day] = (0, 0, 0, 0)
        }
        
        let relevantObs = observations.filter { $0.eventType == .completed || $0.eventType == .skipped }
        
        for obs in relevantObs {
            let day = obs.dayOfWeek
            var current = stats[day]!
            let weight = obs.weight(halfLifeDays: 30)
            
            current.total += 1
            current.weightedTotal += weight
            
            if obs.eventType == .completed {
                current.completed += 1
                current.weightedCompleted += weight
            }
            
            stats[day] = current
        }
        
        return (1...7).compactMap { day in
            guard let data = stats[day], data.total > 0 else { return nil }
            return DayStats(
                dayOfWeek: day,
                completionCount: Int(data.completed),
                totalCount: Int(data.total),
                completionRate: data.completed / data.total,
                weightedCompletionRate: data.weightedTotal > 0 ? data.weightedCompleted / data.weightedTotal : 0
            )
        }
    }
    
    private static func calculateDurationPatterns(completions: [TaskObservation]) -> (preferred: Int?, average: Int?) {
        let durations = completions.compactMap { $0.estimatedMinutes }
        guard !durations.isEmpty else { return (nil, nil) }
        
        // Find most common duration (mode)
        var durationCounts: [Int: Int] = [:]
        for d in durations {
            durationCounts[d, default: 0] += 1
        }
        let preferred = durationCounts.max(by: { $0.value < $1.value })?.key
        
        // Calculate average
        let average = durations.reduce(0, +) / durations.count
        
        return (preferred, average)
    }
    
    private static func calculateCompletionByDuration(observations: [TaskObservation]) -> [String: Double] {
        var categories: [String: (completed: Int, total: Int)] = [
            "short": (0, 0),    // < 30 min
            "medium": (0, 0),  // 30-60 min
            "long": (0, 0)     // > 60 min
        ]
        
        let relevantObs = observations.filter { 
            ($0.eventType == .completed || $0.eventType == .skipped) && $0.estimatedMinutes != nil
        }
        
        for obs in relevantObs {
            guard let mins = obs.estimatedMinutes else { continue }
            
            let category: String
            if mins < 30 {
                category = "short"
            } else if mins <= 60 {
                category = "medium"
            } else {
                category = "long"
            }
            
            categories[category]!.total += 1
            if obs.eventType == .completed {
                categories[category]!.completed += 1
            }
        }
        
        var result: [String: Double] = [:]
        for (category, data) in categories {
            if data.total > 0 {
                result[category] = Double(data.completed) / Double(data.total)
            }
        }
        
        return result
    }
    
    // MARK: - Summary for AI Prompt
    
    /// Generate a text summary suitable for including in AI prompts
    func toPromptSummary() -> String? {
        guard hasEnoughData else { return nil }
        
        var lines: [String] = ["User behavioral patterns (last \(observationCount) observations):"]
        
        // Completion rate
        let pct = Int(weightedCompletionRate * 100)
        lines.append("- Overall completion rate: \(pct)%")
        
        // Duration accuracy
        if averageDurationMultiplier != 1.0 {
            let multiplierPct = Int((averageDurationMultiplier - 1.0) * 100)
            if multiplierPct > 10 {
                lines.append("- Tasks typically take \(multiplierPct)% longer than estimated")
            } else if multiplierPct < -10 {
                lines.append("- Tasks typically take \(abs(multiplierPct))% less time than estimated")
            }
        }
        
        // Best/worst time
        if let best = bestTimeBlock {
            if let bestStats = timeBlockStats.first(where: { $0.timeBlock == best }) {
                lines.append("- Best time: \(best.displayName) (\(Int(bestStats.weightedCompletionRate * 100))% completion)")
            }
        }
        if let worst = worstTimeBlock, worst != bestTimeBlock {
            if let worstStats = timeBlockStats.first(where: { $0.timeBlock == worst }) {
                lines.append("- Challenging time: \(worst.displayName) (\(Int(worstStats.weightedCompletionRate * 100))% completion)")
            }
        }
        
        // Best/worst day
        if let bestDay = mostProductiveDay {
            let dayNames = ["", "Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]
            lines.append("- Most productive day: \(dayNames[bestDay])")
        }
        if let worstDay = leastProductiveDay, worstDay != mostProductiveDay {
            let dayNames = ["", "Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]
            lines.append("- Least productive day: \(dayNames[worstDay])")
        }
        
        // Task size preference
        if let shortRate = completionRateByDuration["short"],
           let longRate = completionRateByDuration["long"],
           shortRate > longRate + 0.2 {
            lines.append("- Prefers shorter tasks (higher completion rate for tasks < 30 min)")
        }
        
        // On-time rate
        if onTimeCompletionRate < 0.6 {
            lines.append("- Often completes tasks later than scheduled (\(Int(onTimeCompletionRate * 100))% on-time)")
        }
        
        return lines.joined(separator: "\n")
    }
}

