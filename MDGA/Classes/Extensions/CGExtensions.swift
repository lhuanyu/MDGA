//
//  CoreGraphics+Extension.swift
//  PeachTree
//
//  Created by LuoHuanyu on 2020/5/5.
//  Copyright © 2020 LuoHuanyu. All rights reserved.
//

import MapKit.MKGeometry

struct CGLine {
    var point1: CGPoint
    var point2: CGPoint
    var points: [CGPoint] {
        [point1,point2]
    }
    
    var angle1:CGFloat {
        let dy = point2.y - point1.y
        let dx = point2.x - point1.x
        let α = atan2(dx,dy)
        return α
    }
    
    var angle:CGFloat {
        let dy = point2.y - point1.y
        let dx = point2.x - point1.x
        let α = atan2(dy,dx)
        return α
    }
    
    var length:CGFloat {
        point1.distanceTo(point2)
    }
    
    init(point1:CGPoint,point2:CGPoint) {
        self.point1 = point1
        self.point2 = point2
    }
    
    init(points:[CGPoint]) {
        self.point1 = points[0]
        self.point2 = points[1]
    }
    
    func intersection(_ line: CGLine, alongTheSegments: Bool = true,tolerance: CGFloat = 1e-6) -> [CGPoint] {
        var mua: CGFloat = 0
        var mub: CGFloat = 0
        
        let x1 = self.point1.x
        let y1 = self.point1.y
        let x2 = self.point2.x
        let y2 = self.point2.y
        let x3 = line.point1.x
        let y3 = line.point1.y
        let x4 = line.point2.x
        let y4 = line.point2.y
        
        let denom  = (y4-y3) * (x2-x1) - (x4-x3) * (y2-y1)
        let numera = (x4-x3) * (y1-y3) - (y4-y3) * (x1-x3)
        let numerb = (x2-x1) * (y1-y3) - (y2-y1) * (x1-x3)
        
        /* Are the lines coincident? */
        if abs(numera) < tolerance && abs(numerb) < tolerance && abs(denom) < tolerance {
            return self.points
        }
        
        /* Are the line parallel */
        if abs(denom) < tolerance {
            return []
        }
        
        /* Is the intersection along the the segments */
        mua = numera / denom
        mub = numerb / denom
        guard alongTheSegments else {
            return [CGPoint(x: x1 + mua * (x2 - x1), y: y1 + mua * (y2 - y1))]
        }
        if (mua < 0 || mua > 1 || mub < 0 || mub > 1) {
            return []
        }
        return [CGPoint(x: x1 + mua * (x2 - x1), y: y1 + mua * (y2 - y1))]
    }
    
    func offset(_ delta:CGFloat) -> CGLine {
        let rotation = CGAffineTransform(rotationAngle: angle1)
        let points = self.points.map{$0.transform(rotation)+CGPoint(x: delta,y:0)}
        let offsetPoints = points.map{$0.transform(rotation.invert)}
        return CGLine(point1: offsetPoints[0], point2: offsetPoints[1])
    }
    
    mutating func lengthen(delta1:CGFloat,delta2:CGFloat) {
        let rotation = CGAffineTransform(rotationAngle: angle1)
        var points = self.points.map{$0.transform(rotation)}
        points[1].y += delta2
        points[0].y -= delta1
        points = points.map{$0.transform(rotation.invert)}
        self.point1 = points[0]
        self.point2 = points[1]
    }
    
    @inline(__always)
    func makeIntervalPoints(with interval: CGFloat) -> [CGPoint] {
        var result = [CGPoint]()
        var transform = CGAffineTransform(translationX: -point1.x, y: -point1.y)
        let rotation = CGAffineTransform(rotationAngle: -angle)
        transform = transform + rotation
        let pts = points.map{$0.transform(transform)}
        let left = pts[0]
        let right = pts[1]
        var distance = interval
        result.append(left)
        while distance < right.x {
            result.append([distance, left.y])
            distance += interval
        }
        result.append(right)
        result = result.map{$0.transform(transform.invert)}
        return result
    }
    
