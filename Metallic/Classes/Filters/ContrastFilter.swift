//
//  ContrastFilter.swift
//  Metallic
//
//  Created by Chaitanya Pandit on 14/01/19.
//  Copyright © 2019 Chaitanya Pandit. All rights reserved.
//

public class ContrastFilter: BasicImageFilter {
    
    public var contrast:Float = 1.0
    
    public init() {
        super.init(name: "Contrast")
    }
    
    override public func getFactors()->[Float] {
        return [contrast]
    }
}
