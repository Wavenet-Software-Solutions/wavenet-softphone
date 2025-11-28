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

     // Extract safe values
     let payloadDict = payload.dictionaryPayload
     let caller = payloadDict["caller"] as? String ?? "Unknown"
     let handle = payloadDict["handle"] as? String ?? caller
     let uuid = (payloadDict["uuid"] as? String) ?? UUID().uuidString

     // Register token inside plugin (important)
     if let token = voipToken {
         SwiftFlutterCallkitIncomingPlugin.sharedInstance?
             .setDevicePushTokenVoIP(token)
     }

     // CallKit configuration (100% safe)
     let params: [String: Any] = [
         "id": uuid,                          // REQUIRED
         "nameCaller": caller,
         "handle": handle,
         "type": 0,
         "appName": "Wavenet Softphone",
         "duration": 30000,
         "textAccept": "Answer",
         "textDecline": "Decline",
         "extra": payloadDict,                // pass whole push if needed
         "ios": [
             "handleType": "generic",
             "supportsVideo": false
         ]
     ]

     // 💖 THE FIX — use PushKit mode!
     SwiftFlutterCallkitIncomingPlugin.sharedInstance?
         .showCallkitIncoming(params, fromPushKit: true)

     completion()
 }


    // ❌ Token invalidated
    func pushRegistry(_ registry: PKPushRegistry,
                      didInvalidatePushTokenFor type: PKPushType) {
        print("❌ VoIP token invalidated")
        FlutterCallkitIncomingPlugin.sharedInstance()?.setDevicePushTokenVoIP("")
    }
}
