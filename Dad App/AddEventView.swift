//
//  AddEventView.swift
//  Dad App
//
//  Created by Ashley Davison on 06/03/2025.
//

import SwiftUI

struct AddEventView: View {
    @EnvironmentObject var dataStore: DataStore
    @Environment(\.presentationMode) var presentationMode
    @State private var eventType: EventType = .feed
    @State private var offset: CGFloat = 0
    
    let date: Date
    
    var body: some View {
        ZStack {
            // Use a fullscreen ZStack instead of NavigationView
            VStack {
                HStack {
                    Text("Add New Event")
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
                
                Picker("Event Type", selection: $eventType) {
                    Text("Feed").tag(EventType.feed)
                    Text("Sleep").tag(EventType.sleep)
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding(.horizontal)
                
                if eventType == .feed {
                    AddFeedView(date: date)
                } else {
                    AddSleepView(date: date)
                }
                
                Spacer()
            }
            .background(Color(.systemBackground))
            .cornerRadius(16)
            .shadow(radius: 10)
            .offset(y: offset)
            .edgesIgnoringSafeArea(.all)
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
