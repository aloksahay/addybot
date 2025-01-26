import SwiftUI
import BigInt
import Foundation
import web3

struct LoginView: View {
    @StateObject var vm: ViewModel
    @State private var emailInput: String = ""
    
    var body: some View {
        // Main container
        ZStack {
            // Background layer
            Image("splash")
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(minWidth: 0, maxWidth: .infinity)
                .edgesIgnoringSafeArea(.all)
            
            // Content layer
            VStack {
                Spacer() // Push content to bottom
                
                // Login form container
                VStack(spacing: 20) {
                    // Title and description
                    VStack(spacing: 12) {
                        Text("Addy for your ADD")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(.white)
                        
                        Rectangle()
                            .frame(height: 1)
                            .foregroundColor(.white.opacity(0.3))
                            .padding(.horizontal, 40)
                        
                        Text("Let Addy manage your tasks for you and block out the distractions to help you achieve your daily goals.")
                            .font(.system(size: 16))
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 20)
                    }
                    .padding(.bottom, 30)
                    
                    // Email field
                    TextField("Enter your email", text: $emailInput)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .keyboardType(.emailAddress)
                        .frame(height: 50)
                    
                    // Login button
                    Button(action: {
                        vm.loginEmailPasswordless(provider: .EMAIL_PASSWORDLESS, email: emailInput)
                    }) {
                        Text("Login")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(Color.black.opacity(0.5))
                            .cornerRadius(8)
                    }
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 50)
            }
            
            // Loading overlay
            if vm.isLoading {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    .scaleEffect(1.5)
            }
        }
    }
}


struct LoginView_Previews: PreviewProvider {
    static var previews: some View {
        let mockViewModel = ViewModel()
        
        // Initialize preview environment
        return Group {
            LoginView(vm: mockViewModel)
                .onAppear {
                    Task {
                        await mockViewModel.setup()
                    }
                }
                .previewDisplayName("Login Screen")
        }
    }
}

public typealias Ether = Double
public typealias Wei = BigUInt

public final class Web3AuthWeb3Utils {
    public static func timeMinToSec(val: Double) -> Double {
        return val * 60
    }

    // NOTE: calculate wei by 10^18
    private static let etherInWei = pow(Double(10), 18)
    private static let etherInGwei = pow(Double(10), 9)

    /// Convert Wei(BInt) unit to Ether(Decimal) unit
    public static func toEther(wei: Wei) -> Ether {
        guard let decimalWei = Double(wei.description) else {
            return 0
        }
        return decimalWei / etherInWei
    }

    public static func toEther(Gwie: BigUInt) -> Ether {
        guard let decimalWei = Double(Gwie.description) else {
            return 0
        }
        return decimalWei / etherInGwei
    }

    /// Convert Ether(Decimal) unit to Wei(BInt) unit
    public static func toWei(ether: Ether) -> Wei {
        let wei = Wei(ether * etherInWei)
        return wei
    }

    /// Convert Ether(String) unit to Wei(BInt) unit
    public static func toWei(ether: String) -> Wei {
        guard let decimalEther = Double(ether) else {
            return 0
        }
        return toWei(ether: decimalEther)
    }

    // Only used for calcurating gas price and gas limit.
    public static func toWei(GWei: Double) -> Wei {
        return Wei(GWei * 1000000000)
    }
}

enum ConverterError: Error {
    case failed
}

extension String {
    func isValidEthAddress() -> Bool {
        let ethAddressRegex = "^0x[a-fA-F0-9]{40}$"
        let pred = NSPredicate(format: "SELF MATCHES %@", ethAddressRegex)
        return pred.evaluate(with: self)
    }

    func numberOfOccurrencesOf(string: String) -> Int {
        return components(separatedBy: string).count - 1
    }
}

