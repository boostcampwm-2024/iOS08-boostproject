import UIKit

import LiveStreamFeature

@main
final class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?
    
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        window = UIWindow(frame: UIScreen.main.bounds)
        let viewController = LiveStreamViewController(viewModel: LiveStreamViewModel())
        window?.rootViewController = viewController
        window?.makeKeyAndVisible()
        return true
    }
}

struct UseCase1:
