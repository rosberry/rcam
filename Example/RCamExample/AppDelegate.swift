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
        let rCamViewController = CameraViewController()
        rCamViewController.delegate = self
        window = UIWindow(frame: UIScreen.main.bounds)
        window?.rootViewController = rCamViewController
        window?.makeKeyAndVisible()
        return true
    }
}

extension AppDelegate: CameraViewControllerDelegate {
    func cameraViewController(_ viewController: CameraViewController, imageCaptured image: UIImage) {
        UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
    }

    func cameraViewControllerCloseEventTriggered(_ viewController: CameraViewController) {
    }
}
