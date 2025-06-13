//
//  apphr.swift
//  RwiftUI
//
//  Created by thawdezin on 6/13/25.
//

// bamawl_hrApp
import SwiftUI
import GoogleMaps

@main
struct bamawl_hrApp: App {
    @StateObject var viewModel: OnboardingViewModel = OnboardingViewModel()
    @StateObject var versionViewModel = VersionViewModel()
    @StateObject var pusherManager = PusherManager() // Instantiate PusherManager here

    @AppStorage("company_code") var companyCode: String?
    @AppStorage("is_login") var isLogin:Bool = false
    @AppStorage("change_code") var isChangeCompanyCode:Bool = false

    @Environment(\.scenePhase) private var scenePhase // To handle app lifecycle
    
    init() {
        GMSServices.provideAPIKey("AIzaSyA8j5RKQ1N3XBdenpjf_HYuAxcPyAXb3UY")
    }

    var body: some Scene {
        WindowGroup {
            NavigationView {
                if companyCode == nil, isChangeCompanyCode {
                    CompanyLoginScreen()
                } else if !isLogin {
                    LoginScreen()
                } else {
                    PackageScreen()
                        .environmentObject(pusherManager) // Make PusherManager available to PackageScreen and its children
                        .onReceive(pusherManager.$latestPusherAlert) { alert in //Instance method 'onReceive(_:perform:)' requires that 'Binding<Published<PusherSalaryAlertModel?>.Publisher>' conform to 'Publisher'
                            if let alert = alert {
                                // Handle the alert in your UI, e.g., show a SwiftUI Alert or banner
                                print("Received Pusher Alert: \(alert.message)")
                                // You can store this in a @State or @Published property in PackageScreen
                                // to trigger a UI update.
                            }
                        }
                }
            }.environmentObject(viewModel)
                .buttonStyle(PlainButtonStyle())
        }
//        .onChange(of: scenePhase) { oldPhase, newPhase in
//            if newPhase == .active {
//                // App became active, potentially reconnect Pusher if needed
//                pusherManager.connectPusher()
//            } else if newPhase == .background {
//                // App went to background, disconnect Pusher to save resources
//                pusherManager.disconnectPusher()
//            }
//        }
        .onChange(of: scenePhase) { newPhase in
            if newPhase == .active {
                pusherManager.connectPusher()
            } else if newPhase == .background {
                pusherManager.disconnectPusher()
            }
        }

    }
}

