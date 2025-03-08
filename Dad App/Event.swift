//
//  Event.swift
//  Dad App
//
//  Created by Ashley Davison on 06/03/2025.
//

import Foundation

struct Event: Identifiable, Codable {
    var id: UUID
    var type: EventType
    var date: Date
    var notes: String
    var isTemplate: Bool
    
    init(id: UUID = UUID(), type: EventType, date: Date, notes: String = "", isTemplate: Bool = false) {
        self.id = id
        self.type = type
        self.date = date
        self.notes = notes
        self.isTemplate = isTemplate
    }
}
