//
//  FeedEvent.swift
//  Dad App
//
//  Created by Ash Beech on 06/03/2025.
//

import Foundation

struct FeedEvent: Identifiable, Codable {
    var id: UUID
    var date: Date
    var notes: String
    var isTemplate: Bool
    var amount: Double // in milliliters
    var breastMilkPercentage: Double // 0-100
    var formulaPercentage: Double // 0-100
    var preparationTime: Date
    
    init(id: UUID = UUID(), date: Date, amount: Double, breastMilkPercentage: Double, formulaPercentage: Double, preparationTime: Date, notes: String = "", isTemplate: Bool = false) {
        self.id = id
        self.date = date
        self.notes = notes
        self.isTemplate = isTemplate
        self.amount = amount
        self.breastMilkPercentage = breastMilkPercentage
        self.formulaPercentage = formulaPercentage
        self.preparationTime = preparationTime
    }
    
    func toEvent() -> Event {
        return Event(id: id, type: .feed, date: date, notes: notes, isTemplate: isTemplate)
    }
    
    static func fromEvent(_ event: Event, amount: Double = 180, breastMilkPercentage: Double = 0, formulaPercentage: Double = 100, preparationTime: Date? = nil) -> FeedEvent {
        let prepTime = preparationTime ?? event.date.addingTimeInterval(-3600)
        return FeedEvent(id: event.id, date: event.date, amount: amount, breastMilkPercentage: breastMilkPercentage, formulaPercentage: formulaPercentage, preparationTime: prepTime, notes: event.notes, isTemplate: event.isTemplate)
    }
}
