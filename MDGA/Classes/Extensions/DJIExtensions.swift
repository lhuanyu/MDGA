//
//  DJIExtensions.swift
//  MDGA
//
//  Created by LuoHuanyu on 2023/5/18.
//  Copyright © 2023 LuoHuanyu. All rights reserved.
//

import DJISDK

extension DJIGPSSignalLevel {
    
    var isAvailale: Bool {
        self == .level2 || self == .level3 || self == .level4 || self == .level5
    }
    
    var isRecordHomePointAvailable: Bool {
        self == .level4 || self == .level5
    }
        
}

extension DJIFlatCameraMode {
    var isSinglePhotoMode: Bool {
        switch self {
        case .photoHDR, .photoSmart, .photoHighResolution, .photoEHDR, .photoSingle, .photoHyperLight:
            return true
        default:
            return false
        }
    }
}

extension DJIWaypointMissionState {
    var isExcuting: Bool {
        self == .executing || self == .executionPaused
    }
}
