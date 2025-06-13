//
//  PusherManager.swift
//  RwiftUI
//
//  Created by thawdezin on 6/13/25.
//

import Foundation
import Combine
import PusherSwift

class AuthRequestBuilder: AuthRequestBuilderProtocol {

    private let gatewayURL = "https://uat-api-hr.bamawl.com/api"
    private let companyKey = "company_code"

    func requestFor(socketID: String, channelName: String) -> URLRequest? {
        // 1. Get company code
        guard let company = UserDefaults.standard.string(forKey: companyKey) else {
            print("Error: company_code not found")
            return nil
        }
        // 2. Build URL
        let urlString = "\(gatewayURL)/\(company)/websocket/auth"
        guard let url = URL(string: urlString) else {
            print("Error: invalid URL \(urlString)")
            return nil
        }
        // 3. Prepare request
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        // 4. JSON-encode body
        let payload = [
            "socket_id": socketID,
            "channel_name": channelName
        ]
        do {
            request.httpBody = try JSONEncoder().encode(payload)
        } catch {
            print("Error encoding auth payload: \(error)")
            return nil
        }
        // 5. Headers
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        let token = getTokenData()?.access_token
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        print("AuthRequest → \(request.httpMethod ?? "") \(url.absoluteString)")
        return request
    }
}

struct WebSocketSetting: Codable {
    var status: String
    var data: WebSocketData
}

struct WebSocketData: Codable {
    let broadcaster: String
    let appId: String
    let key: String
    let host: String
    let cluster: String
    let port: Int
    let scheme: String
    let encrypted: Bool
    let tls: Bool

    private enum CodingKeys: String, CodingKey {
        case broadcaster
        case appId = "app_id"
        case key
        case host
        case cluster
        case port
        case scheme
        case encrypted
        case tls
    }
}

class WebSocketService: BaseService {
    private let gatewayURL = "https://uat-api-hr.bamawl.com/api"
    private let companyKey = "company_code"

    func realtimeAPI() -> AnyPublisher<WebSocketData, Error> {
        // Get company code
        guard let company = UserDefaults.standard.string(forKey: companyKey) else {
            return Fail(error: APIError.invalidCompanyCode).eraseToAnyPublisher()
        }
        // Build URL string
        let urlString = "\(gatewayURL)/\(company)/websocket/setting"
        // Fetch & decode
        return fetch(url: urlString, method: .get)
            .tryMap { (response: WebSocketSetting) -> WebSocketData in
                // Check status
                guard response.status != "NG" else {
                    throw APIError.customError(message: "Realtime API returned NG")
                }
                return response.data
            }
            .eraseToAnyPublisher()
    }
}

// Assuming this is how your Pusher event data looks
struct PusherSalaryAlertModel: Codable {
    let message: String
    let to: String
    let flag: String
    let tenantKeyName: String

    private enum CodingKeys: String, CodingKey {
        case message
        case to
        case flag
        case tenantKeyName = "tenant_key_name"
    }
}

// Extend Notification.Name for your custom notification if you still want to use it
extension Notification.Name {
    static let pusherSalaryAlert = Notification.Name("PusherSalaryAlertNotification")
}

class PusherManager: NSObject, ObservableObject {
    @Published var connectionState: ConnectionState = .disconnected
    @Published var latestPusherAlert: PusherSalaryAlertModel?

    var pusher: Pusher! // Initialized later
    var webSocketSetting: WebSocketSetting = WebSocketSetting(
        status: "",
        data: WebSocketData(
            broadcaster: "",
            appId: "",
            key: "",
            host: "",
            cluster: "",
            port: 0,
            scheme: "",
            encrypted: false,
            tls: false
        )
    )

    private var cancellables = Set<AnyCancellable>()
    private let webSocketService = WebSocketService() // Or integrate into BaseService
    private let _companyNameKey = "company_code" // Key for UserDefaults

