//
//  BasicImageFilter.swift
//  Metallic
//
//  Created by Chaitanya Pandit on 14/01/19.
//  Copyright © 2019 Chaitanya Pandit. All rights reserved.
//

import MetalKit

public class BasicImageFilter {
    
    public var pipelineState:MTLComputePipelineState?
    public var name:String!
    
    public init(name:String) {
        self.name = name
        updatePipeline()
    }
    
    public func updatePipeline() {
        
        guard let device = MTLCreateSystemDefaultDevice() else {
            return
        }
            
        self.pipelineState = device.newComputePipelineStateWithName(functionName: self.name)
    }
    
    public func getFactors()->[Float]{return []}
}

