import SwiftUI

private struct PurchaseOverlay: View {
    let onBuy: () -> Void
    let onCancel: () -> Void
    @State private var isLoading = false
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.7)
                .edgesIgnoringSafeArea(.all)
            
            VStack(spacing: 20) {
                Text("Purchase Mood Room")
                    .font(.system(size: 18))
                    .foregroundColor(.white)
                
                Text("1 MNT")
                    .font(.system(size: 48, weight: .bold))
                    .foregroundColor(.white)
                
                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(1.5)
                } else {
                    VStack(spacing: 12) {
                        Button(action: {
                            isLoading = true
                            DispatchQueue.main.asyncAfter(deadline: .now() + 4) {
                                isLoading = false
                                onBuy()
                            }
                        }) {
                            Text("Buy for 1 MNT")
                                .font(.system(size: 18, weight: .medium))
                                .foregroundColor(.black)
                                .frame(width: 200, height: 50)
                                .background(Color.white)
                                .cornerRadius(12)
                        }
                        
                        Button(action: onCancel) {
                            Text("Cancel")
                                .font(.system(size: 18, weight: .medium))
                                .foregroundColor(.white)
                                .frame(width: 200, height: 50)
                                .background(Color.red.opacity(0.5))
                                .cornerRadius(12)
                        }
                    }
                }
            }
        }
    }
}

public struct DashboardView: View {
    @StateObject var web3RPC: Web3RPC
    @StateObject var viewModel: ViewModel
    @State private var currentPage = 0
    @State private var showHistory = false
    @State private var recommendations: [TaskRecommendation] = []
    @State private var selectedTaskDuration: Int?
    @State private var showFocusMode = false
    @State private var showPurchaseOverlay = false
    @State private var selectedImageForPurchase: Int?
    @State private var purchasedImages: Set<Int> = [1] // Image 1 is free by default
    @State private var balanceTimer: Timer?
    @State private var showLogoutAlert = false
    
    public init(web3RPC: Web3RPC, viewModel: ViewModel) {
        _web3RPC = StateObject(wrappedValue: web3RPC)
        _viewModel = StateObject(wrappedValue: viewModel)
    }
            
    
    private var userInitial: String {
        guard let email = viewModel.user?.userInfo?.email,
              let initial = email.first else { return "?" }
        return String(initial).uppercased()
    }
    
    private var sessionDuration: Int {
        selectedTaskDuration ?? recommendations.first?.sessionDuration ?? 0
    }
    
