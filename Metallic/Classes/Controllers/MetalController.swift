//
//  MetalController.swift
//  Metallic
//
//  Created by Chaitanya Pandit on 13/01/19.
//  Copyright © 2019 Chaitanya Pandit. All rights reserved.
//

import MetalKit
import AVFoundation

class MetalController: NSObject {
    
    private lazy var commandQueue: MTLCommandQueue? = { return metalDevice?.makeCommandQueue() }()
    public var filteringPipeline: FilteringPipeline?
    public var input:((CMSampleBuffer) -> Void)?
    private lazy var metalDevice:  MTLDevice? = { return MTLCreateSystemDefaultDevice() }()
    public var view: MTKView? {
        didSet {
            guard let view = view else {
                return
            }
            
            // Setup ourself as the rendering delegate of the metal view
            view.device = self.metalDevice
            view.delegate = self
            view.framebufferOnly = true
            view.colorPixelFormat = .bgra8Unorm
            view.contentScaleFactor = UIScreen.main.scale
            view.colorPixelFormat = MTLPixelFormat.bgra8Unorm
        }
    }
    public var output: ((CMSampleBuffer) -> Void)?
    internal var renderPipelineState: MTLRenderPipelineState?
    private let semaphore = DispatchSemaphore(value: 1)
    private var textureCache: CVMetalTextureCache!
    private var texture: MTLTexture?
    
    override init() {

        super.init()
        
        // Setup input block and process the incoming buffers
        self.input = {imageBuffer in
            self.processBuffer(imageBuffer)
        }
        
        guard let metalDevice = self.metalDevice,
            CVMetalTextureCacheCreate(kCFAllocatorDefault, nil, metalDevice, nil, &textureCache) == kCVReturnSuccess else {
            fatalError("Unable to create texture cache")
        }

        initializeRenderPipelineState()
    }
    
    // MARK: Processing and applying Filters
    
    private func processBuffer(_ sampleBuffer: CMSampleBuffer) {
        
        // Synchronize the texture computation so that camera frames don't go out of sync
        _ = semaphore.wait(timeout: DispatchTime.distantFuture)
        
        guard sampleBuffer.isVideoBuffer() else {
            return
        }
        
        // Step 1: Get a Texture from the incoming frame buffer
        guard let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer),
            let texture = MetalController.textureFromImageBuffer(imageBuffer: imageBuffer, textureCache:textureCache, planeIndex: 0) else {
                output?(sampleBuffer)
                semaphore.signal()
                
                return
        }
        
        var finalTexture: MTLTexture? = texture
        
        // Step 2: Apply the filters on the original texture
        if let filteringPipeline = filteringPipeline {
            finalTexture = filteringPipeline.filter(inputTexture: texture)
        }
        
        self.texture = finalTexture
        
        // Step 3: convert the texture back to buffer and pass to outpur
        if let outputTexture = finalTexture,
            let outputSampleBuffer = MetalController.sampleBufferFromTexture(texture: outputTexture, sampleBuffer: sampleBuffer) {
            output?(outputSampleBuffer)
        }
        
