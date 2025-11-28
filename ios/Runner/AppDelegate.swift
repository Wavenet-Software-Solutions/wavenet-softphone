import UIKit
import Flutter
import UserNotifications
import AVFoundation
import PushKit
import flutter_local_notifications
import flutter_callkit_incoming

@main
@objc class AppDelegate: FlutterAppDelegate, PKPushRegistryDelegate {

    var voipRegistry: PKPushRegistry?
    var voipToken: String?

    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {

        // iOS audio session
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback,
                                                            mode: .voiceChat,
                                                            options: [.mixWithOthers])
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("⚠️ Failed to configure AVAudioSession: \(error)")
        }

        // Local notifications
        FlutterLocalNotificationsPlugin.setPluginRegistrantCallback { registry in
            GeneratedPluginRegistrant.register(with: registry)
        }

        // PushKit setup
        voipRegistry = PKPushRegistry(queue: .main)
        voipRegistry?.delegate = self
        voipRegistry?.desiredPushTypes = [.voIP]

        UNUserNotificationCenter.current().delegate = self

        GeneratedPluginRegistrant.register(with: self)
        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }

    // MARK: - PushKit VoIP Token Received
    func pushRegistry(_ registry: PKPushRegistry,
                      didUpdate pushCredentials: PKPushCredentials,
                      for type: PKPushType) {

        let token = pushCredentials.token.map { String(format: "%02x", $0) }.joined()
        self.voipToken = token

        print("📱 VoIP Token: \(token)")

        // Send token to Flutter
        if let controller = window?.rootViewController as? FlutterViewController {
            let channel = FlutterMethodChannel(name: "voip_token",
                                               binaryMessenger: controller.binaryMessenger)
            channel.invokeMethod("updateVoipToken", arguments: token)
        }
    }

    // MARK: - PushKit Token Invalidated
    func pushRegistry(_ registry: PKPushRegistry,
                      didInvalidatePushTokenFor type: PKPushType) {

        print("❌ VoIP Token invalidated")

        if let controller = window?.rootViewController as? FlutterViewController {
            let channel = FlutterMethodChannel(name: "voip_token",
                                               binaryMessenger: controller.binaryMessenger)
            channel.invokeMethod("updateVoipToken", arguments: "")
        }
    }

    // MARK: - Incoming VoIP Push Received
    func pushRegistry(_ registry: PKPushRegistry,
                      didReceiveIncomingPushWith payload: PKPushPayload,
                      for type: PKPushType,
                      completion: @escaping () -> Void) {

        print("📩 Incoming VoIP Push Payload: \(payload.dictionaryPayload)")

        // Forward entire payload to Flutter
        if let controller = window?.rootViewController as? FlutterViewController {
            let channel = FlutterMethodChannel(name: "voip_push",
                                               binaryMessenger: controller.binaryMessenger)

            channel.invokeMethod("incomingVoip", arguments: payload.dictionaryPayload)
        }

        completion()
    }
}
