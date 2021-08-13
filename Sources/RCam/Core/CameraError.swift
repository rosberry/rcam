//
//  Copyright © 2019 Rosberry. All rights reserved.
//

import Foundation

enum CameraError {
    case noCaptureSession
    case cameraNotFound
    case cameraSwitchFailed
}

extension CameraError: LocalizedError {
    public var errorDescription: String? {
        switch self {
            case .noCaptureSession:
                return "Capture session isn't found"
            case .cameraNotFound:
                return "Camera not found"
            case .cameraSwitchFailed:
                return "Camera switch failed"
        }
    }
}
