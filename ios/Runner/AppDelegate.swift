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

        // Background audio
        try? AVAudioSession.sharedInstance().setCategory(.playback,
                                                         mode: .voiceChat,
                                                         options: [.mixWithOthers])
        try? AVAudioSession.sharedInstance().setActive(true)

        // Setup PushKit
        voipRegistry = PKPushRegistry(queue: .main)
        voipRegistry?.delegate = self
        voipRegistry?.desiredPushTypes = [.voIP]

        UNUserNotificationCenter.current().delegate = self

        GeneratedPluginRegistrant.register(with: self)

        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }

    // MARK: - VoIP Token
    func pushRegistry(_ registry: PKPushRegistry,
                      didUpdate pushCredentials: PKPushCredentials,
                      for type: PKPushType) {

        let token = pushCredentials.token.map { String(format: "%02x", $0) }.joined()
        self.voipToken = token

        print("🔑 VoIP Token:", token)
        UIPasteboard.general.string = token
    }

    // MARK: - Incoming VoIP Push
    func pushRegistry(_ registry: PKPushRegistry,
                      didReceiveIncomingPushWith payload: PKPushPayload,
                      for type: PKPushType,
                      completion: @escaping () -> Void) {

        print("📩 Incoming VoIP Payload:", payload.dictionaryPayload)

        let payloadDict = payload.dictionaryPayload
        let caller = payloadDict["caller"] as? String ?? "Unknown"
        let uuid = UUID().uuidString

        // Prepare CallKit params
        let params: [String: Any] = [
            "id": uuid,
            "nameCaller": caller,
            "handle": caller,
            "type": 0,
            "appName": "Wavenet Softphone",
            "duration": 30000,
            "textAccept": "Answer",
            "textDecline": "Decline",
            "extra": payloadDict,
            "ios": [
                "handleType": "generic",
                "supportsVideo": false
            ]
        ]

        // Invoke Flutter plugin over MethodChannel
        if let controller = window?.rootViewController as? FlutterViewController {
            let channel = FlutterMethodChannel(
                name: "flutter_callkit_incoming",
                binaryMessenger: controller.binaryMessenger
            )

            channel.invokeMethod("showCallkitIncoming", arguments: params)
        }

        completion()
    }
}
