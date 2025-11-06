import UIKit
import Flutter
import UserNotifications
import flutter_local_notifications // 💡 required for background isolate handling
import Flutter
import AVFoundation

@main
@objc class AppDelegate: FlutterAppDelegate {
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

    // 🌸 Required to make background notification actions work
    FlutterLocalNotificationsPlugin.setPluginRegistrantCallback { (registry) in
      GeneratedPluginRegistrant.register(with: registry)
    }

    // 🍏 Allow notifications to appear when app is open
    UNUserNotificationCenter.current().delegate = self

    // 🎧 Register iOS notification categories (for action buttons)
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

    // 💫 Register categories with iOS
    UNUserNotificationCenter.current().setNotificationCategories([incomingCategory, activeCategory])

    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
