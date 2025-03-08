//
//  DateNavigationView.swift
//  Dad App
//
//  Created by Ashley Davison on 06/03/2025.
//

import SwiftUI

struct DateNavigationView: View {
    @Binding var currentDate: Date
    
    // Fixed height for the view to prevent layout shifts
    private let fixedHeight: CGFloat = 70
    
    var body: some View {
        HStack {
            Button(action: {
                withAnimation {
                    currentDate = Calendar.current.date(byAdding: .day, value: -1, to: currentDate) ?? currentDate
                }
            }) {
                Image(systemName: "chevron.left")
                    .font(.title2)
                    .foregroundColor(.blue)
            }
            
            Spacer()
            
            VStack(spacing: 4) {
                Text(formattedDate())
                    .font(.headline)
                
                // Always reserve space for the Today button, but make it invisible when not needed
                Button("Today") {
                    withAnimation {
                        currentDate = Date()
                    }
                }
                .font(.caption)
                .foregroundColor(.blue)
                .opacity(isToday() ? 0 : 1) // Only hide it visually
                .disabled(isToday()) // Disable when it's today
            }
            .frame(height: fixedHeight) // Fixed height
            
            Spacer()
            
            Button(action: {
                withAnimation {
                    currentDate = Calendar.current.date(byAdding: .day, value: 1, to: currentDate) ?? currentDate
                }
            }) {
                Image(systemName: "chevron.right")
                    .font(.title2)
                    .foregroundColor(.blue)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(10)
        .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
    }
    
    private func formattedDate() -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: currentDate)
    }
    
    private func isToday() -> Bool {
        Calendar.current.isDateInToday(currentDate)
    }
}
