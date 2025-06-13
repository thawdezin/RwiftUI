//
//  PackageScreen.swift
//  RwiftUI
//
//  Created by thawdezin on 6/13/25.
//

import SwiftUI

struct PackageScreen: View {
    // MARK: – Inject PusherManager
    @EnvironmentObject var pusherManager: PusherManager
    @EnvironmentObject var mainViewModel: OnboardingViewModel

    // Original state
    @StateObject var viewModel: PackageViewModel = PackageViewModel()
    @State private var isLogoutNavigate: Bool = false
    @AppStorage("is_upgrade") var isUpgrade: Bool = false
    @State private var isPlanNavigate: Bool = false
    
    // MARK: – For Pusher alert
    @State private var showingPusherAlert: Bool = false
    @State private var pusherAlertMessage: String = ""
    
    var body: some View {
        ZStack {
            Image("launchScreen")
                .resizable()
                .edgesIgnoringSafeArea(.all)
            
            VStack {
                // CONNECTION STATE (optional)
                Text("Pusher: \(pusherManager.connectionState.stringValue())")
                    .foregroundColor(.white)
                    .padding(.bottom, 8)
                
                Text("Welcome to Bamawl System!")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .padding(.bottom, 50)
                    .alert(isPresented: $isUpgrade) {
                        getVersionAlert()
                    }
                
                List {
                    ForEach(viewModel.packageList) { package in
                        Text(package.package_name)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .background(
                                Capsule()
                                    .stroke(Color.white, style: StrokeStyle(lineWidth: 1))
                            )
                            .foregroundColor(Color.white)
                            .font(.caption)
                            .onTapGesture {
                                onNavigate(package: package)
                            }
                            .padding(.vertical, 16)
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                    }
                }
                .alert(isPresented: $mainViewModel.showError) {
                    getAlert(isMain: true)
                }
                .refreshable {
                    viewModel.getAccessPacakge()
                }
                .listStyle(.plain)
                .padding(.horizontal, 20)
                .onAppear {
                    viewModel.getAccessPacakge()
                }
                
                Spacer()
                
                if let appVersion = viewModel.appVersion {
                    Text("Version: \(appVersion)")
                        .font(.headline)
                        .foregroundColor(Color.theme.primaryColor)
                        .alert(isPresented: $viewModel.showError) {
                            getAlert(isMain: false)
                        }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.top, 50)
            .allowsHitTesting(!viewModel.isLoading)
            
            if viewModel.isLoading || mainViewModel.isLoading {
                AppProgressView()
            }
            
            NavigationLink(
                destination: HRMainScreen(),
                isActive: $mainViewModel.isNavigateHR
            ){ EmptyView() }
            
            NavigationLink(
                destination: PlanMainScreen(),
                isActive: $isPlanNavigate
            ){ EmptyView() }
            
            NavigationLink(
                destination: LogoutScreen(),
                isActive: $isLogoutNavigate
            ){ EmptyView() }
        }
        // MARK: – Listen for Pusher alerts
        .onReceive(pusherManager.$latestPusherAlert) { alert in
            if let alert = alert {
                pusherAlertMessage = alert.message
                showingPusherAlert = true
            }
        }
        // MARK: – Show SwiftUI Alert
        .alert("New Salary Alert!", isPresented: $showingPusherAlert) {
            Button("OK") {
                showingPusherAlert = false
                pusherManager.latestPusherAlert = nil
            }
        } message: {
            Text(pusherAlertMessage)
        }
    }
}

// MARK: – Helpers
extension PackageScreen {
    func onNavigate(package: AccessPackage) {
        if package.short_name == "hr" {
            viewModel.showError = false
            viewModel.errorMessage = ""
            mainViewModel.getMenus()
        } else if package.short_name == "plan" {
            isPlanNavigate = true
        } else {
            viewModel.errorMessage = "Coming Soon!"
            viewModel.showError = true
        }
    }
    
    func getAlert(isMain: Bool) -> Alert {
        return Alert(
            title: Text(isMain ? mainViewModel.errorMessage : viewModel.errorMessage),
            dismissButton: .default(Text("OK")) {
                if viewModel.isTokenExpire || mainViewModel.isTokenExpire {
                    isLogoutNavigate = true
                }
            }
        )
    }
    
    func getVersionAlert() -> Alert {
        return Alert(
            title: Text("Update Alert!"),
            message: Text("There's a new version of the app available"),
            primaryButton: .default(Text("Maybe later")),
            secondaryButton: .default(Text("Update")) {
                UIApplication.shared.open(URL(string: APPSTORE_URL)!)
            }
        )
    }
}

