import UIKit
import Flutter
import AVFoundation
import PushKit
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate, PKPushRegistryDelegate {
  var voipRegistry: PKPushRegistry?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // ✅ Activate background audio session
    do {
      try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [.mixWithOthers])
      try AVAudioSession.sharedInstance().setActive(true)
      print("🎧 AVAudioSession configured for background audio")
    } catch {
      print("⚠️ AVAudioSession configuration failed: \(error)")
    }

    // ✅ Initialize PushKit for VoIP notifications
    voipRegistry = PKPushRegistry(queue: .main)
    voipRegistry?.delegate = self
    voipRegistry?.desiredPushTypes = [.voIP]
    print("📱 PushKit initialized")

    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  // 🔑 Called when APNs gives us a new VoIP token
  func pushRegistry(_ registry: PKPushRegistry, didUpdate pushCredentials: PKPushCredentials, for type: PKPushType) {
    let token = pushCredentials.token.map { String(format: "%02x", $0) }.joined()
    print("🔑 VoIP Token: \(token)")

    // Optional: copy token to clipboard for easy testing
    UIPasteboard.general.string = token
    print("📋 Token copied to clipboard")
  }

  // 📞 Called when an incoming VoIP push is received
  func pushRegistry(_ registry: PKPushRegistry, didReceiveIncomingPushWith payload: PKPushPayload, for type: PKPushType) {
    print("📞 Incoming VoIP push received: \(payload.dictionaryPayload)")
  }
}