    override init() {
        super.init()
        // Fetch WebSocket settings when the manager is initialized
        fetchWebSocketSettings()
    }

    func fetchWebSocketSettings() {
        webSocketService.realtimeAPI()
            .sink { completion in
                switch completion {
                case .failure(let error):
                    print("Failed to fetch WebSocket settings: \(error.localizedDescription)")
                    // Handle error, e.g., show an alert, retry
                case .finished:
                    break
                }
            } receiveValue: { [weak self] data in
                self?.webSocketSetting.data = data
                self?.setupPusher()
                self?.connectPusher()
            }
            .store(in: &cancellables)
    }

    private func setupPusher() {
        // Retrieve company name from UserDefaults
        guard let companyName = UserDefaults.standard.string(forKey: _companyNameKey) else {
            print("Error: Company name not found in UserDefaults.")
            // Handle this error appropriately, perhaps disconnect or show an error state
            return
        }

        let p = PusherClientOptions(
            authMethod: AuthMethod.authRequestBuilder(authRequestBuilder: AuthRequestBuilder()), // Assuming AuthRequestBuilder is defined elsewhere
            attemptToReturnJSONObject: true,
            autoReconnect: true,
            host: PusherHost.host(webSocketSetting.data.host), // Use host from fetched data
            port: webSocketSetting.data.port, // Use port from fetched data
            useTLS: webSocketSetting.data.tls, // Use TLS from fetched data
            activityTimeout: 1000
        )

        pusher = Pusher(withAppKey: webSocketSetting.data.key, options: p)
        pusher.delegate = self
    }

    func connectPusher() {
        if pusher == nil {
            print("Pusher client not initialized. Cannot connect.")
            return
        }
        pusher.connect()
    }

    func disconnectPusher() {
        pusher?.disconnect()
    }

    private func subscribeAndBind() {
        guard let companyName = UserDefaults.standard.string(forKey: _companyNameKey) else {
            print("Error: Company name not found for subscription.")
            return
        }

        let channelName = "private-tenant.\(companyName).salary.calculate"
        let eventName = "tenant.\(companyName).background.process.status"

        let myChannel = pusher.subscribe(channelName: channelName)

        _ = myChannel.bind(eventName: eventName) { [weak self] (event: PusherEvent) in
            guard let json: String = event.data else {
                print("Could not get JSON string from event data")
                return
            }
            guard let jsonData = json.data(using: .utf8) else {
                print("Could not convert JSON string to data")
                return
            }

            do {
                let decoder = JSONDecoder()
                let psam = try decoder.decode(PusherSalaryAlertModel.self, from: jsonData)
                DispatchQueue.main.async {
                    self?.latestPusherAlert = psam
                    // If you still want to use NotificationCenter
                    let userInfo: [String: Any] = ["message": psam.message, "flag": psam.flag]
                    NotificationCenter.default.post(name: .pusherSalaryAlert, object: nil, userInfo: userInfo)
                }
            } catch {
                print("Error decoding JSON: \(error)")
            }
        }
    }
}

// MARK: - PusherDelegate Extension
extension PusherManager: PusherDelegate {
    func changedConnectionState(from old: ConnectionState, to new: ConnectionState) {
        DispatchQueue.main.async {
            self.connectionState = new
            print("噫 old: \(old.stringValue()) -> new: \(new.stringValue())")
            if new == .connected {
                self.subscribeAndBind() // Subscribe once connected
            }
        }
    }

    func subscribedToChannel(name: String) {
        print("承 Subscribed to \(name)")
    }

    func debugLog(message: String) {
        print("竢ｰ Message: \(message)")
    }

    func receivedError(error: PusherError) {
        if let code = error.code {
            print("ｧｨ Received error: (\(code)) \(error.message)")
        } else {
            print("ｧｨ Received error: \(error.message)")
        }
    }

    func didReceiveErrorEvent(_ event: PusherError) {
        print("Pusher error: \(event.message)")
    }
}

