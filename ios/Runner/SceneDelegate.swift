import Flutter
import UIKit

class SceneDelegate: FlutterSceneDelegate {
  override func scene(
    _ scene: UIScene,
    willConnectTo session: UISceneSession,
    options connectionOptions: UIScene.ConnectionOptions
  ) {
    super.scene(scene, willConnectTo: session, options: connectionOptions)
    guard let flutter = window?.rootViewController as? FlutterViewController,
          !flutter.isDisplayingFlutterUI else { return }
    flutter.splashScreenView = UIStoryboard(name: "LaunchScreen", bundle: nil)
      .instantiateInitialViewController()?.view
  }
}
