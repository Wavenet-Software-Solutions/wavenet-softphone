import UIKit
import Flutter
import UserNotifications
import AVFoundation
import PushKit
import flutter_local_notifications
import flutter_callkit_incoming   // 💕 Required for CallKit plugin

@main
@objc class AppDelegate: FlutterAppDelegate, PKPushRegistryDelegate {

    var voipRegistry: PKPushRegistry?
    var voipToken: String?

    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {

        // 🌸 Background audio (important for SIP)
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback,
                                                            mode: .voiceChat,
                                                            options: [.mixWithOthers])
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("⚠️ Failed to configure AVAudioSession: \(error)")
        }

        // 🔔 Allow background isolate (flutter_local_notifications)
        FlutterLocalNotificationsPlugin.setPluginRegistrantCallback { registry in
            GeneratedPluginRegistrant.register(with: registry)
        }

        // 📲 PushKit setup
        voipRegistry = PKPushRegistry(queue: .main)
        voipRegistry?.delegate = self
        voipRegistry?.desiredPushTypes = [.voIP]

        print("📱 PushKit initialized.")

        UNUserNotificationCenter.current().delegate = self
        GeneratedPluginRegistrant.register(with: self)

        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }

    // 🔑 Step 1: APNs gives VoIP token
    func pushRegistry(_ registry: PKPushRegistry,
                      didUpdate pushCredentials: PKPushCredentials,
                      for type: PKPushType) {

        let token = pushCredentials.token.map { String(format: "%02x", $0) }.joined()
        self.voipToken = token

        print("🔑 VoIP Token: \(token)")
        UIPasteboard.general.string = token
    }

    // 📞 Step 2: Incoming VoIP push received
    func pushRegistry(_ registry: PKPushRegistry,
                      didReceiveIncomingPushWith payload: PKPushPayload,
                      for type: PKPushType,
                      completion: @escaping () -> Void) {

        print("📩 Incoming VoIP Push Payload: \(payload.dictionaryPayload)")

        // 🌸 Extract caller from payload
        let caller = (payload.dictionaryPayload["caller"] as? String) ?? "Unknown"
        let uuid = UUID().uuidString

        // 🍎 Tell CallKit plugin about token
        if let token = voipToken {
            FlutterCallkitIncomingPlugin.sharedInstance()?.setDevicePushTokenVoIP(token)
        } else {
            print("⚠️ VoIP token not available yet.")
        }

        // 🧚 Create params for CallKit popup
        let params: [String: Any] = [
            "id": uuid,
            "nameCaller": caller,
            "handle": caller,
            "type": 0,
            "appName": "Wavenet Softphone",
            "duration": 30000,
            "textAccept": "Answer",
            "textDecline": "Decline",
            "android": [:],
            "ios": [
                "handleType": "generic",
                "supportsVideo": false
            ]
        ]

        // 💖 Show CallKit incoming popup
        FlutterCallkitIncomingPlugin.sharedInstance()?.showCallkitIncoming(params)

        completion()
    }

    // ❌ Token invalidated
    func pushRegistry(_ registry: PKPushRegistry,
                      didInvalidatePushTokenFor type: PKPushType) {
        print("❌ VoIP token invalidated")
        FlutterCallkitIncomingPlugin.sharedInstance()?.setDevicePushTokenVoIP("")
    }
}
