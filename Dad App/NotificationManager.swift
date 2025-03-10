//
//  NotificationManager.swift
//  Dad App
//
//  Created by Ashley Davison on 06/03/2025.
//

import Foundation
import UserNotifications

class NotificationManager {
    static let shared = NotificationManager()
    
    private init() {
        requestAuthorization()
    }
    
    func requestAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
            if granted {
                print("Notification permission granted")
            } else if let error = error {
                print("Notification permission error: \(error.localizedDescription)")
            }
        }
    }
    
    func scheduleFeedNotification(for feedEvent: FeedEvent) {
        // Don't schedule notifications for past events
        if feedEvent.date < Date() {
            return
        }
        
        // Schedule feed notification
        let content = UNMutableNotificationContent()
        content.title = "Time to Feed"
        content.body = "Feed \(Int(feedEvent.amount))ml (Breast milk: \(Int(feedEvent.breastMilkPercentage))%, Formula: \(Int(feedEvent.formulaPercentage))%)"
        if !feedEvent.notes.isEmpty {
            content.body += " - \(feedEvent.notes)"
        }
        content.sound = .default
        
        let feedTrigger = UNCalendarNotificationTrigger(
            dateMatching: Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: feedEvent.date),
            repeats: false
        )
        
        let feedRequest = UNNotificationRequest(
            identifier: "feed-\(feedEvent.id.uuidString)",
            content: content,
            trigger: feedTrigger
        )
        
        UNUserNotificationCenter.current().add(feedRequest)
        
        // Schedule preparation notification
        let prepContent = UNMutableNotificationContent()
        prepContent.title = "Prepare Milk"
        prepContent.body = "Prepare \(Int(feedEvent.amount))ml (Breast milk: \(Int(feedEvent.breastMilkPercentage))%, Formula: \(Int(feedEvent.formulaPercentage))%)"
        prepContent.sound = .default
        
        let prepTrigger = UNCalendarNotificationTrigger(
            dateMatching: Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: feedEvent.preparationTime),
            repeats: false
        )
        
        let prepRequest = UNNotificationRequest(
            identifier: "prep-\(feedEvent.id.uuidString)",
            content: prepContent,
            trigger: prepTrigger
        )
        
        UNUserNotificationCenter.current().add(prepRequest)
        
        // Add a notification 30 minutes ahead as well, if it's more than 30 minutes in the future
        scheduleEarlyNotification(for: feedEvent)
    }
    
    func scheduleSleepNotification(for sleepEvent: SleepEvent) {
        // Don't schedule notifications for past events
        if sleepEvent.date < Date() {
            return
        }
        
        // Only schedule notifications for nap and bedtime, not waketime
        if sleepEvent.sleepType == .nap || sleepEvent.sleepType == .bedtime {
            let content = UNMutableNotificationContent()
            content.title = sleepEvent.sleepType == .nap ? "Nap Time" : "Bedtime"
            content.body = "Time for baby to \(sleepEvent.sleepType == .nap ? "nap" : "go to bed")"
            if !sleepEvent.notes.isEmpty {
                content.body += " - \(sleepEvent.notes)"
            }
            content.sound = .default
            
            let trigger = UNCalendarNotificationTrigger(
                dateMatching: Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: sleepEvent.date),
                repeats: false
            )
            
            let request = UNNotificationRequest(
                identifier: "sleep-\(sleepEvent.id.uuidString)",
                content: content,
                trigger: trigger
            )
            
            UNUserNotificationCenter.current().add(request)
            
            // Add a notification 30 minutes ahead as well, if it's more than 30 minutes in the future
            scheduleEarlyNotification(for: sleepEvent)
        }
    }
    
    func scheduleTaskNotification(for taskEvent: TaskEvent, at notificationTime: Date) {
        // Don't schedule notifications for past events
        if notificationTime < Date() {
            return
        }
        
        let content = UNMutableNotificationContent()
        content.title = "Task Reminder: \(taskEvent.title)"
        content.body = "Task scheduled to start at \(formatTime(taskEvent.date))"
        if !taskEvent.notes.isEmpty {
            content.body += " - \(taskEvent.notes)"
        }
        content.sound = .default
        
        let triggerDate = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: notificationTime)
        let trigger = UNCalendarNotificationTrigger(dateMatching: triggerDate, repeats: false)
        
        let request = UNNotificationRequest(
            identifier: "task-\(taskEvent.id.uuidString)",
            content: content,
            trigger: trigger
        )
        
        UNUserNotificationCenter.current().add(request)
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    private func scheduleEarlyNotification(for feedEvent: FeedEvent) {
        if feedEvent.date > Date().addingTimeInterval(30 * 60) {
            let earlyContent = UNMutableNotificationContent()
            let earlyDate = feedEvent.date.addingTimeInterval(-30 * 60)
            
            earlyContent.title = "Feed Coming Up Soon"
            earlyContent.body = "Feeding in 30 minutes: \(Int(feedEvent.amount))ml"
            earlyContent.sound = .default
            
            let earlyTrigger = UNCalendarNotificationTrigger(
                dateMatching: Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: earlyDate),
                repeats: false
            )
            
            let earlyRequest = UNNotificationRequest(
                identifier: "early-feed-\(feedEvent.id.uuidString)",
                content: earlyContent,
                trigger: earlyTrigger
            )
            
            UNUserNotificationCenter.current().add(earlyRequest)
        }
    }
    
    private func scheduleEarlyNotification(for sleepEvent: SleepEvent) {
        if sleepEvent.sleepType == .nap || sleepEvent.sleepType == .bedtime {
            if sleepEvent.date > Date().addingTimeInterval(30 * 60) {
                let earlyContent = UNMutableNotificationContent()
                let earlyDate = sleepEvent.date.addingTimeInterval(-30 * 60)
                
                earlyContent.title = "\(sleepEvent.sleepType == .nap ? "Nap" : "Bedtime") Coming Up Soon"
                earlyContent.body = "\(sleepEvent.sleepType == .nap ? "Nap" : "Bedtime") in 30 minutes"
                earlyContent.sound = .default
                
                let earlyTrigger = UNCalendarNotificationTrigger(
                    dateMatching: Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: earlyDate),
                    repeats: false
                )
                
                let earlyRequest = UNNotificationRequest(
                    identifier: "early-sleep-\(sleepEvent.id.uuidString)",
                    content: earlyContent,
                    trigger: earlyTrigger
                )
                
                UNUserNotificationCenter.current().add(earlyRequest)
            }
        }
    }
    
    func cancelNotification(for eventId: UUID) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [
            "feed-\(eventId.uuidString)",
            "prep-\(eventId.uuidString)",
            "sleep-\(eventId.uuidString)",
            "early-feed-\(eventId.uuidString)",
            "early-sleep-\(eventId.uuidString)"
        ])
    }
    
    func cancelAllNotifications() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    }
}
