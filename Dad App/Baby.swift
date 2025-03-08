//
//  Baby.swift
//  Dad App
//
//  Created by Ashley Davison on 06/03/2025.
//

import Foundation

struct Baby: Codable {
    var name: String
    var feedTemplates: [FeedEvent]
    var sleepTemplates: [SleepEvent]
    var wakeTime: Date
    var bedTime: Date
    
    init(name: String, feedTemplates: [FeedEvent] = [], sleepTemplates: [SleepEvent] = [], wakeTime: Date = Calendar.current.date(from: DateComponents(hour: 7, minute: 0))!, bedTime: Date = Calendar.current.date(from: DateComponents(hour: 19, minute: 0))!) {
        self.name = name
        self.feedTemplates = feedTemplates
        self.sleepTemplates = sleepTemplates
        self.wakeTime = wakeTime
        self.bedTime = bedTime
    }
}
