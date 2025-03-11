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
                    
                    // Setup timer to check for naps that need to be stopped at bedtime
                    dataStore.setupBedtimeNapCheckTimer()
                }
                .onChange(of: UIApplication.shared.applicationState) { _, newState in
                    // When app comes to foreground, check for naps at bedtime
                    if newState == .active {
                        dataStore.checkAndStopNapsAtBedtime()
                    }
                    
                    // Clean up deletion caches when app goes to background
                    if newState == .background {
                        dataStore.cleanupDeletionCaches()
                    }
                }
        }
    }
}
