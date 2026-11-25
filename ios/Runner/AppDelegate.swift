import Flutter
import UIKit
#if canImport(GoogleMaps)
import GoogleMaps
#endif

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    #if canImport(GoogleMaps)
    if let apiKey = resolveGoogleMapsApiKey(), !apiKey.isEmpty {
      GMSServices.provideAPIKey(apiKey)
    }
    #endif
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  private func resolveGoogleMapsApiKey() -> String? {
    if let envKey = ProcessInfo.processInfo.environment["GOOGLE_MAPS_API_KEY"], !envKey.isEmpty {
      return envKey
    }
    guard let encoded = Bundle.main.infoDictionary?["DART_DEFINES"] as? String else {
      return nil
    }
    for entry in encoded.components(separatedBy: ",") {
      if let data = Data(base64Encoded: entry),
         let decoded = String(data: data, encoding: .utf8) {
        let parts = decoded.components(separatedBy: "=")
        if parts.count == 2 &&
           (parts[0] == "GOOGLE_MAPS_API_KEY" || parts[0] == "MAPS_API_KEY") &&
           !parts[1].isEmpty {
          return parts[1]
        }
      }
    }
    return nil
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
  }
}
