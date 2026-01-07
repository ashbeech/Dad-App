//
//  AIService.swift
//  Dad App
//

import Foundation

class AIService {
    static let shared = AIService()
    
    // Automatically switches between local and production URLs
    private let baseURL: String = {
        #if DEBUG
        // For simulator: localhost works
        // For physical device: use your Mac's local IP (e.g., "http://192.168.1.100:3000")
        return "http://localhost:3000"
        #else
        // TODO: Replace with your deployed server URL
        return "https://your-app.railway.app"
        #endif
    }()
    
    private let dateFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate]
        return formatter
    }()
    
    private init() {}
    
    /// Phase 1-3: Break down a goal into milestones and scheduled tasks
    /// - Parameters:
    ///   - goal: The user's goal description
    ///   - deadline: Optional target completion date
    ///   - preferences: User's scheduling preferences
    ///   - executionProfile: Optional learned behavioral profile (Phase 3)
    ///   - context: Optional additional context
    /// - Returns: Full breakdown response with milestones and tasks
    func breakdownGoal(
        goal: String,
        deadline: Date? = nil,
        preferences: UserPreferences = .default,
        executionProfile: UserExecutionProfile? = nil,
        context: String? = nil
    ) async throws -> TaskBreakdownResponse {
        
        guard let url = URL(string: "\(baseURL)/api/breakdown") else {
            throw AIServiceError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 60  // Longer timeout for complex planning
        
        // Build request body with Phase 1 fields
        var body: [String: Any] = [
            "goal": goal,
            "currentDate": dateFormatter.string(from: Date()),
            "preferences": preferences.toDictionary()
        ]
        
        if let deadline = deadline {
            body["deadline"] = dateFormatter.string(from: deadline)
        }
        
        // Phase 3: Include behavioral profile if we have enough data
        if let profile = executionProfile, profile.hasEnoughData,
           let profileSummary = profile.toPromptSummary() {
            body["behavioralProfile"] = profileSummary
        }
        
        if let context = context {
            body["context"] = context
        }
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AIServiceError.serverError
        }
        
        // Handle different HTTP status codes
        switch httpResponse.statusCode {
        case 200:
            break
        case 400:
            throw AIServiceError.badRequest
        case 429:
            throw AIServiceError.rateLimited
        case 500...599:
            throw AIServiceError.serverError
        default:
            throw AIServiceError.serverError
        }
        
        do {
            let decoded = try JSONDecoder().decode(TaskBreakdownResponse.self, from: data)
            return decoded
        } catch {
            print("Decoding error: \(error)")
            throw AIServiceError.decodingError
        }
    }
    
    /// Legacy method for backward compatibility - returns just tasks
    func breakdownGoalSimple(
        goal: String,
        deadline: Date? = nil,
        context: String? = nil
    ) async throws -> [GeneratedTask] {
        let response = try await breakdownGoal(
            goal: goal,
            deadline: deadline,
            context: context
        )
        return response.tasks
    }
}

enum AIServiceError: Error, LocalizedError {
    case invalidURL
    case serverError
    case decodingError
    case badRequest
    case rateLimited
    
    var errorDescription: String? {
        switch self {
        case .invalidURL: return "Invalid server URL"
        case .serverError: return "Server error occurred"
        case .decodingError: return "Failed to parse response"
        case .badRequest: return "Invalid request"
        case .rateLimited: return "Too many requests. Please try again later."
        }
    }
}