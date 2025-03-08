//
//  TemplatesView.swift
//  Dad App
//
//  Created by Ashley Davison on 06/03/2025.
//

import SwiftUI

struct TemplatesView: View {
    @EnvironmentObject var dataStore: DataStore
    
    var body: some View {
        List {
            Section(header: Text("Feed Templates")) {
                ForEach(dataStore.baby.feedTemplates, id: \.id) { template in
                    FeedTemplateRow(template: template)
                }
                .onDelete(perform: deleteFeedTemplate)
                
                NavigationLink(destination: AddTemplateView(templateType: .feed)) {
                    Label("Add Feed Template", systemImage: "plus.circle")
                }
            }
            
            Section(header: Text("Sleep Templates")) {
                ForEach(dataStore.baby.sleepTemplates, id: \.id) { template in
                    SleepTemplateRow(template: template)
                }
                .onDelete(perform: deleteSleepTemplate)
                
                NavigationLink(destination: AddTemplateView(templateType: .sleep)) {
                    Label("Add Sleep Template", systemImage: "plus.circle")
                }
            }
        }
        .listStyle(InsetGroupedListStyle())
        .navigationTitle("Templates")
    }
    
    private func deleteFeedTemplate(at offsets: IndexSet) {
        var updatedBaby = dataStore.baby
        updatedBaby.feedTemplates.remove(atOffsets: offsets)
        dataStore.baby = updatedBaby
    }
    
    private func deleteSleepTemplate(at offsets: IndexSet) {
        var updatedBaby = dataStore.baby
        updatedBaby.sleepTemplates.remove(atOffsets: offsets)
        dataStore.baby = updatedBaby
    }
}

struct FeedTemplateRow: View {
    let template: FeedEvent
    
    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text("\(Int(template.amount))ml")
                    .font(.headline)
                
                Text(formattedTime())
                    .font(.subheadline)
                
                Text("Breast: \(Int(template.breastMilkPercentage))%, Formula: \(Int(template.formulaPercentage))%")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Image(systemName: "cup.and.saucer.fill")
                .foregroundColor(.blue)
        }
    }
    
    private func formattedTime() -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: template.date)
    }
}

struct SleepTemplateRow: View {
    let template: SleepEvent
    
    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(template.sleepType.rawValue)
                    .font(.headline)
                
                Text("\(formattedTime(template.date)) - \(formattedTime(template.endTime))")
                    .font(.subheadline)
                
                if !template.notes.isEmpty {
                    Text(template.notes)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            Image(systemName: template.sleepType == .nap ? "moon.zzz.fill" : "bed.double.fill")
                .foregroundColor(template.sleepType == .nap ? .purple : .indigo)
        }
    }
    
    private func formattedTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}
