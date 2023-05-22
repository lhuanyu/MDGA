//
//  ViewController.swift
//  MDGA
//
//  Created by Huanyu Luo on 04/27/2023.
//  Copyright (c) 2023 Huanyu Luo. All rights reserved.
//

import DJIUXSDK

class ViewController: DUXDefaultLayoutViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        if let widget = leadingViewController?.widget(at: 2) {
            leadingViewController?.removeWidget(widget)
        }
        leadingViewController?.addWidget(userLocationWidget)
        leadingViewController?.addWidget(mapTypeWidget)
        
        setupMapView()
        
        setupMissionControlView()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.showUserLocation()
        }
    }
    
    override var contentViewController: UIViewController? {
        didSet {
            if let _ = contentViewController as? DUXMapViewController {
                tapGesture.isEnabled = true
            } else {
                tapGesture.isEnabled = false
            }
        }
    }
    
    let missionControllView = MissionControlView()
    
    func setupMissionControlView() {
        view.addSubview(missionControllView)
        missionControllView.backgroundColor = .black.withAlphaComponent(0.5)
        missionControllView.layer.cornerRadius = 10
        missionControllView.clipsToBounds = true
        let topMargin = UIScreen.main.traitCollection.verticalSizeClass == .compact ? 40.0 : 70
        missionControllView.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(topMargin)
            make.centerX.equalToSuperview()
            make.height.equalTo(40)
            make.width.equalToSuperview().multipliedBy(0.8)
        }
        
        missionControllView.resetButton.addTarget(self, action: #selector(resetMission), for: .touchUpInside)
    }
    
    lazy var userLocationWidget: ButtonWidget = {
        let button = ButtonWidget(type: .custom)
        button.tintColor = .white
        button.setImage(.init(systemName: "person")?.withConfiguration(.flight), for: .normal)
        button.addTarget(self, action: #selector(showUserLocation), for: .touchUpInside)
        return button
    }()
    
    lazy var mapTypeWidget: ButtonWidget = {
        let button = ButtonWidget(type: .custom)
        button.tintColor = .white
        button.setImage(.init(systemName: "map")?.withConfiguration(.flight), for: .normal)
        button.addTarget(self, action: #selector(toggleMapType), for: .touchUpInside)
        return button
    }()
    
    @objc
    func showUserLocation() {
        guard let mapView = mapViewController?.mapWidget.mapView else {
            return
        }
        mapView.showAnnotations([mapView.userLocation], animated: true)
        missionControllView.simulationCoordinate = mapView.userLocation.coordinate
        MissionControl.shared.pointOfInterest = mapView.userLocation.coordinate
    }
    
    lazy var tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleMapTap(_:)))
    func setupMapView() {
        guard let mapView = mapViewController?.mapWidget.mapView else {
            return
        }
        tapGesture.isEnabled = false
        mapView.addGestureRecognizer(tapGesture)
        mapView.mapType = .hybrid
    }
    
    @objc
    func handleMapTap(_ gesture: UITapGestureRecognizer) {
        guard missionControllView.addWaypointButton.isSelected else {
            return
        }
        guard let mapView = mapViewController?.mapWidget.mapView else {
            return
        }
        if gesture.state == .recognized {
            let location = gesture.location(in: mapView)
            let coordinate = mapView.convert(location, toCoordinateFrom: mapView)
            addWaypoint(at: coordinate, altitude: Float(10 * waypointCoodinates.count) + 10)
        }
    }
    
    @objc
    func toggleMapType() {
        guard let mapView = mapViewController?.mapWidget.mapView else {
            return
        }
        switch mapView.mapType {
        case .satellite:
            mapView.mapType = .hybrid
        case .standard:
            mapView.mapType = .satellite
        case .hybrid:
            mapView.mapType = .standard
        default:
            break
        }
    }
    
    var mapViewController: DUXMapViewController? {
        if let mapViewController = contentViewController as? DUXMapViewController {
            return mapViewController
        }
        if let mapViewController = previewViewController as? DUXMapViewController {
            return mapViewController
        }
        return nil
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    //MARK: - Mission
    
    var waypointCoodinates: [CLLocationCoordinate2D] = []
    var waypointAnnotations: [MKPointAnnotation] = []

    func addWaypoint(at coodinate: CLLocationCoordinate2D, altitude: Float) {
        waypointCoodinates.append(coodinate)
        MissionControl.shared.addWaypoint(at: coodinate, altitude: altitude)
        let annotation = MKPointAnnotation()
        annotation.coordinate = coodinate
        annotation.title = "\(Int(altitude))m"
        annotation.subtitle = "\(waypointCoodinates.count+1)"
        waypointAnnotations.append(annotation)
        mapViewController?.mapWidget.mapView.addAnnotation(annotation)
    }
    
    @objc
    func resetMission() {
        MissionControl.shared.reset()
        waypointCoodinates.removeAll()
        mapViewController?.mapWidget.mapView.removeAnnotations(waypointAnnotations)
    }

}

class ButtonWidget: UIButton, DUXWidgetProtocol {
    
    var aspectRatio: CGFloat = 1.0
    
    var collectionView: DUXWidgetCollectionView?
    
    var interactionExpectationLevel: DUXWidgetInteractionExpectionLevel = .full
    
    var action: DUXWidgetActionBlock?
    
    func dependentKeys() -> [DJIKey] {
        []
    }
    
    func transform(_ value: DUXSDKModelValue, for key: DJIKey) {
        
    }
}

extension UIImage.Configuration {
    static var flight: UIImage.SymbolConfiguration {
        if UIScreen.main.traitCollection.verticalSizeClass == .compact {
            return UIImage.SymbolConfiguration(pointSize: 24, weight: .regular, scale: .default)
        } else {
            return UIImage.SymbolConfiguration(pointSize: 30, weight: .regular, scale: .default)
        }
    }
}

extension UIWindow {
    
    static var key: UIWindow? {
        if #available(iOS 13, *) {
            return UIApplication.shared.windows.first { $0.isKeyWindow }
        } else {
            return UIApplication.shared.keyWindow
        }
    }
    
    static var topMostViewController: UIViewController? {
        guard let rootViewController = key?.rootViewController else {
            return nil
        }
        
        var topViewController: UIViewController?
        if let navigationController = rootViewController as? UINavigationController {
            topViewController = navigationController.topViewController
        } else if let tabbarController = rootViewController as? UITabBarController {
            topViewController = tabbarController.selectedViewController
        } else {
            topViewController = rootViewController
        }
        
        while let presentedViewController = topViewController?.presentedViewController {
            topViewController = presentedViewController
        }
        
        return topViewController
    }
    
}


func errorAlert(_ message: String) {
    guard let topMostViewController = UIWindow.topMostViewController else {
        return
    }
    let errorAlert = UIAlertController(title: "Error", message: message, preferredStyle: .alert)
    errorAlert.addAction(UIAlertAction(title: "OK", style: .cancel, handler: nil))
    topMostViewController.present(errorAlert, animated: true)
}
