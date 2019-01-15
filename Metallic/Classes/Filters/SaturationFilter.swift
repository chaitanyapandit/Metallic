//
//  SaturationFilter.swift
//  Metallic
//
//  Created by Chaitanya Pandit on 14/01/19.
//  Copyright © 2019 Chaitanya Pandit. All rights reserved.
//

public class SaturationFilter: BasicImageFilter {
    
    public var saturation:Float = 1.0
    
    public init() {
        super.init(name: "Saturation")
    }
    
    override public func getFactors()->[Float] {
        return [saturation]
    }
}
