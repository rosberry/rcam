//
//  Copyright © 2022 Rosberry. All rights reserved.
//

import UIKit

public extension UIDevice {
    
    static let isWideAngelFrontCamera: Bool = {
        var systemInfo = utsname()
        uname(&systemInfo)
        let machineMirror = Mirror(reflecting: systemInfo.machine)
        let identifier = machineMirror.children.reduce("") { identifier, element in
            guard let value = element.value as? Int8, value != 0 else { return identifier }
            return identifier + String(UnicodeScalar(UInt8(value)))
        }

        func mapToDevice(identifier: String) -> Bool {
            switch identifier {
            case "iPhone3,1", "iPhone3,2", "iPhone3,3", "iPhone4,1":
                return false
            case "iPhone5,1", "iPhone5,2":
                return false
            case "iPhone5,3", "iPhone5,4":
                return false
            case "iPhone6,1", "iPhone6,2":
                return false
            case "iPhone7,2":
                return false
            case "iPhone7,1":
                return false
            case "iPhone8,1":
                return false
            case "iPhone8,2":
                return false
            case "iPhone9,1", "iPhone9,3":
                return false
            case "iPhone9,2", "iPhone9,4":
                return false
            case "iPhone8,4":
                return false
            case "iPhone10,1", "iPhone10,4":
                return false
            case "iPhone10,2", "iPhone10,5":
                return false
            case "iPhone10,3", "iPhone10,6":
                return false
            case "iPhone11,2":
                return true
            case "iPhone11,4", "iPhone11,6":
                return true
            case "iPhone11,8":
                return true
            default:
                return true
            }
        }
        return mapToDevice(identifier: identifier)
    }()
}
