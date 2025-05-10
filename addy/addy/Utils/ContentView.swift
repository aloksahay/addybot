//
//  ContentView.swift
//  addy
//
//  Created by Alok Sahay on 24.01.2025.
//

import SwiftUI

struct ContentView: View {
    @StateObject var vm: ViewModel

    var body: some View {
        NavigationView {
                    VStack {
                        if vm.isLoading {
                            ProgressView()
                        } else {
                            if vm.loggedIn,let user = vm.user, let web3rpc = Web3RPC(user: user) {
                                DashboardView(web3RPC: web3rpc, viewModel: vm)
                            } else {
                                LoginView(vm: vm)
                            }
                        }
                    }
                    Spacer()
                }
                .onAppear {
                    Task {
                        await vm.setup()
                    }
                }
    }
}
