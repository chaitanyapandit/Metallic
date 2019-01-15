//
//  RecordingController.swift
//  Metallic
//
//  Created by Chaitanya Pandit on 13/01/19.
//  Copyright © 2019 Chaitanya Pandit. All rights reserved.
//

import Foundation
import AVFoundation

@objcMembers class RecordingController {
    
    private let assetWriter: AVAssetWriter
    private var assetWriterInput: AVAssetWriterInput!
    var input:((CMSampleBuffer) -> Void)?
    private let queue = DispatchQueue(label: "com.ceepee.metallic.recorder")
    private var recording: Bool = false

    // MARK Interface
    
    public init?() {

        // Setup the assetwriter to write to a new file in documents directory
        guard let documentsDirectoryURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).last else {
            return nil
        }
        
        let outputURL = documentsDirectoryURL.appendingPathComponent(NSUUID().uuidString).appendingPathExtension("mp4")
        
        do {
            self.assetWriter = try AVAssetWriter(url: outputURL, fileType: AVFileType.mp4)
        } catch let error {
            print("Fatal error creating recorder: \(error)")
            return nil
        }
        
        // Setup the input block to consume frames
        self.input = {sampleBuffer in
            self.append(sampleBuffer: sampleBuffer)
        }
    }
    
    public func startRecording() {
        self.queue.sync {
            self.recording = true
        }
    }
    
    public func stopRecording(completion: @escaping ((URL) -> Void)) {
        self.queue.sync {
            self.recording = false
            self.assetWriter.finishWriting {
                DispatchQueue.main.async {
                    completion(self.assetWriter.outputURL)
                }
            }
        }
    }

    // MARK Internal

    @objc(appendSampleBuffer:) func append(sampleBuffer: CMSampleBuffer) {
        
        guard let formatDescription = CMSampleBufferGetFormatDescription(sampleBuffer),
        CMFormatDescriptionGetMediaType(formatDescription) == kCMMediaType_Video,
        let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            return
        }
        
        // Process in a separate queue
        self.queue.async {
            
            guard self.recording else {
                return
            }
            
            if self.assetWriterInput == nil {
                // Setup for the first time
                self.assetWriterInput = AVAssetWriterInput(mediaType: .video, outputSettings:
                    [AVVideoCodecKey: AVVideoCodecType.h264,
                     AVVideoWidthKey: CVPixelBufferGetWidth(pixelBuffer),
                     AVVideoHeightKey: CVPixelBufferGetHeight(pixelBuffer),
                     AVVideoScalingModeKey : AVVideoScalingModeResizeAspectFill,
                     AVVideoCompressionPropertiesKey: [AVVideoAverageBitRateKey : 10 * 1024 * 1024]]
                )
                self.assetWriterInput.expectsMediaDataInRealTime = true
                self.assetWriter.add(self.assetWriterInput)
                
                self.assetWriter.startWriting()
                self.assetWriter.startSession(atSourceTime: CMSampleBufferGetPresentationTimeStamp(sampleBuffer))
            }
            
            if self.assetWriterInput.isReadyForMoreMediaData {
                self.assetWriterInput.append(sampleBuffer)
            }
        }
    }
}
