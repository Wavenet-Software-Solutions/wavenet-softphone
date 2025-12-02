import UIKit
import CallKit
import AVFAudio
import PushKit
import Flutter
import flutter_callkit_incoming

@UIApplicationMain
@objc class AppDelegate: FlutterAppDelegate, PKPushRegistryDelegate, CallkitIncomingAppDelegate {

    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil
    ) -> Bool {

        GeneratedPluginRegistrant.register(with: self)

        // Setup PushKit
        let voipRegistry = PKPushRegistry(queue: .main)
        voipRegistry.delegate = self
        voipRegistry.desiredPushTypes = [.voIP]

        if #available(iOS 10.0, *) {
            UNUserNotificationCenter.current().delegate = self
        }

        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }

    // MARK: - VoIP Token
    func pushRegistry(_ registry: PKPushRegistry,
                      didUpdate credentials: PKPushCredentials,
                      for type: PKPushType) {

        let deviceToken = credentials.token.map { String(format: "%02x", $0) }.joined()
        print("VoIP Token:", deviceToken)

        SwiftFlutterCallkitIncomingPlugin.sharedInstance?.setDevicePushTokenVoIP(deviceToken)
    }

    func pushRegistry(_ registry: PKPushRegistry,
                      didInvalidatePushTokenFor type: PKPushType) {
        SwiftFlutterCallkitIncomingPlugin.sharedInstance?.setDevicePushTokenVoIP("")
    }

    // MARK: - Incoming VoIP Push
    func pushRegistry(_ registry: PKPushRegistry,
                      didReceiveIncomingPushWith payload: PKPushPayload,
                      for type: PKPushType,
                      completion: @escaping () -> Void) {

        guard type == .voIP else { return }

        print("📩 Incoming payload:", payload.dictionaryPayload)

        let id = payload.dictionaryPayload["id"] as? String ?? UUID().uuidString
        let name = payload.dictionaryPayload["nameCaller"] as? String ?? "Unknown"
        let handle = payload.dictionaryPayload["handle"] as? String ?? name
        let isVideo = payload.dictionaryPayload["isVideo"] as? Bool ?? false

        let data = flutter_callkit_incoming.Data(
            id: id,
            nameCaller: name,
            handle: handle,
            type: isVideo ? 1 : 0
        )

        data.extra = payload.dictionaryPayload as NSDictionary

        SwiftFlutterCallkitIncomingPlugin.sharedInstance?.showCallkitIncoming(
            data,
            fromPushKit: true
        ) {
            completion()
        }
    }

    // MARK: - REQUIRED PROTOCOL METHODS
    func onAccept(_ call: Call, _ action: CXAnswerCallAction) {
        print("☎️ Accept")
        action.fulfill()
    }

    func onDecline(_ call: Call, _ action: CXEndCallAction) {
        print("❌ Decline")
        action.fulfill()
    }

    func onEnd(_ call: Call, _ action: CXEndCallAction) {
        print("🔚 End")
        action.fulfill()
    }

    func onTimeOut(_ call: Call) {
        print("⌛ Timeout")
    }

    func didActivateAudioSession(_ audioSession: AVAudioSession) {
        print("🔊 Audio session activated")
    }

    func didDeactivateAudioSession(_ audioSession: AVAudioSession) {
        print("🔇 Audio session deactivated")
    }
}
