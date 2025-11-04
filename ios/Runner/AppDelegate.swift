import Flutter
import UIKit
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    UNUserNotificationCenter.current().delegate = self

    // 🌸 Register iOS notification categories
    let muteAction = UNNotificationAction(identifier: "MUTE_ACTION",
                                          title: "Mute/Unmute 🎙️",
                                          options: [])
    let hangupAction = UNNotificationAction(identifier: "HANGUP_ACTION",
                                            title: "Hang Up 💔",
                                            options: [.destructive])

    let activeCategory = UNNotificationCategory(identifier: "active_call",
                                                actions: [muteAction, hangupAction],
                                                intentIdentifiers: [],
                                                options: [])
    UNUserNotificationCenter.current().setNotificationCategories([activeCategory])

    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}

