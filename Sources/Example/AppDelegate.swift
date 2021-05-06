//
//  Copyright © 2020 Rosberry. All rights reserved.
//

import UIKit

typealias LaunchOptions = [UIApplication.LaunchOptionsKey: Any]

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: LaunchOptions?) -> Bool {
        window = UIWindow(frame: UIScreen.main.bounds)
        window?.rootViewController = ExampleViewController()
        window?.makeKeyAndVisible()
        return true
    }
}
