import UIKit
import Flutter
import UserNotifications
import flutter_local_notifications   // 💡 Needed for background isolate
import AVFoundation
import PushKit

@main
@objc class AppDelegate: FlutterAppDelegate, PKPushRegistryDelegate {

  var voipRegistry: PKPushRegistry?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {

    // 🎧 Enable background audio so VoIP sounds can play
    do {
      try AVAudioSession.sharedInstance().setCategory(.playback,
                                                      mode: .default,
                                                      options: [.mixWithOthers])
      try AVAudioSession.sharedInstance().setActive(true)
      print("🎧 AVAudioSession configured for background audio")
    } catch {
      print("⚠️ Failed to configure AVAudioSession: \(error)")
    }

    // 📲 Initialize PushKit for VoIP notifications
    voipRegistry = PKPushRegistry(queue: .main)
    voipRegistry?.delegate = self
    voipRegistry?.desiredPushTypes = [.voIP]
    print("📱 PushKit initialized and waiting for token")

    // 🌸 Allow background isolate for local notifications
    FlutterLocalNotificationsPlugin.setPluginRegistrantCallback { registry in
      GeneratedPluginRegistrant.register(with: registry)
    }

    // 🍏 Allow notifications while app is in foreground
    UNUserNotificationCenter.current().delegate = self

    // 💬 Define iOS notification categories for action buttons
    let acceptAction = UNNotificationAction(identifier: "ACCEPT",
                                            title: "✅ Accept",
                                            options: [.foreground])
    let declineAction = UNNotificationAction(identifier: "DECLINE",
                                             title: "❌ Decline",
                                             options: [.destructive])
    let incomingCategory = UNNotificationCategory(identifier: "incoming_call",
                                                  actions: [acceptAction, declineAction],
                                                  intentIdentifiers: [],
                                                  options: [])

    let muteAction = UNNotificationAction(identifier: "MUTE_ACTION",
                                          title: "Mute/Unmute 🎙️",
                                          options: [.foreground])
    let hangupAction = UNNotificationAction(identifier: "HANGUP_ACTION",
                                            title: "Hang Up 💔",
                                            options: [.destructive])
    let activeCategory = UNNotificationCategory(identifier: "active_call",
                                                actions: [muteAction, hangupAction],
                                                intentIdentifiers: [],
                                                options: [])

    UNUserNotificationCenter.current()
      .setNotificationCategories([incomingCategory, activeCategory])

    // ✅ Standard Flutter plugin registration
    GeneratedPluginRegistrant.register(with: self)
    return super.application(application,
                             didFinishLaunchingWithOptions: launchOptions)
  }

  // 🔑 Called when APNs provides a new VoIP token
  func pushRegistry(_ registry: PKPushRegistry,
                    didUpdate pushCredentials: PKPushCredentials,
                    for type: PKPushType) {

    let token = pushCredentials.token.map { String(format: "%02x", $0) }.joined()
    print("🔑 VoIP Token: \(token)")

    // 📋 Copy token to clipboard for quick testing
    UIPasteboard.general.string = token
    print("📋 Token copied to clipboard")

    // 💫 Show popup alert with the token (for debugging)
    DispatchQueue.main.async {
      let alert = UIAlertController(title: "VoIP Token",
                                    message: token,
                                    preferredStyle: .alert)
      alert.addAction(UIAlertAction(title: "OK", style: .default))

      // ✅ Present alert from the root view controller safely
      if let rootVC = UIApplication.shared.connectedScenes
          .compactMap({ $0 as? UIWindowScene })
          .flatMap({ $0.windows })
          .first(where: { $0.isKeyWindow })?.rootViewController {
        rootVC.present(alert, animated: true)
      } else {
        print("⚠️ Could not find rootViewController to present token alert.")
      }
    }

    // 💾 TODO: Send token to your backend for PushKit registration
    // Example:
    // MyApiService.registerVoipToken(userId: currentUser.id, token: token)
  }

  // 📞 Called when a VoIP push notification arrives
  func pushRegistry(_ registry: PKPushRegistry,
                    didReceiveIncomingPushWith payload: PKPushPayload,
                    for type: PKPushType) {

     print(credentials.token)
     let deviceToken = credentials.token.map { String(format: "%02x", $0) }.joined()
     // Save deviceToken to your server
     SwiftFlutterCallkitIncomingPlugin.sharedInstance?.setDevicePushTokenVoIP(deviceToken)

    // Here you can handle the payload — e.g. show CallKit screen
    // FlutterCallkitIncoming.showCallkitIncoming(...)
  }

  // 💔 Optional: handle if push fails to register
  func pushRegistry(_ registry: PKPushRegistry,
                    didInvalidatePushTokenFor type: PKPushType) {
       print("didInvalidatePushTokenFor")
        SwiftFlutterCallkitIncomingPlugin.sharedInstance?.setDevicePushTokenVoIP("")
  }
}
