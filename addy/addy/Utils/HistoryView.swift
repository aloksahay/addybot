import SwiftUI

struct ContributionView: View {
    let days = 7
    let contributions: [Int] = [2, 4, 1, 3, 5, 0, 2]
    let dayLabels = ["M", "T", "W", "T", "F", "S", "S"]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Last 7 Days")
                .foregroundColor(.white)
                .font(.system(size: 16, weight: .medium))
            
            VStack(spacing: 8) {
                // Day labels
                HStack(spacing: 8) {
                    ForEach(0..<days, id: \.self) { index in
                        Text(dayLabels[index])
                            .foregroundColor(.gray)
                            .font(.system(size: 12))
                            .frame(width: 40)
                    }
                }
                
                // Contribution squares
                HStack(spacing: 8) {
                    ForEach(0..<days, id: \.self) { index in
                        RoundedRectangle(cornerRadius: 4)
                            .fill(contributionColor(for: contributions[index]))
                            .frame(width: 40, height: 40)
                    }
                }
            }
        }
        .padding()
        .background(Color.black.opacity(0.3))
        .cornerRadius(10)
        .padding(.horizontal)
    }
    
    private func contributionColor(for count: Int) -> Color {
        switch count {
        case 0: return Color.gray.opacity(0.3)
        case 1...2: return Color.green.opacity(0.3)
        case 3...4: return Color.green.opacity(0.6)
        default: return Color.green
        }
    }
}

public struct HistoryView: View {
    @Binding var isPresented: Bool
    
    public init(isPresented: Binding<Bool>) {
        _isPresented = isPresented
    }
    
    public var body: some View {
        ZStack {
            // Background - Same slate color as Dashboard
            Color(red: 30/255, green: 31/255, blue: 34/255)
                .ignoresSafeArea()
            
            VStack {
                // Header
                HStack {
                    Button(action: {
                        isPresented = false
                    }) {
                        Image(systemName: "xmark")
                            .foregroundColor(.white)
                            .font(.system(size: 20, weight: .medium))
                    }
                    
                    Spacer()
                    
                    Text("History")
                        .foregroundColor(.white)
                        .font(.system(size: 20, weight: .bold))
                    
                    Spacer()
                }
                .padding()
                
                ContributionView()
                
                Spacer()
            }
        }
    }
} 
