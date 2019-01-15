//
//  FilteringPipeline.swift
//  Metallic
//
//  Created by Chaitanya Pandit on 14/01/19.
//  Copyright © 2019 Chaitanya Pandit. All rights reserved.
//

import MetalKit

class FilteringPipeline {
    
    private var filters = [BasicImageFilter]()

    lazy var metalDevice:  MTLDevice? = {
        return MTLCreateSystemDefaultDevice()
    }()
    
    lazy var commandQueue: MTLCommandQueue? = {
        return metalDevice?.makeCommandQueue()
    }()
    
    func addFilter(filter: BasicImageFilter) {
        self.filters.append(filter)
    }
    
    func filter(inputTexture: MTLTexture) -> MTLTexture? {
        
        var texture:MTLTexture? = inputTexture
        
        // Walk through each of our filters and add to commandQueue
        for filter in filters {
            guard let currentTexture = texture,
                let emptyTexture = currentTexture.sameSizeEmptyTexture(),
             let pipelineState = filter.pipelineState else {
                continue
            }
            var textures = [MTLTexture]()
            textures.append(emptyTexture)
            textures.append(currentTexture)
            self.commandQueue?.addCommand(pipelineState: (pipelineState), textures: textures, factors: filter.getFactors())
            
            texture = textures.first
        }
        
        return texture
    }
}