    public var body: some View {
        ZStack {
            // Background - Slate color
            Color(red: 30/255, green: 31/255, blue: 34/255)
                .ignoresSafeArea()
            
            VStack(spacing: 20) {
                // Top Bar with aligned buttons
                HStack(alignment: .top) {
                    // History Button
                    ZStack {
                        Circle()
                            .fill(Color.black)
                            .frame(width: 40, height: 40)
                        Image(systemName: "clock.fill")
                            .foregroundColor(.white)
                            .font(.system(size: 18))
                    }
                    .onTapGesture {
                        showHistory = true
                    }
                    
                    Spacer()
                    
                    // Profile and Balance with Logout
                    VStack(alignment: .trailing, spacing: 8) {
                        ZStack {
                            Circle()
                                .fill(Color.black)
                                .frame(width: 40, height: 40)
                            Text(userInitial)
                                .foregroundColor(.white)
                                .font(.system(size: 18, weight: .medium))
                        }
                        
                        if web3RPC.balance >= 0 {
                            Button(action: {
                                showLogoutAlert = true
                            }) {
                                Text("\(String(format: "%.1f", web3RPC.balance)) MNT")
                                    .foregroundColor(.white)
                                    .font(.system(size: 16, weight: .semibold))
                            }
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.top, 20)
                
                // Updated TabView with purchase/owned indicators
                TabView(selection: $currentPage) {
                    ForEach(1...4, id: \.self) { index in
                        ZStack(alignment: .bottomTrailing) {
                            Image("\(index)")
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: UIScreen.main.bounds.width - 40, height: 300)
                                .cornerRadius(20)
                            
                            if purchasedImages.contains(index) {
                                // Owned image indicator
                                ZStack {
                                    Circle()
                                        .fill(Color.green.opacity(0.6))
                                        .frame(width: 40, height: 40)
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.white)
                                }
                                .padding(12)
                            } else {
                                // Purchase button
                                Button(action: {
                                    selectedImageForPurchase = index
                                    showPurchaseOverlay = true
                                }) {
                                    VStack(spacing: 4) {
                                        ZStack {
                                            Circle()
                                                .stroke(Color.yellow, lineWidth: 2)
                                                .background(Circle().fill(Color.black.opacity(0.7)))
                                                .frame(width: 40, height: 40)
                                            Image(systemName: "cart.fill")
                                                .foregroundColor(.white)
                                        }
                                        Text("1 MNT")
                                            .font(.system(size: 12, weight: .medium))
                                            .foregroundColor(.white)
                                    }
                                }
                                .padding(12)
                            }
                        }
                        .tag(index - 1)
                    }
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .automatic))
                .frame(height: 300)
                
                // Tasks ScrollView
                if !recommendations.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 15) {
                            ForEach(Array(recommendations.enumerated()), id: \.element.taskName) { index, task in
                                Button(action: {
                                    selectedTaskDuration = task.sessionDuration
                                }) {
                                    VStack(alignment: .leading, spacing: 8) {
                                        Text(task.taskName)
                                            .foregroundColor(.white)
                                            .font(.system(size: 16, weight: .medium))
                                            .multilineTextAlignment(.leading)
                                            .lineLimit(2)
                                        
                                        ProgressView(value: task.currentCompletion)
                                            .progressViewStyle(LinearProgressViewStyle(tint: .green))
                                            .frame(width: 120)
                                    }
                                    .frame(width: 160, height: 100)
                                    .padding(.horizontal, 20)
                                    .padding(.vertical, 12)
                                    .background(Color.black)
                                    .cornerRadius(10)
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                } else {
                    Text("Loading tasks...")
                        .foregroundColor(.gray)
                }
                
                // Session Duration Display - only show when tasks are loaded
                if !recommendations.isEmpty {
                    Text("\(sessionDuration) min")
                        .font(.system(size: 48, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.vertical, 30)
                }
                
                Spacer()
                
                // Start Focus Session Button
                Button(action: {
                    showFocusMode = true
                }) {
                    Text("Start Focus Session")
                        .foregroundColor(.white)
                        .font(.system(size: 18, weight: .bold))
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(Color.black)
                        .cornerRadius(12)
                }
                .padding(.horizontal)
                .padding(.bottom, 30)
            }
            
            // Updated Purchase Overlay
            if showPurchaseOverlay {
                PurchaseOverlay(
                    onBuy: {
                        if let imageIndex = selectedImageForPurchase {
                            purchasedImages.insert(imageIndex)
                            web3RPC.getBalance()
                        }
                        showPurchaseOverlay = false
                    },
                    onCancel: {
                        showPurchaseOverlay = false
                    }
                )
                .transition(.opacity)
            }
        }
        .fullScreenCover(isPresented: $showHistory) {
            HistoryView(isPresented: $showHistory)
        }
        .fullScreenCover(isPresented: $showFocusMode) {
            FocusModeView(
                isPresented: $showFocusMode,
                sessionDuration: sessionDuration,
                selectedImageIndex: currentPage
            )
        }
        .alert(isPresented: $showLogoutAlert) {
            Alert(
                title: Text("Logout"),
                message: Text("Are you sure you want to logout?"),
                primaryButton: .destructive(Text("Logout")) {
                    Task {
                        do {
                            try await viewModel.logout()
                        } catch {
                            print("Logout failed: \(error)")
                        }
                    }
                },
                secondaryButton: .cancel()
            )
        }
        .onAppear {
            web3RPC.getBalance()
            fetchRecommendations()
            startBalancePolling()
        }
        .onDisappear {
            balanceTimer?.invalidate()
        }
    }
    
    private func fetchRecommendations() {
        // Replace localhost with your machine's IP address
        guard let url = URL(string: "http://192.168.1.112:3000/recommend-session") else {
            print("⚠️ Invalid URL")
            return
        }
        
        print("📡 Fetching recommendations from: \(url)")
        
        var request = URLRequest(url: url)
        request.timeoutInterval = 30 // Increased timeout for development
        
        // Add headers if needed
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("❌ Error fetching recommendations: \(error)")
                return
            }
            
            if let httpResponse = response as? HTTPURLResponse {
                print("📥 Response status code: \(httpResponse.statusCode)")
            }
            
            guard let data = data else {
                print("❌ No data received")
                return
            }
            
            print("📦 Received data: \(String(data: data, encoding: .utf8) ?? "Unable to decode data")")
            
            do {
                let decodedResponse = try JSONDecoder().decode(RecommendationResponse.self, from: data)
                print("✅ Successfully decoded \(decodedResponse.recommendations.count) recommendations")
                
                DispatchQueue.main.async {
                    self.recommendations = decodedResponse.recommendations
                }
            } catch {
                print("❌ Decoding error: \(error)")
            }
        }.resume()
    }
    
    private func startBalancePolling() {
        // Initial fetch already done in onAppear
        
        // Set up polling every 10 seconds
        balanceTimer = Timer.scheduledTimer(withTimeInterval: 10, repeats: true) { _ in
            web3RPC.getBalance()
        }
    }
}