    var bounds: CGRect {
        let minX = min(point1.x,point2.x)
        let maxX = max(point1.x,point2.x)
        let minY = min(point1.y,point2.y)
        let maxY = max(point1.y,point2.y)
        return CGRect(x: minX, y: minY, width: maxX-minX, height: maxY-minY)
    }
    
}

extension CGPoint: Hashable {
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(x)
        hasher.combine(y)
    }
    
    init(angle: CGFloat) {
      self.init(x: cos(angle), y: sin(angle))
    }
    
    var angle: CGFloat {
      atan2(y, x)
    }
    
}

extension CGPoint {

    @inline(__always)
    func transform(_ trans:CGAffineTransform) -> CGPoint {
        applying(trans)
    }

    var mapPoint:MKMapPoint {
        MKMapPoint(x: Double(self.x), y: Double(self.y))
    }
    
    func offset(dx:CGFloat,dy:CGFloat) -> CGPoint {
        CGPoint(x: x + dx, y: y + dy)
    }
    
}

extension CGPoint {
    func distanceTo(_ point:CGPoint) -> CGFloat {
        let dx = self.x-point.x
        let dy = self.y-point.y
        return sqrt(dx*dx+dy*dy)
    }
    
    func distaceFrom(_ line:[CGPoint]) -> CGFloat {
        let point1 = line[0]
        let point2 = line[1]
        let s = (self.x-point1.x)*(point1.y-point2.y)-(point1.x-point2.x)*(self.y-point1.y)
        let l = sqrt(pow(point1.x-point2.x,2)+pow(point1.y-point2.y,2))
        let distance = abs(s/l)
        return distance
    }
    
    func distaceVectorFrom(_ line:[CGPoint]) -> CGFloat {
        let point1 = line[0]
        let point2 = line[1]
        let s = (self.x-point1.x)*(point1.y-point2.y)-(point1.x-point2.x)*(self.y-point1.y)
        let l = sqrt(pow(point1.x-point2.x,2)+pow(point1.y-point2.y,2))
        let distance = s/l
        return distance
    }
    
}

extension CGFloat {
    func sign() -> CGFloat {
      (self >= 0.0) ? 1.0 : -1.0
    }
}

extension CGPoint: ExpressibleByArrayLiteral {
    
    public init(arrayLiteral elements: CGFloat...) {
        self.init()
        if elements.count > 1 {
            self.x = elements[0]
            self.y = elements[1]
        } else {
            self.x = 0
            self.y = 0
        }
    }
    
    
    static func - (left:CGPoint,right:CGPoint) -> CGPoint {
        CGPoint(x: left.x-right.x,y: left.y-right.y)
    }

    static func -= (left:inout CGPoint,right:CGPoint) {
        left = CGPoint(x: left.x-right.x,y: left.y-right.y)
    }

    static func + (left:CGPoint,right:CGPoint) -> CGPoint {
        CGPoint(x: left.x+right.x,y: left.y+right.y)
    }

    static func += (left:inout CGPoint,right:CGPoint) {
        left = CGPoint(x: left.x+right.x,y: left.y+right.y)
    }

    static func * (left:CGPoint,right:CGFloat) -> CGPoint {
        CGPoint(x: left.x*right,y: left.y*right)
    }

    static func / (left:CGPoint,right:CGFloat) -> CGPoint {
        CGPoint(x: left.x/right,y: left.y/right)
    }
        
}

extension CGAffineTransform {
    
    @inline(__always)
    var invert:CGAffineTransform {
        self.inverted()
    }
    
    static func translate(_ x:CGFloat,y:CGFloat) -> CGAffineTransform {
        CGAffineTransform(translationX: x, y: y)
    }
    
    static func rotate(_ angle:CGFloat) -> CGAffineTransform {
        CGAffineTransform(rotationAngle: angle)
    }
    
    static func + (lhs:CGAffineTransform,rhs:CGAffineTransform) -> CGAffineTransform {
        lhs.concatenating(rhs)
    }
}


extension Int {
    var cgFloat: CGFloat {
        CGFloat(self)
    }
}

extension CGFloat {
    var int: Int {
        Int(self)
    }
    
    var float: Float {
        Float(self)
    }
}
