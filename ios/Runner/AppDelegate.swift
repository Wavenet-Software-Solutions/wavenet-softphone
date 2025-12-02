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
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {

        // Register Flutter plugins
        GeneratedPluginRegistrant.register(with: self)

        // Setup PushKit for VoIP
        let mainQueue = DispatchQueue.main
        let voipRegistry = PKPushRegistry(queue: mainQueue)
        voipRegistry.delegate = self
        voipRegistry.desiredPushTypes = [.voIP]

        // Enable missed call notifications
        if #available(iOS 10.0, *) {
            UNUserNotificationCenter.current().delegate = self
        }

        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }

    // MARK: - VoIP Token
    func pushRegistry(_ registry: PKPushRegistry, didUpdate credentials: PKPushCredentials, for type: PKPushType) {
        let deviceToken = credentials.token.map { String(format: "%02x", $0) }.joined()
        print("VoIP Token:", deviceToken)
        SwiftFlutterCallkitIncomingPlugin.sharedInstance?.setDevicePushTokenVoIP(deviceToken)
    }

    func pushRegistry(_ registry: PKPushRegistry, didInvalidatePushTokenFor type: PKPushType) {
        SwiftFlutterCallkitIncomingPlugin.sharedInstance?.setDevicePushTokenVoIP("")
    }

    // MARK: - Incoming VoIP Push
    func pushRegistry(_ registry: PKPushRegistry,
                      didReceiveIncomingPushWith payload: PKPushPayload,
                      for type: PKPushType,
                      completion: @escaping () -> Void) {

        guard type == .voIP else { return }

        let id = payload.dictionaryPayload["id"] as? String ?? UUID().uuidString
        let name = payload.dictionaryPayload["nameCaller"] as? String ?? "Unknown"
        let handle = payload.dictionaryPayload["handle"] as? String ?? "Unknown"
        let isVideo = payload.dictionaryPayload["isVideo"] as? Bool ?? false

        // Create CallKit data object
        let data = flutter_callkit_incoming.Data(
            id: id,
            nameCaller: name,
            handle: handle,
            type: isVideo ? 1 : 0
        )

        data.extra = payload.dictionaryPayload

        // Show CallKit incoming UI
        SwiftFlutterCallkitIncomingPlugin.sharedInstance?.showCallkitIncoming(data, fromPushKit: true) {
            completion()
        }
    }

    // MARK: - Call Actions
    func onAccept(_ call: Call, _ action: CXAnswerCallAction) {
        print("Accept call")
        action.fulfill()
    }

    func onDecline(_ call: Call, _ action: CXEndCallAction) {
        print("Decline call")
        action.fulfill()
    }

    func onEnd(_ call: Call, _ action: CXEndCallAction) {
        print("End call")
        action.fulfill()
    }

    func onTimeOut(_ call: Call) {
        print("Call timeout")
    }
}
