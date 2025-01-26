import SwiftUI

private struct AnimatedNumber: View {
    let value: Int
    let duration: Double = 0.3
    @State private var displayedValue: Int = 0
    
    var body: some View {
        Text("\(displayedValue)")
            .font(.system(size: 24, weight: .bold))
            .onAppear {
                withAnimation(.spring(duration: duration)) {
                    displayedValue = value
                }
            }
            .onChange(of: value) { newValue in
                withAnimation(.spring(duration: duration)) {
                    displayedValue = newValue
                }
            }
    }
}

// Define a struct to hold commit statistics
private struct CommitStats: Equatable {
    let additions: Int
    let deletions: Int
}

private struct SessionCompletionOverlay: View {
    let elapsedTime: Int
    let onDone: () -> Void
    
    private var durationString: String {
        let minutes = elapsedTime / 60
        let seconds = elapsedTime % 60
        if minutes > 0 {
            return "\(minutes)m:\(seconds)s"
        }
        return "\(seconds) seconds"
    }
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.7)
                .edgesIgnoringSafeArea(.all)
            
            VStack(spacing: 20) {
                Text("You just focused for")
                    .font(.system(size: 18))
                    .foregroundColor(.white)
                
                Text(durationString)
                    .font(.system(size: 48, weight: .bold))
                    .foregroundColor(.white)
                
                Button(action: onDone) {
                    Text("Done")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(.black)
                        .frame(width: 200, height: 50)
                        .background(Color.white)
                        .cornerRadius(12)
                }
                .padding(.top, 20)
            }
        }
    }
}

public struct FocusModeView: View {
    @Binding var isPresented: Bool
    let sessionDuration: Int
    let selectedImageIndex: Int
    
    @State private var timeRemaining: Int
    @State private var timer: Timer?
    @State private var commitStats: CommitStats?
    @State private var showingCompletionOverlay = false
    @State private var elapsedTime: Int = 0
    
    public init(isPresented: Binding<Bool>, sessionDuration: Int, selectedImageIndex: Int) {
        _isPresented = isPresented
        self.sessionDuration = sessionDuration
        self.selectedImageIndex = selectedImageIndex
        _timeRemaining = State(initialValue: sessionDuration * 60) // Convert minutes to seconds
    }

    
    private var progress: Double {
        let totalSeconds = Double(sessionDuration * 60)
        let remainingSeconds = Double(timeRemaining)
        return 1 - (remainingSeconds / totalSeconds)
    }
    
    private var timeString: String {
        let minutes = timeRemaining / 60
        let seconds = timeRemaining % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
    
    public var body: some View {
        ZStack {
            // Background Image
            Image("\(selectedImageIndex + 1)")
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(minWidth: 0, maxWidth: .infinity)
                .edgesIgnoringSafeArea(.all)
            
            // Semi-transparent overlay
            Color.black.opacity(0.2)
                .edgesIgnoringSafeArea(.all)
            
            // Timer and Controls
            VStack(spacing: 30) {
                // Stats at the top
                if let stats = commitStats {
                    HStack(spacing: 20) {
                        VStack {
                            AnimatedNumber(value: stats.additions)
                            Text("Added")
                                .font(.system(size: 14))
                        }
                        .foregroundColor(.green)
                        .transition(.scale.combined(with: .opacity))
                        
                        VStack {
                            AnimatedNumber(value: stats.deletions)
                            Text("Removed")
                                .font(.system(size: 14))
                        }
                        .foregroundColor(.red)
                        .transition(.scale.combined(with: .opacity))
                    }
                    .padding(.vertical, 10)
                    .animation(.spring(duration: 0.3), value: stats)
                }
                
                Spacer()
                
                // Progress Bar
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        // Background
                        RoundedRectangle(cornerRadius: 5)
                            .fill(Color.white.opacity(0.3))
                            .frame(height: 10)
                        
                        // Progress
                        RoundedRectangle(cornerRadius: 5)
                            .fill(Color.white)
                            .frame(width: geometry.size.width * progress, height: 10)
                    }
                }
                .frame(height: 10)
                
                // Timer Display
                Text(timeString)
                    .font(.system(size: 64, weight: .bold))
                    .foregroundColor(.white)
                
                // End Session Button
                Button(action: {
                    timer?.invalidate()
                    showingCompletionOverlay = true
                }) {
                    Text("End Session")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(Color.red.opacity(0.6))
                        .cornerRadius(12)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 30)  // Added top padding for stats
            .safeAreaInset(edge: .bottom) {
                Color.clear.frame(height: 0)
            }
            .blur(radius: showingCompletionOverlay ? 10 : 0)
            
            // Completion Overlay
            if showingCompletionOverlay {
                SessionCompletionOverlay(
                    elapsedTime: sessionDuration * 60 - timeRemaining,
                    onDone: {
                        isPresented = false
                    }
                )
                .transition(.opacity)
            }
        }
        .animation(.easeInOut, value: showingCompletionOverlay)
        .onAppear {
            startTimer()
            startGitHubPolling()
        }
        .onDisappear {
            timer?.invalidate()
        }
    }
    
    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            if timeRemaining > 0 {
                timeRemaining -= 1
            } else {
                timer?.invalidate()
            }
        }
    }
    
    private func startGitHubPolling() {
        // Initial fetch
        fetchGitHubCommits()
        
        // Set up polling every 5 seconds
        Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { _ in
            fetchGitHubCommits()
        }
    }
    
    private func fetchGitHubCommits() {
        guard let url = URL(string: "http://192.168.1.112:3000/github-commits") else {
            print("⚠️ Invalid GitHub URL")
            return
        }
        
        var request = URLRequest(url: url)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("❌ GitHub API Error: \(error)")
                return
            }
            
            guard let data = data else {
                print("❌ No GitHub data received")
                return
            }
            
            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let stats = json["stats"] as? [String: Int] {
                    DispatchQueue.main.async {
                        commitStats = CommitStats(
                            additions: stats["additions"] ?? 0,
                            deletions: stats["deletions"] ?? 0
                        )
                        print("📊 Commit stats - Additions: \(stats["additions"] ?? 0), Deletions: \(stats["deletions"] ?? 0)")
                    }
                }
            } catch {
                print("❌ GitHub JSON Decoding error: \(error)")
            }
        }.resume()
    }
} 
