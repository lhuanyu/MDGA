//
//  AutoPilot.swift
//  PeachTree
//
//  Created by LuoHuanyu on 2022/3/15.
//  Copyright © 2022 LuoHuanyu. All rights reserved.
//

import DJISDK
import UIKit
import CoreLocation

@objcMembers
open class AutoPilot: NSObject, WaypointMissionOperator {

    public override init() {
        super.init()
    }
    
    //MARK: - DJI
    
    private var keyManager: DJIKeyManager? {
        DJISDKManager.keyManager()
    }
    
    private func bindSDKKeys() {
        DJISDKManager.stopListening(onProductConnectionUpdatesOfListener: self)
        DJISDKManager.startListeningOnProductConnectionUpdates(withListener: self) { product in
            if let _ = product as? DJIAircraft {
                self.onAircraftConnected(true)
            } else {
                self.onAircraftConnected(false)
            }
        }
        
        keyManager?.stopAllListening(ofListeners: self)
        if let key = DJIFlightControllerKey(param: DJIFlightControllerParamIsGoingHome) {
            keyManager?.startListeningForChanges(on: key, withListener: self, andUpdate: { oldValue, newValue in
                if let boolValue = newValue?.boolValue {
                    self.isGoingHome = boolValue
                }
            })
        }
        
        if let key = DJIFlightControllerKey(param: DJIFlightControllerParamIsFlying) {
            keyManager?.startListeningForChanges(on: key, withListener: self, andUpdate: { oldValue, newValue in
                if let boolValue = newValue?.boolValue {
                    self.isFlying = boolValue
                }
            })
        }
    }
    
    private var aircraft: DJIAircraft? {
        DJISDKManager.product() as? DJIAircraft
    }
    
    private var controller: DJIFlightController? {
        aircraft?.flightController
    }
    
    public var isSupported: Bool {
        guard let model = DJISDKManager.product()?.model else {
            return false
        }
        switch model {
        case DJIAircraftModelNameMavicAir2:
            return true
        case DJIAircraftModelNameMavicMini:
            return true
        case DJIAircraftModelNameDJIMini2:
            return true
        case DJIAircraftModelNameDJIMiniSE:
            return true
        case DJIAircraftModelNameDJIAir2S:
            return true
        case DJIAircraftModeNameOnlyRemoteController:
            return false
        default:
            return shouldSupportAllModels
        }
    }
    
    public var shouldSupported: Bool {
        guard let aircraft = DJISDKManager.product()?.model else {
            return false
        }
        switch aircraft {
        case DJIAircraftModelNameMavicAir2:
            return true
        case DJIAircraftModelNameMavicMini:
            return true
        case DJIAircraftModelNameDJIMini2:
            return true
        case DJIAircraftModelNameDJIMiniSE:
            return true
        case DJIAircraftModelNameDJIAir2S:
            return true
        case DJIAircraftModeNameOnlyRemoteController:
            return false
        default:
            return false
        }
    }
    
    public var shouldSupportAllModels = false {
        didSet {
            ///Switch autopilot when drone is connected.
            if let _ = controller, !shouldSupported {
                if shouldSupportAllModels {///global on, setup forcely.
                    setup()
                } else {///global off,  reset for other models.

                }
            }
        }
    }
    
    private var isVirtualStickControlModeEnabled: Bool {
        keyManager?.getValueFor(DJIFlightControllerKey(param: DJIFlightControllerParamVirtualStickControlModeEnabled)!)?.boolValue ?? false
    }
    
    public var isAutoPilotAvailable: Bool {
        guard let controller = controller else {
            return false
        }
        
        guard controller.isVirtualStickControlModeAvailable() else {
            return false
        }
        
        guard isVirtualStickControlModeEnabled else {
            return false
        }
        
        return controller.verticalControlMode == .position &&
        controller.rollPitchControlMode == .velocity &&
        controller.yawControlMode == .angle &&
        controller.rollPitchCoordinateSystem == .body
    }
    
    private var isGoingHome: Bool = false {
        didSet {
            if isGoingHome && self.currentState.isExcuting {
                stopMission(completion: nil)
            }
        }
    }
    
    private var isLanding: Bool {
        keyManager?.getValueFor(DJIFlightControllerKey(param: DJIFlightControllerParamIsLanding)!)?.boolValue ?? false
    }
    
    private var isFlying: Bool  = false {
        didSet {
            guard !isFlying && currentState.isExcuting else {
                return
            }
            stopMission(completion: nil)
        }
    }
    
    public func setup() {
        if isAutoPilotAvailable {
            return
        }
        
        guard isSupported else {
            return
        }
        
        
        guard let controller = controller else {
            return
        }
        
        controller.verticalControlMode = .position
        controller.rollPitchControlMode = .velocity
        controller.yawControlMode = .angle
        controller.rollPitchCoordinateSystem = .body
        
        if isDisconnectedWhenExecuting {
            if isGoingHome || isLanding || !isFlying {
                stopMission(completion: nil)
            } else if isAutoPilotAvailable {
                displayLink?.isPaused = false
            } else {
                controller.setVirtualStickModeEnabled(true, withCompletion: { error in
                    if let _ = error {
                        self.stopMission(completion: nil)
                    } else {
                        self.displayLink?.isPaused = false
                    }
                })
            }
            isDisconnectedWhenExecuting = false
        } else {
            bindSDKKeys()
            currentState = .readyToUpload
        }
    }
    
    private func onAircraftConnected(_ connected: Bool) {
        guard !connected else {
            return
        }
        
        guard let mission = loadedMission else {
            return
        }
        
        guard self.currentState  == .executing else {
            self.currentState = .disconnected
            return
        }
        
        if mission.exitMissionOnRCSignalLost {
            self.stopMission(completion: nil)
        } else {
            self.isDisconnectedWhenExecuting = true
            self.pauseMission(completion: nil)
        }
    }
    
    private var isDisconnectedWhenExecuting = false
    
    public var isAutoPilotOn: Bool {
        guard let displayLink = displayLink, !displayLink.isPaused else {
            return false
        }
        return isAutoPilotAvailable
    }
    
    //MARK: - Waypoint Mission Operator
    
    @Published
    public var currentState: DJIWaypointMissionState = .unknown
    
