//
//  DadTrackApp.swift
//  Dad App
//
//  Created by Ashley Davison on 06/03/2025.
//

import SwiftUI

@main
struct DadTrackApp: App {
    @StateObject private var dataStore = DataStore()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(dataStore)
                .onAppear {
                    // Request notification permissions when app launches
                    NotificationManager.shared.requestAuthorization()
                    
                    // CRITICAL FIX: Ensure today's schedule exists
                    dataStore.ensureTodayScheduleExists()
                    
                    // Setup timer to check for naps that need to be stopped at bedtime
                    dataStore.setupBedtimeNapCheckTimer()
                    
                    // CRITICAL FIX: Post a notification that the app has launched
                    // This will trigger UI components to refresh
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        NotificationCenter.default.post(
                            name: NSNotification.Name("AppLaunched"),
                            object: nil
                        )
                    }
                }
                .onChange(of: UIApplication.shared.applicationState) { _, newState in
                    // When app comes to foreground, check for naps at bedtime
                    if newState == .active {
                        print("App became active")
                        
                        // CRITICAL FIX: Ensure today's schedule exists when app becomes active
                        dataStore.ensureTodayScheduleExists()
                        
                        // Check for naps that should be stopped at bedtime
                        dataStore.checkAndStopNapsAtBedtime()
                        
                        // CRITICAL FIX: Post a notification that the app became active
                        // This will trigger UI components to refresh
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                            NotificationCenter.default.post(
                                name: UIApplication.didBecomeActiveNotification,
                                object: nil
                            )
                            
                            // Also post our custom notification
                            NotificationCenter.default.post(
                                name: NSNotification.Name("EventDataChanged"),
                                object: nil
                            )
                        }
                    }
                    
                    // Clean up deletion caches when app goes to background
                    if newState == .background {
                        dataStore.cleanupDeletionCaches()
                    }
                }
        }
    }
}
