//
//  SensorDataField.swift
//  OsmAnd Maps
//
//  Created by Oleksandr Panchenko on 02.11.2023.
//  Copyright © 2023 OsmAnd. All rights reserved.
//

import Foundation

class SensorDataField {
    var nameId: String
    var numberValue: NSNumber?
    var stringValue: String?
    var unitNameId: String

    init(nameId: String, unitNameId: String, numberValue: NSNumber?, stringValue: String?) {
        self.nameId = nameId
        self.numberValue = numberValue
        self.stringValue = stringValue
        self.unitNameId = unitNameId
    }
    
    func getFormattedValue() -> FormattedValue? {
        if numberValue == nil && stringValue == nil {
            return nil
        }
        var number: Float = 0.0
        if let numberValue {
            number = numberValue.floatValue
        }
        var value: String? = nil
        if let stringValue {
            value = stringValue
        }
        if value == nil, let numberValue {
            value = numberValue.stringValue
        }
        return FormattedValue(valueSrc: number, value: value ?? "-", unit: unitNameId);
    }
}

@objcMembers
final class FormattedValue: NSObject {
    let value: String
    let unit: String?
    let valueSrc: Float
    
    private let separateWithSpace: Bool
    
    init(valueSrc: Float, value: String, unit: String?) {
        self.value = value
        self.valueSrc = valueSrc
        self.unit = unit
        self.separateWithSpace = true
    }
    
    init(valueSrc: Float, value: String, unit: String?, separateWithSpace: Bool) {
        self.value = value
        self.valueSrc = valueSrc
        self.unit = unit
        self.separateWithSpace = separateWithSpace
    }
}
