//
//  BrightnessFilter.swift
//  Metallic
//
//  Created by Chaitanya Pandit on 14/01/19.
//  Copyright © 2019 Chaitanya Pandit. All rights reserved.
//

import Foundation

public class BrightnessFilter: BasicImageFilter {
    
    public var brightness:Float = 0.0
    
    public init() {
        super.init(name: "Brightness")
    }
    
    override public func getFactors()->[Float] {
        return [brightness]
    }
}
