//
//  CategoryBarView.swift
//  Dad App
//
//  Created by Ash Beech on 08/03/2025.
//

import SwiftUI

struct CategoryBarView: View {
    @Binding var selectedCategories: [EventType]?
    
    // All possible categories (expandable for future)
    private let categories: [(title: String, type: [EventType]?)] = [
        ("All", nil),
        ("Goals", [.goal]),
        ("Feed", [.feed]),
        ("Sleep", [.sleep]),
        ("Tasks", [.task])
    ]

    var body: some View {
        HStack(spacing: 0) {
            ForEach(0..<categories.count, id: \.self) { index in
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedCategories = categories[index].type
                    }
                }) {
                    Text(categories[index].title)
                        .font(.callout)
                        .fontWeight(isSelected(categories[index].type) ? .bold : .regular)
                        .foregroundColor(isSelected(categories[index].type) ? .blue : .gray)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            isSelected(categories[index].type)
                            ? Color.blue.opacity(0.1)
                            : Color.gray.opacity(0.05)
                        )
                }
                .buttonStyle(PlainButtonStyle())
                
                // Add divider between categories (except after the last one)
                if index < categories.count - 1 {
                    Divider()
                        .frame(height: 24)
                }
            }
        }
        .background(Color(.secondarySystemBackground))
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
        )
    }
    
    private func isSelected(_ eventTypes: [EventType]?) -> Bool {
        if selectedCategories == nil && eventTypes == nil {
            return true
        }
        if let types = eventTypes, let selectedTypes = selectedCategories {
            return types == selectedTypes
        }
        return false
    }
}
