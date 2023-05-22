//
//  MapKitExtentision.swift
//  PeachTree
//
//  Created by LuoHuanyu on 2020/5/5.
//  Copyright © 2020 LuoHuanyu. All rights reserved.
//

import MapKit

extension CLLocationCoordinate2D {
    
    func distance(to coordinate: CLLocationCoordinate2D) -> Double {
        return mapPoint.distance(to: coordinate.mapPoint)
    }
    
    var mapPoint: MKMapPoint {
        MKMapPoint(self)
    }
    
    var cgPoint: CGPoint {
        mapPoint.cgPoint
    }

    var isValid: Bool {
        if self.latitude == 0 && self.longitude == 0 {
            return false
        }
        return CLLocationCoordinate2DIsValid(self)
    }
    
}

extension MKMapPoint {
    var cgPoint: CGPoint {
        .init(x: self.x, y: self.y)
    }
}
