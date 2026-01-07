//
//  EventType.swift
//  Dad App
//
//  Created by Ash Beech on 06/03/2025.
//

import Foundation
import SwiftUI

enum EventType: String, Codable {
    case goal = "Goal"
    case feed = "Feed"
    case sleep = "Sleep"
    case task = "Task"
    
    var color: Color {
        switch self {
        case .goal:
            return .orange
        case .feed:
            return .blue
        case .sleep:
            return .purple
        case .task:
            return .green
        }
    }
}
