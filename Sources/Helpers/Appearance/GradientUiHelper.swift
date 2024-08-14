//
//  GradientUiHelper.swift
//  OsmAnd Maps
//
//  Created by Skalii on 01.08.2024.
//  Copyright © 2024 OsmAnd. All rights reserved.
//

import Foundation
import Charts

@objcMembers
final class GradientUiHelper: NSObject {

    final class AxisValueFormatter: IAxisValueFormatter {

        private let formatClosure: (Double, AxisBase?) -> String
        
        init(formatClosure: @escaping (Double, AxisBase?) -> String) {
            self.formatClosure = formatClosure
        }
        
        func stringForValue(_ value: Double, axis: AxisBase?) -> String {
            return formatClosure(value, axis)
        }
    }

    static let maxAltitudeAddition = 50.0

    static func formatTerrainTypeValues(_ value: Double) -> String {
        let format = value >= 10 ? "#" : "#.#"
        let formatter = NumberFormatter()
        formatter.positiveFormat = format
        var formattedValue = formatter.string(from: NSNumber(value: value)) ?? ""
        if formattedValue.hasSuffix(".0") {
            formattedValue.removeLast(2)
        }
        return formattedValue
    }

    static func getGradientTypeFormatterFor(terrainType: TerrainType, analysis: OAGPXTrackAnalysis?) -> IAxisValueFormatter {
        Self.getGradientTypeFormatter(terrainType, analysis: analysis)
    }

    static func getGradientTypeFormatter(_ gradientType: Any, analysis: OAGPXTrackAnalysis?) -> IAxisValueFormatter {
        if let terrainType = gradientType as? TerrainType {
            return getTerrainTypeFormatter(terrainType)
        }
        return getColorizationTypeFormatter(gradientType as! ColorizationType, analysis: analysis)
    }

    private static func getTerrainTypeFormatter(_ terrainType: TerrainType) -> IAxisValueFormatter {
        return AxisValueFormatter { (value, axis) in
            var shouldShowUnit = axis?.entries.contains(value) ?? false
            var stringValue = Self.formatTerrainTypeValues(value)
            var typeValue = ""
            switch terrainType {
            case .slope:
                typeValue = "°"
            case .height:
                let formattedValue = OAOsmAndFormatter.getFormattedAlt(value, mc: OAAppSettings.sharedManager().metricSystem.get())
                stringValue = formattedValue ?? ""
                shouldShowUnit = false
            default:
                break
            }
            return shouldShowUnit ? "\(stringValue) \(typeValue)" : stringValue
        }
    }

    private static func getColorizationTypeFormatter(_ colorizationType: ColorizationType, analysis: OAGPXTrackAnalysis?) -> IAxisValueFormatter {
        return AxisValueFormatter { (value, axis) in
            var shouldShowUnit = axis?.entries.contains(value) ?? false
            var stringValue = Self.formatValue(value, multiplier: 100)
            var type = "%"
            if let analysis = analysis {
                switch colorizationType {
                case .speed:
                    if analysis.maxSpeed != 0 {
                        type = OASpeedConstant.toShortString(OAAppSettings.sharedManager().speedSystem.get())
                        stringValue = Self.formatValue(value, multiplier: analysis.maxSpeed)
                    }
                case .elevation:
                    let minElevation = analysis.minElevation
                    let maxElevation = analysis.maxElevation + maxAltitudeAddition
                    if minElevation != 99999.0 && maxElevation != -100.0 {
                        let calculatedValue = value == 0 ? minElevation : minElevation + (value * (maxElevation - minElevation))
                        let formattedValue = OAOsmAndFormatter.getFormattedAlt(calculatedValue, mc: OAAppSettings.sharedManager().metricSystem.get())
                        stringValue = formattedValue ?? ""
                        shouldShowUnit = false
                    }
                default:
                    break
                }
            }
            return shouldShowUnit ? "\(stringValue) \(type)" : stringValue
        }
    }

    private static func formatValue(_ value: Double, multiplier: Float) -> String {
        let formatter = NumberFormatter()
        formatter.positiveFormat = "#"
        return formatter.string(from: NSNumber(value: value * Double(multiplier))) ?? ""
    }
}