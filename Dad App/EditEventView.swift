//
//  EditEventView.swift
//  Dad App
//
//  Created by Ashley Davison on 06/03/2025.
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
                        withAnimation(.easeInOut(duration: 0.3)) {
                            offset = UIScreen.main.bounds.height
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            presentationMode.wrappedValue.dismiss()
                        }
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
                        // TODO: placeholder
                        if let sleepEvent = dataStore.getSleepEvent(id: event.id, for: date) {
                            EditSleepView(sleepEvent: sleepEvent, date: date)
                        } else {
                            Text("Could not find sleep event details")
                                .foregroundColor(.red)
                        }
                    }
                }
                
                Spacer()
            }
            .background(Color(.systemBackground))
            .cornerRadius(16)
            .shadow(radius: 10)
            .offset(y: offset)
            .edgesIgnoringSafeArea(.all)
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("DismissEditView"))) { _ in
                withAnimation(.easeInOut(duration: 0.3)) {
                    offset = UIScreen.main.bounds.height
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    presentationMode.wrappedValue.dismiss()
                }
            }
        }
        .onAppear {
            // Animate the form sliding up when it appears
            offset = UIScreen.main.bounds.height
            withAnimation(.easeOut(duration: 0.3)) {
                offset = 0
            }
        }
    }
}
