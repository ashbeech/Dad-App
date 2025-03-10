//
//  EventType.swift
//  Dad App
//
//  Created by Ashley Davison on 06/03/2025.
//

import Foundation
import SwiftUI

enum EventType: String, Codable {
    case feed = "Feed"
    case sleep = "Sleep"
    case task = "Task"
    
    var color: Color {
        switch self {
        case .feed:
            return .blue
        case .sleep:
            return .purple
        case .task:
            return .green
        }
    }
}
