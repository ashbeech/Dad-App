//
//  AddEventView.swift
//  Dad App
//
//  Created by Ash Beech on 06/03/2025.
//

import SwiftUI

struct AddEventView: View {
    @EnvironmentObject var dataStore: DataStore
    @Environment(\.presentationMode) var presentationMode
    @State private var eventType: EventType = .goal
    @State private var offset: CGFloat = 0
    
    let date: Date
    let initialTime: Date
    
    init(date: Date, initialTime: Date = Date()) {
        self.date = date
        self.initialTime = initialTime
    }
    
    var body: some View {
        ZStack {
            VStack {
                HStack {
                    Text("Add New Event")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    Button("Cancel") {
                        presentationMode.wrappedValue.dismiss()
                    }
                    .foregroundColor(.blue)
                }
                .padding()
                
                Picker("Event Type", selection: $eventType) {
                    Text("Feed").tag(EventType.feed)
                    Text("Sleep").tag(EventType.sleep)
                    Text("Task").tag(EventType.task)
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding(.horizontal)
                
                // Pass the initialTime to child views
                if eventType == .feed {
                    AddFeedView(date: date, initialTime: initialTime)
                        .environmentObject(dataStore)
                } else if eventType == .sleep {
                    AddSleepView(date: date, initialTime: initialTime)
                        .environmentObject(dataStore)
                } else if eventType == .goal {
                    AddGoalView(date: date)
                        .environmentObject(dataStore)
                } else {
                    AddTaskView(date: date, initialTime: initialTime)
                        .environmentObject(dataStore)
                }
                
                Spacer()
            }
            .cornerRadius(16)
            .shadow(radius: 10)
            .background(Color.clear)
            //.offset(y: offset)
            .edgesIgnoringSafeArea(.all)
        }
        .offset(y: offset)
        .onAppear {
            // Animate the form sliding up when it appears
            offset = UIScreen.main.bounds.height
            withAnimation(.easeOut(duration: 0.3)) {
                offset = 0
            }
        }
        .onDisappear() {
            // Animate the form sliding up when it appears
            withAnimation(.easeOut(duration: 0.3)) {
                offset = UIScreen.main.bounds.height
            }
        }
    }
}
