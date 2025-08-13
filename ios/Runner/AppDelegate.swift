import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
      let controller = window?.rootViewController as! FlutterViewController
      PeerService.register(with: controller.registrar(forPlugin: "PeerService")!)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
