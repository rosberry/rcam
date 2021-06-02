//
//  Copyright © 2020 Rosberry. All rights reserved.
//

import UIKit
import RCam

typealias LaunchOptions = [UIApplication.LaunchOptionsKey: Any]

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: LaunchOptions?) -> Bool {
        let rCamViewController = RCamViewController()
        rCamViewController.delegate = self
        window = UIWindow(frame: UIScreen.main.bounds)
        window?.rootViewController = rCamViewController
        window?.makeKeyAndVisible()
        return true
    }
}

extension AppDelegate: RCamViewControllerDelegate {
    func rCamViewController(_ viewController: RCamViewController, imageCaptured image: UIImage) {
        UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
    }
}
