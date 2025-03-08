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
            NavigationView {
                ContentView()
                    .environmentObject(dataStore)
            }
            .onAppear {
                // Request notification permissions when app launches
                NotificationManager.shared.requestAuthorization()
            }
        }
    }
}
