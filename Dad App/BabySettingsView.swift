//
//  BabySettingsView.swift
//  Dad App
//
//  Created by Ashley Davison on 06/03/2025.
//

import SwiftUI

struct BabySettingsView: View {
    @EnvironmentObject var dataStore: DataStore
    @Environment(\.presentationMode) var presentationMode
    
    @State private var babyName: String
    @State private var wakeTime: Date
    @State private var bedTime: Date
    
    init() {
        _babyName = State(initialValue: "")
        _wakeTime = State(initialValue: Date())
        _bedTime = State(initialValue: Date())
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Baby Information")) {
                    TextField("Baby Name", text: $babyName)
                }
                
                Section(header: Text("Daily Schedule")) {
                    DatePicker("Wake Time", selection: $wakeTime, displayedComponents: .hourAndMinute)
                    DatePicker("Bed Time", selection: $bedTime, displayedComponents: .hourAndMinute)
                }
                
                Section(header: Text("Templates")) {
                    NavigationLink(destination: TemplatesView()) {
                        Text("Manage Feed & Sleep Templates")
                    }
                }
                
                Button(action: saveSettings) {
                    Text("Save Settings")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
                .buttonStyle(PlainButtonStyle())
                .padding()
            }
            .navigationTitle("Baby Settings")
            .navigationBarItems(trailing: Button("Done") {
                presentationMode.wrappedValue.dismiss()
            })
            .onAppear {
                // Load current baby settings
                babyName = dataStore.baby.name
                wakeTime = dataStore.baby.wakeTime
                bedTime = dataStore.baby.bedTime
            }
        }
    }
    
    private func saveSettings() {
        var updatedBaby = dataStore.baby
        updatedBaby.name = babyName
        updatedBaby.wakeTime = wakeTime
        updatedBaby.bedTime = bedTime
        
        dataStore.baby = updatedBaby
        
        // Post notification with async delay to ensure UI updates AFTER dataStore changes propagate
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            NotificationCenter.default.post(name: NSNotification.Name("BabyTimeChanged"), object: nil)
        }
        
        presentationMode.wrappedValue.dismiss()
    }
}
