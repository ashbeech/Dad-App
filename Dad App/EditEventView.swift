//
//  EditEventView.swift
//  Dad App
//
//  Created by Ash Beech on 06/03/2025.
//

import SwiftUI

struct EditEventView: View {
    @EnvironmentObject var dataStore: DataStore
    @Environment(\.presentationMode) var presentationMode
    
    let event: Event
    let date: Date
    
    @State private var offset: CGFloat = 0
    @State private var buttonScale: CGFloat = 1.0
    @State private var shouldDismiss: Bool = false
    
    var body: some View {
        ZStack {
            // Use a fullscreen ZStack instead of NavigationView
            VStack {
                HStack {
                    Text("Edit Event")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    Button("Cancel") {
                        presentationMode.wrappedValue.dismiss()
                    }
                    .foregroundColor(.blue)
                }
                .padding()
                
                Group {
                    switch event.type {
                    case .feed:
                        if let feedEvent = dataStore.getFeedEvent(id: event.id, for: date) {
                            EditFeedView(feedEvent: feedEvent, date: date)
                        } else {
                            Text("Could not find feed event details")
                                .foregroundColor(.red)
                        }
                    case .sleep:
                        if let sleepEvent = dataStore.getSleepEvent(id: event.id, for: date) {
                            EditSleepView(sleepEvent: sleepEvent, date: date)
                        } else {
                            Text("Could not find sleep event details")
                                .foregroundColor(.red)
                        }
                    case .task:
                        if let taskEvent = dataStore.getTaskEvent(id: event.id, for: date) {
                            EditTaskView(taskEvent: taskEvent, date: date)
                        } else {
                            Text("Could not find task event details")
                                .foregroundColor(.red)
                        }
                    case .goal:
                        if let goalEvent = dataStore.getGoalEvent(id: event.id, for: date) {
                            EditGoalView(goalEvent: goalEvent, date: date)
                        } else {
                            Text("Could not find goal event details")
                                .foregroundColor(.red)
                        }
                    }
                }
                
                Spacer()
            }
            .background(Color(.systemBackground))
            .cornerRadius(16)
            .shadow(radius: 10)
            .edgesIgnoringSafeArea(.all)
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("DismissEditView"))) { _ in
                presentationMode.wrappedValue.dismiss()
            }
        }
    }
}