    public func load(_ mission: DJIWaypointMission) -> Error? {
        reset()
        if let error = mission.checkValidity() {
            return error
        } else {
            loadedMission = mission
            autoFlightSpeed = mission.autoFlightSpeed
            repeatTimes = max(1, Int(mission.repeatTimes))
            return nil
        }
    }
    
    public func uploadMission(completion: DJICompletionBlock?) {
        guard let controller = controller else {
            print("flightController is nil.")
            return
        }
        currentState = .uploading
        controller.setVirtualStickModeEnabled(true, withCompletion: { error in
            if let error = error {
                completion?(error)
                self.currentState = .readyToUpload
                print("Enable Virtual Stick Mode: \(error)")
            } else {
                print("Enable Virtual Stick Mode Success.")
                self.setupVirtualStickMode()
                self.setupDisplayLink()
                completion?(nil)
                self.currentState = .readyToExecute
            }
        })
    }
    
    private func setupVirtualStickMode() {
        guard let controller = controller else {
            return
        }
        controller.verticalControlMode = .position
        controller.rollPitchControlMode = .velocity
        controller.yawControlMode = .angle
        controller.rollPitchCoordinateSystem = .body
    }
    
    private func setupDisplayLink() {
        displayLink?.invalidate()
        switch headingMode {
        case .track:
            displayLink = CADisplayLink(target: self, selector: #selector(freeMode))
        case .free:
            displayLink = CADisplayLink(target: self, selector: #selector(freeMode))
        case .hotpoint:
            displayLink = CADisplayLink(target: self, selector: #selector(hotpointMode))
        }
        
        displayLink?.preferredFramesPerSecond = 40
        displayLink?.add(to: .main, forMode: .common)
        displayLink?.isPaused = true
    }
    
    public private(set) var loadedMission: DJIWaypointMission? {
        didSet {
            if pointOfInterest != nil || usingWaypointHeading {
                headingMode = .free
            } else {
                headingMode = .track
            }
        }
    }
    
    private var gpsSignalLevel: DJIGPSSignalLevel {
        if let rawValue = keyManager?.getValueFor(DJIFlightControllerKey(param: DJIFlightControllerParamGPSSignalStatus)!)?.unsignedCharValue {
            return DJIGPSSignalLevel(rawValue: rawValue) ?? .levelNone
        }
        return .levelNone
    }
    
    public func startMission(completion: DJICompletionBlock? = nil) {
        guard let mission = loadedMission else {
            currentState = .readyToUpload
            return
        }
        guard isAutoPilotAvailable else {
            currentState = .readyToUpload
            return
        }
        guard gpsSignalLevel.isRecordHomePointAvailable else {
            currentState = .readyToExecute
            let code = DJISDKMissionError.missionErrorGPSSignalWeak.rawValue
            if let error = NSError.djisdkMissionError(forCode: code) {
                completion?(error)
            }
            return
        }
        
        if isLanding {
            currentState = .readyToExecute
            let code = DJISDKMissionError.missionErrorAircraftLanding.rawValue
            if let error = NSError.djisdkMissionError(forCode: code) {
                completion?(error)
            }
            return
        }
        
        if isGoingHome {
            currentState = .readyToExecute
            let code = DJISDKMissionError.missionErrorAircraftGoingHome.rawValue
            if let error = NSError.djisdkMissionError(forCode: code) {
                completion?(error)
            }
            return
        }
        
        controlData = DJIVirtualStickFlightControlData()
        waypoints = mission.allWaypoints()
        
        if isFlying {
            self.isClimbing = true
            self.displayLink?.isPaused = false
            self.moveToNextWaypoint()
            completion?(nil)
        } else {
            controller?.startTakeoff(completion: { error in
                if let error = error {
                    print(error)
                    self.currentState = .readyToExecute
                } else {
                    self.isClimbing = true
                    self.displayLink?.isPaused = false
                    self.moveToNextWaypoint()
                }
                completion?(error)
            })
        }
    }
        
    public func stopMission(completion: DJICompletionBlock?) {
        controller?.setVirtualStickModeEnabled(false, withCompletion: { error in
            if let error = error {
                print("Disable Virtual Stick Mode: \(error)")
            } else {
                print("Disable Virtual Stick Mode Success.")
            }
        })
        setGimbalPitch(0)
        if isRecording {
            camera?.stopRecordVideo(completion: nil)
        }
        reset()
        completion?(nil)
    }
    
    private func reset() {
        displayLink?.invalidate()
        displayLink = nil
        index = -1
        loadedMission = nil
        actionHeading = nil
        actionGimbalPitch = nil
        waypoint = nil
        lastWaypoint = nil
        actionIndex = 0
        controlData = nil
        isTurning = false
        isClimbing = false
        coordinate = nil
        flag = 0
        executionProgress = nil
        lastShootPhotoCoordinate = nil
        isDisconnectedWhenExecuting = false
        currentState = .readyToUpload
        repeatTimes = 1
        headingClockwise = true
        distanceBetween = nil
        isCircleCaptured = false
        radius = 0
        targetAngle = 0
        angleBetween = 0
        shootInInterval = true
        headingMode = .track
        isCurveTurning = false
        isCurveTurnNeeded = false
        isCurveTurnClockwise = false
        isApproachingWaypoint = false
        actionState = .idle
    }
    
    public func pauseMission(completion: DJICompletionBlock?) {
        displayLink?.isPaused = true
        currentState = .executionPaused
        completion?(nil)
    }
    
    public func resumeMission(completion: DJICompletionBlock?) {
        displayLink?.isPaused = false
        completion?(nil)
    }
    
    //MARK: - Control Loop
    
    private var displayLink: CADisplayLink?
    
    private var controlData: DJIVirtualStickFlightControlData?
    
    private var height: Float? {
        controlData?.verticalThrottle
    }
    
    private var pitchSpeed: Float? {
        controlData?.pitch
    }
    
    private var rollSpeed: Float? {
        controlData?.roll
    }
    
    private var decelerationFactor: Float = 2.0
    
    private var speed: Float? {
        if let roll = rollSpeed, let pitch = pitchSpeed {
            return sqrt(roll*roll + pitch*pitch)
        } else if let rollSpeed = rollSpeed {
            return rollSpeed
        } else if let pitchSpeed = pitchSpeed {
            return pitchSpeed
        }
        return nil
    }
    
    private var autoFlightSpeed: Float = 0 {
        didSet {
            if autoFlightSpeed > 10 {
                decelerationFactor = 2.5
            } else {
                decelerationFactor = 2.0
            }
        }
    }
    
    @discardableResult
    private func controlSpeed() -> Bool {
        guard let speed = speed, speed != 0 else {
            return false
        }
        
        if isCurveTurning {
            curveTurnSpeed()
        } else {
            if isCurveTurnNeeded {
                curveTurnAppoachingSpeed()
            } else {
                normalAppoachingSpeed()
            }
        }
        return true
    }
    
    private func curveTurnSpeed() {
        if isCurveTurnCourseReached {
            isCurveTurning = false
            moveToNextWaypoint()
        } else {
            holdSpeed(turningSpeed)
        }
    }
    
    private func curveTurnAppoachingSpeed() {
        if targetDistance < turningDistance {
            isCurveTurning = true
            holdSpeed(turningSpeed)
        } else if targetDistance < turningDistance + curveTurnDecelarationDistace {
            holdSpeed(turningSpeed)
        } else {
            holdSpeed(autoFlightSpeed)
        }
    }
    
    private func normalAppoachingSpeed() {
        if targetDistance < 0.5 {
            holdSpeed(0)
        } else if targetDistance < autoFlightSpeed * decelerationFactor || isApproachingWaypoint {
            isApproachingWaypoint = true
            holdSpeed(max(1, targetDistance / decelerationFactor))
        } else if !isApproachingWaypoint {
            holdSpeed(autoFlightSpeed)
        }
    }
    
    private func checkPhotoDistance() {
        if let lastShootPhotoCoordinate = lastShootPhotoCoordinate,
           let aircraftCoordinate = aircraftCoordinate {
            let distance = lastShootPhotoCoordinate.distance(to: aircraftCoordinate)
            if distance + 0.5 > shootPhotoDistance {
                shootPhoto()
                self.lastShootPhotoCoordinate = aircraftCoordinate
            }
        }
    }
    
    private var isApproachingWaypoint = false
    
    private func holdSpeed(_ speed: Float) {
        guard let course = targetCourseHeading?.normalDegree,
              let heading = aircraftHeading?.normalDegree else {
            return
        }
        
        trackOffSet = caculateTrackDelta()
        let trackSpeed = speed == 0 ? 0 : caculateTrackSpeed()
        
        let angle = (course-heading).radians
        let roll = speed * cos(angle) + trackSpeed * sin(-angle)
        let pitch = speed * sin(angle) + trackSpeed * cos(-angle)
        
        
        holdRoll(roll)
        holdPitch(pitch)
    }
    
    private func holdPitch(_ speed: Float) {
        controlData?.pitch = speed
    }
    
    private func holdRoll(_ speed: Float) {
        controlData?.roll = speed
    }
    
    private func holdHeight(_ height: Float) {
        controlData?.verticalThrottle = height
    }
    
    private var heading: Float? {
        controlData?.yaw
    }
    
    private func holdHeading(_ heading: Float) {
        controlData?.yaw = heading
    }
    
    private func go(to coordinate: CLLocationCoordinate2D) {
        self.coordinate = coordinate
    }
    
    @inline(__always)
    private func sendCommand() {
        if let controlData = controlData {
            controller?.send(controlData, withCompletion: nil)
        }
    }
    
    private var flag = 0
    
    //MARK: - Free Mode
    
    func freeMode() {
        switch flag {
        case 0:
            flag = 1
            sendCommand()
        case 1:
            flag = 2
            updateExecutionState()
            checkPhotoDistance()
        case 2:
            flag = 3
            if actionState == .executing {
                break
            }
            controlHeading()///send command
        case 3:
            flag = 0
            if controlSpeed() {
                return
            }
            
            if controlClimb() {
                return
            }
            
            updateActionState()
        default:
            break
        }
    }
    
    private func updateActionState() {
        switch actionState {
        case .idle:
            if !isTurning && isTargetHeightReached {
                if isApproachingWaypoint {
                    actionState = .ready
                } else {
                    actionState = .restoring
                }
            }
            if isTargetHeadingReached {
                isTurning = false
            }
        case .ready:
            if starActions() {
                actionState = .executing
            } else {
                actionState = .finished
            }
        case .executing:
            checkActionState()
        case .finished:
            actionState = .restoring
            moveToNextWaypoint()
        case .restoring:
            if isTargetHeadingReached {
                holdSpeed(autoFlightSpeed)
                isTurning = false
                isApproachingWaypoint = false
                actionState = .idle
            }
        }
    }
        
    private func updateExecutionState() {
        if index > -1 {
            currentState = .executing
        }
    }
    
    private func checkActionState() {
        guard let waypoint = waypoint else {
            return
        }
        if let actionHeading = actionHeading {
            if isAircraftReachedHeading(actionHeading) {
                self.actionHeading = nil
                DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                    self.nextAction(at: waypoint)
                }
            }
        } else if let actionGimbalPitch = actionGimbalPitch {
            if abs(gimbalPitch - actionGimbalPitch) < 0.5 {
                self.actionGimbalPitch = nil
                DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                    self.nextAction(at: waypoint)
                }
            }
        }
    }
    
    private func controlHeading() {
        if let targetHeading = targetHeading {
            holdHeading(targetHeading)
            controlSpeed()
            sendCommand()
        }
    }
    
    private func controlClimb() -> Bool {
        if isClimbing {
            if isTargetHeightReached {
                isClimbing = false
                if let loadedMission = loadedMission,
                   loadedMission.rotateGimbalPitch,
                   let gimbalPitch = waypoints.first?.gimbalPitch {
                    setGimbalPitch(gimbalPitch.double)
                }
                return false
            } else {
                return true
            }
        }
        return false
    }

    //MARK: - Hotpoint Mode
    
    func hotpointMode() {
        switch flag {
        case 0:
            flag = 1
            sendCommand()
        case 1:
            flag = 2
            if index > -1 {
                currentState = .executing
            }
            passWaypoint()
        case 2:
            flag = 3
            if let targetHeading = targetHeading {
                holdHeading(targetHeading)
                sendCommand()
            }
        case 3:
            flag = 0
            guard let speed = speed else {
                break
            }
            if speed == 0 {
                if isClimbing {
                    if isTargetHeightReached {
                        isClimbing = false
                        if let loadedMission = loadedMission,
                           loadedMission.rotateGimbalPitch,
                           let gimbalPitch = waypoints.first?.gimbalPitch {
                            setGimbalPitch(gimbalPitch.double)
                        }
                    } else {
                        break
                    }
                }
                if isTargetHeadingReached {
                    holdSpeed(autoFlightSpeed)
                }
            } else {
                if isCircleCaptured {
                    holdCircle(radius)
                } else if targetDistance < 0.5 {
                    isCircleCaptured = true
                    holdCircle(radius)
                } else if targetDistance < autoFlightSpeed * decelerationFactor || isApproachingWaypoint {
                    isApproachingWaypoint = true
                    holdSpeed(max(1, targetDistance / decelerationFactor))
                } else {
                    holdSpeed(autoFlightSpeed)
                }
            }
        default:
            break
        }
    }
    
    private var radius: Float = 0
    
    private var clockwise = true
    
    private var isCircleCaptured = false {
        didSet {
            if isCircleCaptured, let pointOfInterest = pointOfInterest {
                let target = pointOfInterest.cgPoint
                let current = waypoints[0].coordinate.cgPoint
                let heading = (CGLine(point1: current, point2: target).angle - .pi * 0.5).degrees.normalDegree
                targetAngle = heading
            }
        }
    }
    
    private var angleBetween: CGFloat = 0
    
    private var shootInInterval = true
    
    private var targetAngle: CGFloat = 0
    
    private var isTargetAngleReached: Bool {
        guard let aircraftCoordinate = aircraftCoordinate else {
            return false
        }
        
        guard let pointOfInterest = pointOfInterest else {
            return false
        }
        
        let target = pointOfInterest.mapPoint.cgPoint
        let current = aircraftCoordinate.mapPoint.cgPoint
        let angle = (CGLine(point1: current, point2: target).angle - .pi * 0.5).degrees.normalDegree
        
        if index == 0 {
            if targetDistance < 2 {
                return true
            } else {
                return abs(targetAngle - angle) < 4
            }
        }
        
        if clockwise {
            var angle = ceil(angle).int
            var targetAngle = floor(targetAngle).int
            if angle == 360 {
                angle = 0
            }
            if abs(targetAngle - angle) > 180 {
                if angle < targetAngle {
                    angle += 360
                } else {
                    targetAngle += 360
                }
            }
            return angle >= targetAngle
        } else {
            var angle = floor(angle).int
            var targetAngle = ceil(targetAngle).int
            if targetAngle == 360 {
                targetAngle = 0
            }
            if abs(targetAngle - angle) > 180 {
                if angle < targetAngle {
                    angle += 360
                } else {
                    targetAngle += 360
                }
            }
            return angle <= targetAngle
        }
    }
    
    private func holdCircle(_ radius: Float) {
        guard let targetHeading = targetHeading,
              let aircraftCoordinate = aircraftCoordinate,
              let pointOfInterest = pointOfInterest else {
            return
        }
        holdHeading(targetHeading)
        holdCirclePitch(autoFlightSpeed)
        let radiusDelta = radius - aircraftCoordinate.distance(to: pointOfInterest).float
        let sign: Float = radiusDelta > 0 ? 1 : -1
        if abs(radiusDelta) > 5 {
            holdCircleRoll(5 * sign)
        } else {
            holdCircleRoll(radiusDelta)
        }
    }
    
    private lazy var holdCirclePitch: (Float) -> Void = self.holdPitch
    
    private lazy var holdCircleRoll: (Float) -> Void = self.holdRoll
    
    private var lastCoordinate: CLLocationCoordinate2D?
    
    private var coordinate: CLLocationCoordinate2D?
    
    private var aircraftLocation: CLLocation? {
        keyManager?.getValueFor(DJIFlightControllerKey(param: DJIFlightControllerParamAircraftLocation)!)?.value as? CLLocation
    }
    
    private var aircraftCoordinate: CLLocationCoordinate2D? {
        aircraftLocation?.coordinate
    }
    
    private var aircraftAttitude: DJISDKVector3D? {
        keyManager?.getValueFor(DJIFlightControllerKey(param: DJIFlightControllerParamAttitude)!)?.value as? DJISDKVector3D
    }
    
    private var aircraftAltitude: Double {
        keyManager?.getValueFor(DJIFlightControllerKey(param: DJIFlightControllerParamAltitudeInMeters)!)?.doubleValue ?? 0
    }
    
    //MARK: - State
    
    enum ControlProgram {
        case idle
        case climb
        case normalTurn
        case curveTurn
        case executingAction
        case normal
    }
    
    private(set) var program: ControlProgram = .idle
    
    private var repeatTimes = 1
    
    private var isClimbing = false
    
    private var isTurning = false
    
    public var latestExecutionProgress: DJIWaypointExecutionProgress? {
        return executionProgress
    }
    
    var executionProgress: WaypointExcutionProgress?
    
    private var index = -1
    
    private var waypoints = [DJIWaypoint]() {
        didSet {
            coordinate = nil
            index = -1
        }
    }
    
    var lastWaypoint: DJIWaypoint?
    
    var waypoint: DJIWaypoint?
    
    @discardableResult
    func moveToNextWaypoint() -> Bool {
        guard let mission = loadedMission else {
            return false
        }
        index += 1
        executionProgress?.isReached = true
        lastShootPhotoCoordinate = nil
        lastCoordinate = waypoint?.coordinate ?? aircraftCoordinate
        if index < waypoints.count {
            let waypoint = waypoints[index]
            lastWaypoint = self.waypoint
            self.waypoint = waypoint
            go(to: waypoint.coordinate)
            holdHeight(waypoint.altitude)
            if mission.rotateGimbalPitch && index > 0 {
                print("Set Waypoint Gimbal Pitch: \(waypoint.gimbalPitch)")
                setGimbalPitch(waypoint.gimbalPitch.double)
            }
            if mission.headingMode == .usingWaypointHeading {
                updateHeadings()
            }
            
            if mission.flightPathMode == .curved {
                if prepareForCurveTurn(waypoint) {
                    isCurveTurnNeeded = true
                } else {
                    isCurveTurnNeeded = false
                    isTurning = true
                }
            } else {
                isCurveTurnNeeded = false
                isTurning = true
            }
            
            if let lastWaypoint = lastWaypoint, lastWaypoint.shootPhotoDistanceInterval > 0 {
                lastShootPhotoCoordinate = lastWaypoint.coordinate
                shootPhotoDistance = lastWaypoint.shootPhotoDistanceInterval.double
            }
            
            let progress = WaypointExcutionProgress()
            progress.index = index
            progress.isReached = false
            executionProgress = progress
            return true
        } else {
            repeatTimes -= 1
            if repeatTimes == 0  {
                let finished = finish()
                if finished {
                    switch mission.finishedAction {
                    case .goHome:
                        controller?.startGoHome(completion: nil)
                    case .autoLand:
                        controller?.startLanding(completion: nil)
                    case .noAction:
                        break
                    default:
                        break
                    }
                }
                return false
            } else {
                index = -1
                lastWaypoint = nil
                moveToNextWaypoint()
                return true
            }
        }
    }
    
    private func passWaypoint() {
        guard let loadedMission = loadedMission else {
            return
        }
        guard isCircleCaptured else {
            return
        }
        guard let pointOfInterest = pointOfInterest else {
            return
        }
        if isTargetAngleReached {
            if shootInInterval {
                shootPhoto()
            }
            index += 1
            executionProgress?.isReached = true
            if index < waypoints.count {
                let target = pointOfInterest.cgPoint
                let current = waypoints[index].coordinate.cgPoint
                coordinate = waypoints[index].coordinate
                let heading = (CGLine(point1: current, point2: target).angle - .pi * 0.5).degrees.normalDegree
                targetAngle = heading
                holdHeight(waypoints[index].altitude)
                let progress = WaypointExcutionProgress()
                progress.index = index
                progress.isReached = false
                progress.isMute = true
                executionProgress = progress
            } else {
                repeatTimes -= 1
                if repeatTimes == 0  {
                    let finished = finish()
                    if finished {
                        switch loadedMission.finishedAction {
                        case .goHome:
                            controller?.startGoHome(completion: nil)
                        case .autoLand:
                            controller?.startLanding(completion: nil)
                        default:
                            break
                        }
                    }
                } else {
                    index = 0
                    let target = pointOfInterest.cgPoint
                    let current = waypoints[0].coordinate.cgPoint
                    coordinate = waypoints[0].coordinate
                    let heading = (CGLine(point1: current, point2: target).angle - .pi * 0.5).degrees.normalDegree
                    targetAngle = heading
                    holdHeight(waypoints[index].altitude)
                    let progress = WaypointExcutionProgress()
                    progress.index = 0
                    progress.isReached = false
                    progress.isMute = true
                    executionProgress = progress
                }
            }
        }
    }
    
    var shouldMoveToNextMission: Bool {
        false
    }
    
    @discardableResult
    func finish() -> Bool {
        if shouldMoveToNextMission {
            reset()
            return false
        } else {
            stopMission(completion: nil)
            return true
        }
    }
    
    private var pointOfInterest: CLLocationCoordinate2D? {
        if let poi = loadedMission?.pointOfInterest, poi.isValid {
            return poi
        }
        return nil
    }
    
    //MARK: - Curve Turn
    
    private var isCurveTurning = false
    
    private var isCurveTurnNeeded = false
    
    private var isCurveTurnClockwise = true
    
    private var startCourseHeading = Float(0)
    
    private var endCourseHeading = Float(0)
    
    private var endCourseCoordinate = CLLocationCoordinate2D()
    
    private var curveTurnDecelarationDistace: Float = 0
        
    private func prepareForCurveTurn(_ wayponit: DJIWaypoint) -> Bool {
        if index > 0 && index < waypoints.count - 1 && wayponit.cornerRadiusInMeters > 0.2 {
            guard let lastCoordinate = lastCoordinate else {
                return false
            }
            
            turningSpeed = max(1, min(wayponit.cornerRadiusInMeters * 0.3, autoFlightSpeed))

            let next = waypoints[index+1].coordinate.cgPoint
            let current = wayponit.coordinate.cgPoint
            let prev = lastCoordinate.cgPoint
            let radius = wayponit.cornerRadiusInMeters.double * MKMapPointsPerMeterAtLatitude(wayponit.coordinate.latitude)
            let info = arcInfo(previous: prev, current: current, next: next, radius: radius)

            isCurveTurnClockwise = info.clockwise
            turningCenterCoordinate = info.center.mapPoint.coordinate
            let angle = abs(info.endAngle - info.startAngle) * 0.5
            let factor = sin(angle).float
            print("factor: \(factor)")
            turningDistance = turningCenterCoordinate.distance(to: wayponit.coordinate).float * factor
            print("turningDistance: \(turningDistance)")
            
            let currentLegLength = lastCoordinate.distance(to: wayponit.coordinate).float
            let nextLegLength = wayponit.coordinate.distance(to: waypoints[index+1].coordinate).float
            
            if turningDistance > nextLegLength ||  turningDistance > currentLegLength {
                return false
            }
            
            endCourseCoordinate = waypoints[index+1].coordinate
            startCourseHeading = heading(from: lastCoordinate, to: wayponit.coordinate).float
            endCourseHeading = heading(from: wayponit.coordinate, to: endCourseCoordinate).float
            
            if isCurveTurnClockwise {
                holdCircleRoll = { self.holdPitch(-$0) }
                holdCirclePitch = holdRoll
            } else {
                holdCircleRoll = holdPitch
                holdCirclePitch = holdRoll
            }
            
            print("delta angle: \(angle.degrees * 2)")

            if angle.degrees < 5 {
                curveTurnDecelarationDistace = autoFlightSpeed
            } else {
                curveTurnDecelarationDistace = autoFlightSpeed + 5.0 * autoFlightSpeed / 15.0
            }
            return true
        } else {
            return false
        }
    }
    
    private var turningCenterCoordinate = CLLocationCoordinate2D()
    
    private var turningDistance = Float(0.0)
            
    private var turningHeading: Float? {
        guard let aircraftCoordinate = aircraftCoordinate else {
            return aircraftHeading
        }
        var heading = heading(from: aircraftCoordinate, to: turningCenterCoordinate).float
        if isCurveTurnClockwise {
            heading = (heading - 90).headingDegree
            
            let normalHeading = heading.normalDegree
            let normalStartHeading = startCourseHeading.normalDegree
            if normalStartHeading < 355 {
                if normalHeading < normalStartHeading {
                    return startCourseHeading
                } else {
                    startCourseHeading = heading
                }
            }
        } else {
            heading = (heading + 90).headingDegree
            
            let normalHeading = heading.normalDegree
            let normalStartHeading = startCourseHeading.normalDegree
            if normalStartHeading > 5 {
                if normalHeading > normalStartHeading {
                    return startCourseHeading
                } else {
                    startCourseHeading = heading
                }
            }
        }
        return heading
    }
    
    private var isTurningFinished: Bool {
        guard let aircraftHeading = aircraftHeading else {
            return false
        }
        if abs(endCourseHeading.normalDegree - aircraftHeading.normalDegree) < 2 {
            return true
        }
        return false
    }
    
    private var isCurveTurnCourseReached: Bool {
        if let aircraftCoordinate = aircraftCoordinate {
            let heading = heading(from: aircraftCoordinate, to: endCourseCoordinate).float
            let delta = abs(endCourseHeading.normalDegree - heading.normalDegree)
            print("course delta: \(delta)")
            if delta < 1 || delta > 359 {
                return true
            }
        }
        return false
    }
    
    private var turningSpeed = Float(0.0)
    
    private func curveTurnRadiusDelta() -> Float {
        guard let waypoint = waypoint else {
            return 0
        }
        guard let aircraftCoordinate = aircraftCoordinate else {
            return 0
        }
        let delta = waypoint.cornerRadiusInMeters - aircraftCoordinate.distance(to: turningCenterCoordinate).float
        if isCurveTurnClockwise {
            return -delta
        } else {
            return delta
        }
    }
    
    //MARK: - Track
    
    private var trackOffSet: Float = 0
    
    private func caculateTrackDelta() -> Float {
        if speed == 0 {
            return 0
        }
        
        if isCurveTurning {
            return curveTurnRadiusDelta()
        }
        
        guard let aircraftCoordinate = aircraftCoordinate else {
            return 0
        }
        
        guard let coordinate = coordinate,
              let lastCoordinate = lastCoordinate else {
            return 0
        }
        
        let distance = aircraftCoordinate.cgPoint.distaceVectorFrom([coordinate.cgPoint, lastCoordinate.cgPoint]) * MKMetersPerMapPointAtLatitude(coordinate.latitude)
        return distance.float
    }
    
    private func caculateTrackSpeed() -> Float {
        if abs(trackOffSet) > 5 {
            let sign: Float = trackOffSet > 0 ? 1 : -1
            return sign * 5
        }
        return trackOffSet
    }
    
    //MARK: - Heading
    
    enum HeadingMode {
        case track
        case free
        case hotpoint
    }
    
    private var headingMode = HeadingMode.track
        
    private var hotpointHeading: DJIHotpointHeading = .towardHotpoint {
        didSet {
            switch hotpointHeading {
            case .towardHotpoint:
                if clockwise {
                    holdCircleRoll =  { self.holdRoll(-$0) }
                    holdCirclePitch = { self.holdPitch(-$0) }
                } else {
                    holdCircleRoll =  { self.holdRoll(-$0) }
                    holdCirclePitch = holdPitch
                }
            case .alongCircleLookingForward:
                if clockwise {
                    holdCircleRoll = { self.holdPitch(-$0) }
                    holdCirclePitch = holdRoll
                } else {
                    holdCircleRoll = holdPitch
                    holdCirclePitch = holdRoll
                }
            case .alongCircleLookingBackward:
                if clockwise {
                    holdCircleRoll = holdPitch
                    holdCirclePitch =  { self.holdRoll(-$0) }
                } else {
                    holdCircleRoll = { self.holdPitch(-$0) }
                    holdCirclePitch =  { self.holdRoll(-$0) }
                }
            case .awayFromHotpoint:
                if clockwise {
                    holdCircleRoll =  holdRoll
                    holdCirclePitch = holdPitch
                } else {
                    holdCircleRoll =  holdRoll
                    holdCirclePitch = { self.holdPitch(-$0) }
                }
            case .controlledByRemoteController:
                break
            case .usingInitialHeading:
                break
            @unknown default:
                break
            }
        }
    }
    
    private var usingWaypointHeading: Bool {
        guard let loadedMission = loadedMission else {
            return false
        }
        return loadedMission.headingMode == .usingWaypointHeading
    }
    
    private var lastTargetHeading: Float?
    
    private var targetHeading: Float? {
        guard let aircraftCoordinate = aircraftCoordinate else {
            return nil
        }
        if headingMode == .hotpoint, let pointOfInterest = pointOfInterest {
            var current = aircraftCoordinate
            if pointOfInterest.distance(to: aircraftCoordinate) < 5, let coordinate = coordinate {
                current = coordinate
            }
            let heading = heading(from: current, to: pointOfInterest)
            
            switch hotpointHeading {
            case .towardHotpoint:
                return heading.float
            case .alongCircleLookingForward:
                return clockwise ? (heading - 90).headingDegree.float : (heading + 90).headingDegree.float
            case .alongCircleLookingBackward:
                return clockwise ? (heading + 90).headingDegree.float : (heading - 90).headingDegree.float
            case .awayFromHotpoint:
                return (heading - 180).headingDegree.float
            case .controlledByRemoteController:
                fatalError()
            case .usingInitialHeading:
                fatalError()
            @unknown default:
                fatalError()
            }
        } else if let pointOfInterest = pointOfInterest {
            var current = aircraftCoordinate
            if pointOfInterest.distance(to: aircraftCoordinate) < 5, let coordinate = coordinate {
                current = coordinate
            }
            let heading = heading(from: current, to: pointOfInterest)
            return heading.float
        } else if usingWaypointHeading {
            
            if headingBetween == 0 {
                return endHeading.headingDegree
            }
            
            guard let distanceBetween = distanceBetween else {
                return endHeading.headingDegree
            }
            
            let ratio = max(0, 1 - targetDistance / distanceBetween)
            let delta = headingBetween * ratio
            let target = (startHeading + delta).headingDegree
            return target
        } else if isCurveTurning {
            return turningHeading
        } else if let coordinate = coordinate {
            if coordinate.distance(to: aircraftCoordinate) < 1 {
                return lastTargetHeading
            }
            let heading = heading(from: aircraftCoordinate, to: coordinate).float
            lastTargetHeading = heading
            return heading
        }
        return nil
    }
    
    private func heading(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D) -> CGFloat {
        let heading = (CGLine(point1: to.cgPoint, point2: from.cgPoint).angle - .pi * 0.5).degrees
        return heading.headingDegree
    }
    
    private func updateHeadings() {
        distanceBetween = nil
        startHeading = aircraftHeading ?? lastWaypoint?.heading.float ?? 0
        startHeading = startHeading.normalDegree ///0~360
        guard let end = waypoint else {
            return
        }
        endHeading = end.heading.normalDegree.float
        if let lastHeading = lastWaypoint?.heading, lastHeading == end.heading {
            headingBetween = 0
        } else {
            headingBetween = endHeading - startHeading
        }
        if let start = lastWaypoint {
            distanceBetween = start.coordinate.distance(to: end.coordinate).float
        }
        if let turnMode = lastWaypoint?.turnMode {
            headingClockwise = turnMode == .clockwise
        }
        if headingClockwise {
            if headingBetween < 0 {
                headingBetween += 360
            }
        } else {
            if headingBetween > 0 {
                headingBetween -= 360
            }
        }
    }
    
    private var startHeading: Float = 0
    
    private var endHeading: Float = 0
    
    private var headingBetween: Float = 0
    
    private var headingClockwise = true
    
    private var distanceBetween: Float?
    
    private var lastTargetCourseHeading: Float?
    
    private var targetCourseHeading: Float? {
        guard let aircraftCoordinate = aircraftCoordinate else {
            return nil
        }
        if isCurveTurning {
            return turningHeading
        } else if headingMode == .track {
            return targetHeading
        } else if let coordinate = coordinate {
            if coordinate.distance(to: aircraftCoordinate) < 2 {
                return lastTargetCourseHeading
            }
            let heading = heading(from: aircraftCoordinate, to: coordinate).float
            lastTargetCourseHeading = heading
            return heading
        }
        return nil
    }
    
    private var isTargetHeadingReached: Bool {
        guard let targetHeading = targetHeading?.normalDegree,
              let heading = aircraftHeading?.normalDegree else {
            return false
        }
        let delta = abs(targetHeading-heading)
        return delta < 1.0 || delta > 359
    }
    
    private var aircraftHeading: Float? {
        aircraftAttitude?.z.float
    }
    
    private func isAircraftReachedHeading(_ targetHeading: Float) -> Bool {
        guard let aircraftHeading = aircraftHeading?.normalDegree else {
            return false
        }
        return abs(targetHeading.normalDegree-aircraftHeading) < 1.0
    }
    
    private var targetDistance: Float {
        guard let coordinate = coordinate,
              let aircraftCoordinate = aircraftCoordinate else {
            return 1000000
        }
        return coordinate.distance(to: aircraftCoordinate).float
    }
    
    private var isTargetHeightReached: Bool {
        guard let target = height else {
            return false
        }
        return abs(target-aircraftAltitude.float) < 1.0
    }
    
    //MARK: - Action
    
    private var shootPhotoDistance = 0.0
    
    private var lastShootPhotoCoordinate: CLLocationCoordinate2D?
    
    private func triggerShoot() {
        guard currentState == .executing else {
            return
        }
        guard !isTurning else {
            return
        }
        shootPhoto()
    }
    
    enum ActionState {
        case idle
        case ready
        case executing
        case finished
        case restoring ///restore cruise state
    }
    
    var actionState = ActionState.idle
    
    private var actionIndex = 0
    
    private func nextAction(at waypoint: DJIWaypoint) {
        guard self.waypoint == waypoint else {
            return
        }
        actionIndex += 1
        print("actionIndex: \(actionIndex)")
        if actionIndex < waypoint.waypointActions.count {
            if let action = waypoint.waypointActions[actionIndex] as? DJIWaypointAction {
                excuteAction(action)
            }
        } else {
            actionState = .finished
            print("Action finished.")
        }
    }
    
    private func starActions() -> Bool {
        if let action = waypoint?.waypointActions.first as? DJIWaypointAction {
            actionIndex = 0
            excuteAction(action)
            return true
        }
        return false
    }
    
    private var actionHeading: Float?
    
    private var actionGimbalPitch: Double?
    
    private var isActionHeadingReached: Bool {
        guard let actionHeading = actionHeading else {
            return true
        }
        return isAircraftReachedHeading(actionHeading)
    }
    
    private func excuteAction(_ action: DJIWaypointAction) {
        guard let waypoint = waypoint else {
            return
        }
        print("action \(actionIndex): type: \(action.actionType),  param: \(action.actionParam)")
        switch action.actionType {
        case .rotateAircraft:
            let targetHeading = Float(action.actionParam)
            actionHeading = targetHeading
            holdHeading(Float(action.actionParam))
        case .rotateGimbalPitch:
            actionGimbalPitch = Double(action.actionParam)
            let rotation = DJIGimbalRotation(
                pitchValue: NSNumber(value: action.actionParam),
                rollValue: nil,
                yawValue: nil,
                time: 2,
                mode: .absoluteAngle,
                ignore: true
            )
            gimbal?.rotate(with: rotation) { error in
                if let error = error {
                    print(error)
                    self.actionGimbalPitch = nil
                    self.nextAction(at: waypoint)
                }
            }
        case .shootPhoto:
            guard let camera = camera else {
                nextAction(at: waypoint)
                return
            }
            if camera.isFlatCameraModeSupported() {
                if flatCameraMode.isSinglePhotoMode {
                    camera.startShootPhoto(completion: { error in
                        if let error = error {
                            print(error)
                        }
                        self.nextAction(at: waypoint)
                    })
                } else {
                    camera.setFlatMode(.photoSingle) { error in
                        if let error = error {
                            print(error)
                        } else {
                            DispatchQueue.main.async {
                                self.excuteAction(action)
                            }
                        }
                    }
                }
            } else {
                if cameraMode == .shootPhoto {
                    camera.startShootPhoto(completion: { error in
                        if let error = error {
                            print(error)
                        }
                        self.nextAction(at: waypoint)
                    })
                } else {
                    camera.setMode(.shootPhoto, withCompletion: { error in
                        if let error = error {
                            print(error)
                        } else {
                            DispatchQueue.main.async {
                                self.excuteAction(action)
                            }
                        }
                    })
                }
            }
        case .startRecord:
            guard let camera = camera else {
                nextAction(at: waypoint)
                return
            }
            if camera.isFlatCameraModeSupported() {
                if flatCameraMode == .videoNormal {
                    camera.startRecordVideo(completion: { error in
                        self.nextAction(at: waypoint)
                    })
                } else {
                    camera.setFlatMode(.videoNormal) { error in
                        if let error = error {
                            print(error)
                            self.nextAction(at: waypoint)
                        } else {
                            DispatchQueue.main.async {
                                self.excuteAction(action)
                            }
                        }
                    }
                }
            } else {
                if cameraMode == .recordVideo {
                    camera.startRecordVideo(completion: { error in
                        self.nextAction(at: waypoint)
                    })
                } else {
                    camera.setMode(.recordVideo, withCompletion: { error in
                        if let error = error {
                            print(error)
                            self.nextAction(at: waypoint)
                        } else {
                            DispatchQueue.main.async {
                                self.excuteAction(action)
                            }
                        }
                    })
                }
            }
        case .stopRecord:
            camera?.stopRecordVideo(completion: { error in
                self.nextAction(at: waypoint)
            })
        case .stay:
            let seconds = Int(action.actionParam)
            DispatchQueue.main.asyncAfter(deadline: .now() + DispatchTimeInterval.milliseconds(seconds)) {
                self.nextAction(at: waypoint)
            }
        default:
            break
        }
    }
    
    func shootPhoto(isRetry: Bool = false) {
        guard let camera = camera else {
            return
        }
        if camera.isFlatCameraModeSupported() {
            if flatCameraMode.isSinglePhotoMode {
                camera.startShootPhoto { error in
                    if let error = error {
                        print(error)
                        if !isRetry {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                                self.shootPhoto(isRetry: true)
                            }
                        }
                    }
                }
            } else {
                camera.setFlatMode(.photoSingle) { error in
                    if let error = error {
                        print(error)
                    } else if !isRetry {
                        DispatchQueue.main.async {
                            self.shootPhoto(isRetry: true)
                        }
                    }
                }
            }
        } else {
            if cameraMode == .shootPhoto {
                camera.startShootPhoto { error in
                    if let error = error {
                        print(error)
                        if !isRetry {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                                self.shootPhoto(isRetry: true)
                            }
                        }
                    }
                }
            } else {
                camera.setMode(.shootPhoto, withCompletion: { error in
                    if let error = error {
                        print(error)
                    } else if !isRetry {
                        DispatchQueue.main.async {
                            self.shootPhoto(isRetry: true)
                        }
                    }
                })
            }
        }
    }
    
    //MARK: Camera and Gimbal
    
    private var camera: DJICamera? {
        DJISDKManager.product()?.camera
    }
        
    private var flatCameraMode: DJIFlatCameraMode {
        if let rawValue = keyManager?.getValueFor(DJICameraKey(param: DJICameraParamFlatMode)!)?.unsignedLongValue {
            return DJIFlatCameraMode(rawValue: rawValue) ?? .unknown
        }
        return .unknown
    }
        
    private var cameraMode: DJICameraMode {
        if let rawValue = keyManager?.getValueFor(DJICameraKey(param: DJICameraParamMode)!)?.unsignedLongValue {
            return DJICameraMode(rawValue: rawValue) ?? .unknown
        }
        return .unknown
    }
    
    private var isRecording: Bool {
        keyManager?.getValueFor(DJICameraKey(param: DJICameraParamIsRecording)!)?.boolValue ?? false
    }
    
    private var gimbal: DJIGimbal? {
        DJISDKManager.product()?.gimbal
    }
    
    private var gimbalAttitudeInDegrees: DJIGimbalAttitude? {
        guard let rawValue = keyManager?.getValueFor(DJIGimbalKey(param: DJIGimbalParamAttitudeInDegrees)!)?.value as? NSValue else {
            return nil
        }
        return rawValue.value(of: DJIGimbalAttitude.self)
    }

    private var gimbalPitch: Double {
        gimbalAttitudeInDegrees?.pitch.double ?? 0
    }
    
    private func setGimbalPitch(_ pitch: Double) {
        let rotation = DJIGimbalRotation(
            pitchValue: NSNumber(value: pitch),
            rollValue: nil,
            yawValue: nil,
            time: 1,
            mode: .absoluteAngle,
            ignore: true
        )
        gimbal?.rotate(with: rotation) { error in
            if let error = error {
                print(error)
            }
        }
    }

    
    //MARK: - Geometry Helpers
    
    private func arcInfo(
        previous: CGPoint,
        current: CGPoint,
        next: CGPoint,
        radius: CGFloat)
        -> (center: CGPoint, startAngle: CGFloat, endAngle: CGFloat, clockwise: Bool)
    {
        let a = previous
        let b = current
        let bCornerRadius: CGFloat = radius
        let c = next

        let abcAngle: CGFloat = angleBetween3Points(a, b, c)
        let xbaAngle = (a - b).angle
        let abeAngle = abcAngle / 2

        let deLength: CGFloat = bCornerRadius
        let bdLength = bCornerRadius / tan(abeAngle)
        let beLength = sqrt(deLength*deLength + bdLength*bdLength)

        let beVector: CGPoint = CGPoint(angle: abcAngle/2 + xbaAngle)

        let e: CGPoint = b + beVector * beLength

        let xebAngle = (b - e).angle
        let bedAngle = (CGFloat.pi / 2 - abs(abeAngle)) * abeAngle.sign() * -1

        return (
            center: e,
            startAngle: xebAngle - bedAngle,
            endAngle: xebAngle + bedAngle,
            clockwise: abeAngle < 0)
    }

    private func angleBetween3Points(_ a: CGPoint, _ b: CGPoint, _ c: CGPoint) -> CGFloat {
        let xbaAngle = (a - b).angle
        let xbcAngle = (c - b).angle // if you were to put point b at the origin, `xbc` refers to the angle formed from the x-axis to the bc line (clockwise)
        let abcAngle = xbcAngle - xbaAngle
        return CGPoint(angle: abcAngle).angle // normalize angle between -π to π
    }
    
    
}

final class WaypointExcutionProgress: DJIWaypointExecutionProgress {
    
    var index: Int = 0
    
    var isReached = false
    
    override var targetWaypointIndex: Int {
        return index
    }
    
    override var isWaypointReached: Bool {
        isReached
    }
    
    var isMute = false
    
}
