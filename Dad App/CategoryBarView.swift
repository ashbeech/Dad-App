//
//  CategoryBarView.swift
//  Dad App
//
//  Created by Ashley Davison on 08/03/2025.
//

import SwiftUI

struct CategoryBarView: View {
    @Binding var selectedCategories: [EventType]?
    @State private var scrollOffset: CGFloat = 0
    @State private var isShowingMore = false

    // All possible categories (expandable for future)
    private let categories: [(title: String, type: [EventType]?)] = [
        ("All", nil),
        ("Feed", [.feed]),
        ("Sleep", [.sleep]),
        ("Tasks", [.task]) // Placeholder for future implementation
    ]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(0..<categories.count, id: \.self) { index in
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedCategories = categories[index].type
                        }
                    }) {
                        Text(categories[index].title)
                            .font(.callout)
                            .fontWeight(isSelected(categories[index].type) ? .bold : .regular)
                            .foregroundColor(isSelected(categories[index].type) ? .white : .primary)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 20)
                                    .fill(isSelected(categories[index].type) ? Color.blue : Color.gray.opacity(0.2))
                            )
                            // Removed the Circle() indicator that was below the text
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
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