        semaphore.signal()
    }
 
    // MARK: Rendering
    
    private func render(texture: MTLTexture, inView metalView:MTKView, withCommandBuffer commandBuffer: MTLCommandBuffer, device: MTLDevice) {
        
        // Renders the texture on to the metal view
        _ = semaphore.wait(timeout: DispatchTime.distantFuture)
        
        guard
            let currentRenderPassDescriptor = metalView.currentRenderPassDescriptor,
            let currentDrawable = metalView.currentDrawable,
            let renderPipelineState = renderPipelineState,
            let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: currentRenderPassDescriptor)
            else {
                semaphore.signal()
                return
        }
        
        encoder.pushDebugGroup("RenderFrame")
        encoder.setRenderPipelineState(renderPipelineState)
        encoder.setFragmentTexture(texture, index: 0)
        encoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4, instanceCount: 1)
        encoder.popDebugGroup()
        encoder.endEncoding()
        
        commandBuffer.addScheduledHandler { [weak self] (buffer) in
            guard let unwrappedSelf = self else { return }
            
            unwrappedSelf.semaphore.signal()
        }
        commandBuffer.present(currentDrawable)
        commandBuffer.commit()
    }
    
    // MARK: Private

    private func initializeRenderPipelineState() {
        // Setup the rendering pipeline
        guard
            let device = metalDevice,
            let library = device.makeDefaultLibrary()
            else { return }
        
        let pipelineDescriptor = MTLRenderPipelineDescriptor()
        pipelineDescriptor.sampleCount = 1
        pipelineDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
        pipelineDescriptor.depthAttachmentPixelFormat = .depth32Float
        pipelineDescriptor.vertexFunction = library.makeFunction(name: "mapTexture")
        pipelineDescriptor.fragmentFunction = library.makeFunction(name: "displayTexture")
        
        do {
            try renderPipelineState = device.makeRenderPipelineState(descriptor: pipelineDescriptor)
        }
        catch {
            assertionFailure("Failed creating a render state pipeline. Can't render the texture without one.")
            return
        }
    }
    
    // MARK: Helpers

    private class func textureFromImageBuffer(imageBuffer: CVImageBuffer, textureCache: CVMetalTextureCache, planeIndex:Int) -> MTLTexture? {
       
        // Converts a CVImageBuffer in to a MTLTexture
        let isPlanar = CVPixelBufferIsPlanar(imageBuffer)
        let width = isPlanar ? CVPixelBufferGetWidthOfPlane(imageBuffer, planeIndex) : CVPixelBufferGetWidth(imageBuffer)
        let height = isPlanar ? CVPixelBufferGetHeightOfPlane(imageBuffer, planeIndex) : CVPixelBufferGetHeight(imageBuffer)
        
        var imageTextureRef: CVMetalTexture?
        
        let result = CVMetalTextureCacheCreateTextureFromImage(kCFAllocatorDefault, textureCache, imageBuffer, nil, MTLPixelFormat.bgra8Unorm, width, height, planeIndex, &imageTextureRef)
        
        guard  let imageTexture = imageTextureRef,
            let metalTexture = CVMetalTextureGetTexture(imageTexture),
            result == kCVReturnSuccess else {
                return nil
        }

        return metalTexture
    }
    
    private class func sampleBufferFromTexture(texture: MTLTexture, sampleBuffer:CMSampleBuffer) -> CMSampleBuffer? {
        
        // Converts a MTLTexture in to CMSampleBuffer
        guard let pixelBuffer : CVPixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            return nil
        }
        
        CVPixelBufferLockBaseAddress(pixelBuffer, CVPixelBufferLockFlags.init(rawValue: 0))
        guard let tmpBuffer = CVPixelBufferGetBaseAddress(pixelBuffer) else {
            return nil
        }
        
        let region = MTLRegionMake2D(0, 0, texture.width, texture.height);
        texture.getBytes(tmpBuffer, bytesPerRow: CVPixelBufferGetBytesPerRow(pixelBuffer), from: region, mipmapLevel: 0)
        CVPixelBufferUnlockBaseAddress(pixelBuffer, CVPixelBufferLockFlags.init(rawValue: 0))
        
        var timingInfo: CMSampleTimingInfo = CMSampleTimingInfo.invalid
        _ = CMSampleBufferGetSampleTimingInfo(sampleBuffer, at: 0, timingInfoOut: &timingInfo)
        
        var outputFormatDescriptionRef: CMFormatDescription? = nil
        CMVideoFormatDescriptionCreateForImageBuffer(allocator: kCFAllocatorDefault, imageBuffer: pixelBuffer, formatDescriptionOut: &outputFormatDescriptionRef)
        
        guard let outputFormatDescription = outputFormatDescriptionRef else {
            return nil
        }
        
        var outputSampleBuffer: CMSampleBuffer? = nil
        CMSampleBufferCreateReadyWithImageBuffer(allocator: kCFAllocatorDefault, imageBuffer: pixelBuffer, formatDescription: outputFormatDescription, sampleTiming: &timingInfo, sampleBufferOut: &outputSampleBuffer)
        
        return outputSampleBuffer
    }
    
}

extension MetalController: MTKViewDelegate {
    
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) { }
    
    func draw(in view: MTKView) {
        guard
            let texture = texture,
            let device = metalDevice,
            let commandBuffer = commandQueue?.makeCommandBuffer() else {
                return
        }

        // Render the texture in to the metal view
        render(texture: texture, inView: view, withCommandBuffer: commandBuffer, device: device)
    }
}
