//
//  Metal+Additions.swift
//  Metallic
//
//  Created by Chaitanya Pandit on 14/01/19.
//  Copyright © 2019 Chaitanya Pandit. All rights reserved.
//

import MetalKit

public extension MTLTexture {
    
    public func sameSizeEmptyTexture()-> MTLTexture? {
        guard let device = MTLCreateSystemDefaultDevice() else {
            fatalError("Unable to create metal device")
        }
        
        let textureDescriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: self.pixelFormat, width: self.width, height: self.height, mipmapped: false)
        textureDescriptor.usage = [.shaderRead, .shaderWrite]
        
        return device.makeTexture(descriptor: textureDescriptor)
    }
    
    public func threadGroups()-> MTLSize {
        let groupCount = threadGroupCount()
        return MTLSizeMake(Int(self.width) / groupCount.width, Int(self.height) / groupCount.height, 1)
    }
    
    public func threadGroupCount()->MTLSize {
        return MTLSizeMake(16, 16, 1)
    }
}

public extension MTLDevice {
        
    public func newComputePipelineStateWithName(functionName:String) -> MTLComputePipelineState? {
        guard let library = self.makeDefaultLibrary(),
            let function = library.makeFunction(name: functionName) else {
                fatalError("Unable to setup Library")
        }
        
        do {
            let pipelineState = try self.makeComputePipelineState(function: function)
            return pipelineState
        }
        catch {
            fatalError("Unable to setup Metal")
        }
    }
}

public extension MTLCommandQueue{
    
    public func addCommand<T>(pipelineState:MTLComputePipelineState,textures:[MTLTexture],factors:[T]) {
        
        guard let device = MTLCreateSystemDefaultDevice() else {
            fatalError("Unable to create metal device")
        }

        let commandBuffer = self.makeCommandBuffer()
        let commandEncoder = commandBuffer?.makeComputeCommandEncoder()
        commandEncoder?.setComputePipelineState(pipelineState)
        
        for i in 0..<textures.count{
            commandEncoder?.setTexture(textures[i], index: i)
        }
        
        for i in 0..<factors.count{
            var factor = factors[i]
            let size = max(MemoryLayout.size(ofValue: factor), 16)
            let buffer = device.makeBuffer(bytes: &factor, length: size, options: [MTLResourceOptions.storageModeShared])
            commandEncoder?.setBuffer(buffer, offset: 0, index: i)
        }
        
        commandEncoder?.dispatchThreadgroups(textures[0].threadGroups(), threadsPerThreadgroup: textures[0].threadGroupCount())
        commandEncoder?.endEncoding()
        commandBuffer?.commit()
        commandBuffer?.waitUntilCompleted()
    }
}
