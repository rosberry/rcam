//
//  Copyright © 2021 Rosberry. All rights reserved.
//

import AVFoundation

public extension AVCapturePhoto {

    var exifOrientation: Int32? {
        metadata[String(kCGImagePropertyOrientation)] as? Int32
    }
}
