//
//  NumberExtensions.swift
//  MDGA
//
//  Created by LuoHuanyu on 2023/5/19.
//  Copyright © 2023 LuoHuanyu. All rights reserved.
//

import Foundation

extension Int {
    var normalDegree: Int {
        if self < 0 {
            return self + 360
        }
        return self
    }
    
    var headingDegree: Int {
        if self > 180 {
            return self - 360
        } else if self < -180 {
            return self + 360
        }
        return self
    }
}

extension Float {
    var normalDegree: Float {
        if self < 0 {
            return self + 360
        } else if self > 360 {
            return self - 360
        }
        return self
    }
    
    var headingDegree: Float {
        if self > 180 {
            return self - 360
        } else if self < -180 {
            return self + 360
        }
        return self
    }
}

extension CGFloat {
    var normalDegree: CGFloat {
        if self < 0 {
            return self + 360
        } else if self > 360 {
            return self - 360
        }
        return self
    }
    
    var headingDegree: CGFloat {
        if self > 180 {
            return self - 360
        } else if self < -180 {
            return self + 360
        }
        return self
    }
}

extension Float {
    var double: Double {
        Double(self)
    }
}

extension Double {
    var float: Float {
        Float(self)
    }
}

extension Int {
    var float: Float {
        Float(self)
    }
}


extension FloatingPoint {
    
    var radians: Self {
        return Self.pi * self / Self(180)
    }
    
    var degrees: Self {
        return self * Self(180) / Self.pi
    }
    
}
