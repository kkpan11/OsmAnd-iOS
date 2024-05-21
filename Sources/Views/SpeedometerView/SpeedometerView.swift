//
//  SpeedometerView.swift
//  OsmAnd Maps
//
//  Created by Oleksandr Panchenko on 16.05.2024.
//  Copyright © 2024 OsmAnd. All rights reserved.
//

import Foundation

@objcMembers
final class SpeedometerView: OATextInfoWidget {
    @IBOutlet private weak var centerPositionXConstraint: NSLayoutConstraint!
    @IBOutlet private weak var centerPositionYConstraint: NSLayoutConstraint!
    @IBOutlet private weak var leadingPositionConstraint: NSLayoutConstraint!
    @IBOutlet private weak var trailingPositionConstraint: NSLayoutConstraint!
    
    @IBOutlet private weak var contentStackView: UIStackView!
    
    @IBOutlet private weak var speedometerSpeedView: SpeedometerSpeedView!
   // @IBOutlet private weak var speedometerSpeedViewWidthConstraint: NSLayoutConstraint!
    
    @IBOutlet private weak var speedLimitEUView: SpeedLimitView! {
        didSet {
            speedLimitEUView.isHidden = true
        }
    }
    @IBOutlet private weak var speedLimitNAMView: SpeedLimitView! {
        didSet {
            speedLimitNAMView.isHidden = true
        }
    }
    
    let settings = OAAppSettings.sharedManager()!
    
    var style = EOAWidgetSizeStyle(rawValue: 2)!
    
    var isCarPlay = false
    var isPreview = false
    
    static var initView: SpeedometerView? {
        UINib(nibName: String(describing: self), bundle: nil)
            .instantiate(withOwner: nil, options: nil)[0] as? SpeedometerView
    }
    
    func isVisibleSpeedLimitView() -> Bool {
        let showSpeedLimitWarnings = settings.showSpeedLimitWarnings.get()
        if !showSpeedLimitWarnings {
            return false
        }
        
//        let _rh = OARoutingHelper.sharedInstance()
//        let _app = OsmAndApp.swiftInstance()
//        let _trackingUtilities = OAMapViewTrackingUtilities.instance()
//        let _locationProvider = _app?.locationServices
//        //let _wh = OAWaypointHelper.sharedInstance()
//        let _currentPositionHelper = OACurrentPositionHelper.instance()
//        let trafficWarnings = settings.showTrafficWarnings.get()
//        let cams = settings.showCameras.get()
//      //  let peds = settings.showPedestrian.get()
//        //let tunnels = settings.showTunnels.get()
//        var visible = false

//        if (_rh.isFollowingMode() || _trackingUtilities.isMapLinkedToLocation()) && (trafficWarnings || cams) {
//            var alarm: OAAlarmInfo?
//            
//            if _rh.isFollowingMode() && !OARoutingHelper.isDeviatedFromRoute() && !_rh.getCurrentGPXRoute() {
////                alarm = _wh.getMostImportantAlarm(_settings.speedSystem.get(), showCameras: cams)
//            } else {
//                if let loc = _app.locationServices.lastKnownLocation,
//                   let ro = _currentPositionHelper.getLastKnownRouteSegment(loc) {
//                    alarm = _wh.calculateMostImportantAlarm(ro, loc: loc, mc: _settings.metricSystem.get(), sc: _settings.speedSystem.get(), showCameras: cams)
//                }
//            }
//            
//            if let alarm, alarm.type == AIT_SPEED_LIMIT {
//                // Handle alarm
//            }
//        }
        
        return false
    }
        
//    func updateWidgetSize() {
//        let maxHeightWidth = getCurrentSpeedViewMaxHeightWidth()
//        [speedometerSpeedView, speedLimitNAMView, speedLimitNAMView].forEach {
//            $0.heightEqualConstraint?.constant = maxHeightWidth
//            $0.widthEqualConstraint?.constant = maxHeightWidth
//        }
//    }
    
