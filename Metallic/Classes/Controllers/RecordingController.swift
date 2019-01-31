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
    private var videoInput: AVAssetWriterInput!
    private var audioInput: AVAssetWriterInput!

    var input:((CMSampleBuffer) -> Void)?
    private let queue = DispatchQueue(label: "com.ceepee.metallic.recorder")
    private var recording: Bool = false
    private var hasAudioInput: Bool = false
    private var hasVideoInput: Bool = false

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
    
    func startWriter(sampleBuffer: CMSampleBuffer) {
        guard hasAudioInput, hasVideoInput else {
            return
        }
        
        self.assetWriter.startWriting()
        self.assetWriter.startSession(atSourceTime: CMSampleBufferGetPresentationTimeStamp(sampleBuffer))
    }

    @objc(appendSampleBuffer:) func append(sampleBuffer: CMSampleBuffer) {
        guard let formatDescription = CMSampleBufferGetFormatDescription(sampleBuffer),
        self.recording else {
            return
        }

        self.queue.async {
            if CMFormatDescriptionGetMediaType(formatDescription) == kCMMediaType_Video {
                self.appendVideoBuffer(sampleBuffer: sampleBuffer)
            } else if CMFormatDescriptionGetMediaType(formatDescription) == kCMMediaType_Audio {
                self.appendAudioBuffer(sampleBuffer: sampleBuffer)
            }
        }
    }
    
    func appendAudioBuffer(sampleBuffer: CMSampleBuffer) {
        
        if self.audioInput == nil {
            let input = AVAssetWriterInput(mediaType: AVMediaType.audio, outputSettings: [ AVFormatIDKey: kAudioFormatMPEG4AAC,
                                                                                           AVNumberOfChannelsKey: 1,
                                                                                           AVSampleRateKey: 44100,
                                                                                           AVEncoderBitRateKey: 64000])

            guard self.assetWriter.canAdd(input) else {
                return
            }
            
            self.audioInput = input
            self.assetWriter.add(input)
            self.hasAudioInput = true
            startWriter(sampleBuffer: sampleBuffer)
        }
        
        if self.audioInput.isReadyForMoreMediaData {
            self.audioInput.append(sampleBuffer)
        }
    }

    func appendVideoBuffer(sampleBuffer: CMSampleBuffer) {
        
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            return
        }
        
        // Process in a separate queue
        if self.videoInput == nil {
            // Setup for the first time
            let input = AVAssetWriterInput(mediaType: .video, outputSettings:
                [AVVideoCodecKey: AVVideoCodecType.h264,
                 AVVideoWidthKey: CVPixelBufferGetWidth(pixelBuffer),
                 AVVideoHeightKey: CVPixelBufferGetHeight(pixelBuffer),
                 AVVideoScalingModeKey : AVVideoScalingModeResizeAspectFill,
                 AVVideoCompressionPropertiesKey: [AVVideoAverageBitRateKey : 10 * 1024 * 1024]]
            )

            input.expectsMediaDataInRealTime = true

            guard self.assetWriter.canAdd(input) else {
                return
            }
            
            self.videoInput = input
            self.assetWriter.add(input)
            self.hasVideoInput = true
            startWriter(sampleBuffer: sampleBuffer)
        }
        
        if self.videoInput.isReadyForMoreMediaData {
            self.videoInput.append(sampleBuffer)
        }
    }
}
