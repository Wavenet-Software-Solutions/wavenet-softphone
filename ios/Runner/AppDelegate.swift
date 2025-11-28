import UIKit
import Flutter
import PushKit
import AVFoundation
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate, PKPushRegistryDelegate {

    var voipRegistry: PKPushRegistry?
    var voipToken: String?

    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil
    ) -> Bool {

        try? AVAudioSession.sharedInstance().setCategory(.playback,
                                                         mode: .voiceChat,
                                                         options: [.mixWithOthers])
        try? AVAudioSession.sharedInstance().setActive(true)

        // PushKit
        voipRegistry = PKPushRegistry(queue: .main)
        voipRegistry?.delegate = self
        voipRegistry?.desiredPushTypes = [.voIP]

        UNUserNotificationCenter.current().delegate = self

        GeneratedPluginRegistrant.register(with: self)
        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }

    // MARK: - Token
    func pushRegistry(_ registry: PKPushRegistry,
                      didUpdate pushCredentials: PKPushCredentials,
                      for type: PKPushType) {
        let token = pushCredentials.token.map { String(format: "%02x", $0) }.joined()
        voipToken = token
        print("🔑 VoIP Token:", token)
        UIPasteboard.general.string = token
    }

    // MARK: - REQUIRED HANDLER #1 (iOS 13–18)
    func pushRegistry(_ registry: PKPushRegistry,
                      didReceiveIncomingPushWith payload: PKPushPayload,
                      for type: PKPushType,
                      completion: @escaping () -> Void) {

        handleVoipPush(payload)
        completion()  // 💖 REQUIRED or iOS crashes app
    }

    // MARK: - REQUIRED HANDLER #2 (legacy)
    func pushRegistry(_ registry: PKPushRegistry,
                      didReceiveIncomingPushWith payload: PKPushPayload,
                      for type: PKPushType) {

        handleVoipPush(payload)
    }

    // MARK: - Shared handler
    private func handleVoipPush(_ payload: PKPushPayload) {
        print("📩 Incoming VoIP Payload:", payload.dictionaryPayload)

        let caller = payload.dictionaryPayload["caller"] as? String ?? "Unknown"
        let uuid = UUID().uuidString

        let params: [String: Any] = [
            "id": uuid,
            "nameCaller": caller,
            "handle": caller,
            "type": 0,
            "appName": "Wavenet Softphone",
            "duration": 30000,
            "extra": payload.dictionaryPayload,
            "ios": [
                "handleType": "generic",
                "supportsVideo": false
            ]
        ]

        if let controller = window?.rootViewController as? FlutterViewController {
            let channel = FlutterMethodChannel(
                name: "flutter_callkit_incoming",
                binaryMessenger: controller.binaryMessenger
            )
            channel.invokeMethod("showCallkitIncoming", arguments: params)
        }
    }
}