    func updateWidgetSizeTest() {
        //[[OAAppSettings sharedManager] registerWidgetSizeStylePreference:prefId defValue:EOAWidgetSizeStyleMedium]
        widgetSizePref = settings.registerWidgetSizeStylePreference("updateWidgetSizeTest", defValue: style)
        updateWith(style: style, appMode: settings.applicationMode.get())
       // updateWidgetSize()
        
//        layoutIfNeeded()
//        DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
//            self.updateWith(style: EOAWidgetSizeStyle(rawValue: 1)!, appMode: settings.applicationMode.get())
//            self.updateWidgetSize()
//            self.layoutIfNeeded()
//            DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
//                self.updateWith(style: EOAWidgetSizeStyle(rawValue: 2)!, appMode: settings.applicationMode.get())
//                self.updateWidgetSize()
//                self.layoutIfNeeded()
//            }
//        }
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
    }
    
//    override func invalidateIntrinsicContentSize() {
//        getCurrentSpeedViewMaxHeightWidth()
//    }
    
    override var intrinsicContentSize: CGSize {
        let fittingSize = contentStackView.systemLayoutSizeFitting(UIView.layoutFittingCompressedSize)
        return CGSize(width: fittingSize.width, height: getCurrentSpeedViewMaxHeightWidth())
    }
    
    func configure() {
        updateWidgetSizeTest()
        let width = getCurrentSpeedViewMaxHeightWidth()
        let settings = OAAppSettings.sharedManager()!
        let drivingRegion = settings.drivingRegion.get()
        
        if drivingRegion == EOADrivingRegion.DR_US || drivingRegion == EOADrivingRegion.DR_CANADA  {
            speedLimitEUView.isHidden = true
            speedLimitNAMView.isHidden = false
        } else {
            speedLimitEUView.isHidden = false
            speedLimitNAMView.isHidden = true
        }
//
//        if (drivingRegion == DR_US)
//            return @"list_warnings_speed_limit_us";
//        else if (drivingRegion == DR_CANADA)
//            return @"list_warnings_speed_limit_ca";
//        return @"list_warnings_limit";
        // TODO:
        // EU – img_speedlimit_eu
        // USA, Canada – img_speedlimit_nam
        speedometerSpeedView.configureWith(widgetSizeStyle: style, width: width)
        speedLimitEUView.configureWith(widgetSizeStyle: style, width: width)
        speedLimitNAMView.configureWith(widgetSizeStyle: style, width: width)
//        let size = getCurrentSpeedViewMaxHeightWidth()
//        speedometerSpeedViewWidthConstraint.constant = size
        centerPositionYConstraint.isActive = true
        if isPreview {
            centerPositionXConstraint.isActive = true
            leadingPositionConstraint.isActive = false
            trailingPositionConstraint.isActive = false
        } else {
            centerPositionXConstraint.isActive = false
            if isCarPlay {
                layer.cornerRadius = 10
                leadingPositionConstraint.isActive = false
                trailingPositionConstraint.isActive = true
            } else {
                layer.cornerRadius = 6
                leadingPositionConstraint.isActive = true
                trailingPositionConstraint.isActive = false
            }
        }
        // TODO: property 
        speedLimitEUView.isHidden = false
        // EU – img_speedlimit_eu
        // USA, Canada – img_speedlimit_nam
        
        configureStackPosition()
    }
    
    override func updateInfo() -> Bool {
        // TODO:
        return true
    }
    
    private func configureStackPosition() {
        guard isCarPlay else { return }
        if let itemView = contentStackView.subviews.first {
            contentStackView.removeArrangedSubview(itemView)
            contentStackView.setNeedsLayout()
            contentStackView.layoutIfNeeded()
            
            contentStackView.insertArrangedSubview(itemView, at: 1)
            contentStackView.setNeedsLayout()
        }
    }
}

extension SpeedometerView {
    func getCurrentSpeedViewMaxHeightWidth() -> CGFloat {
        switch widgetSizeStyle {
        case .small: 56
        case .medium: 72
        case .large: 96
        @unknown default: fatalError("Unknown EOAWidgetSizeStyle enum value")
        }
    }
}
