//
//  CameraController.swift
//  Metallic
//
//  Created by Chaitanya Pandit on 13/01/19.
//  Copyright © 2019 Chaitanya Pandit. All rights reserved.
//

import AVFoundation
import UIKit

class CameraController: NSObject {
    
    public enum CaptureSessionError: Error {
        case deviceNotFound
    }
    
    var captureSession: AVCaptureSession?
    var capturePreset = AVCaptureSession.Preset.hd1280x720
    let captureQueue = DispatchQueue(label: "com.ceepee.metallic.capturesession", attributes: [])
    var output: ((CMSampleBuffer) -> Void)?
    var videoInput: AVCaptureDeviceInput?
    var videoOutput: AVCaptureVideoDataOutput?
    var audioInput: AVCaptureDeviceInput?
    var audioOutput: AVCaptureAudioDataOutput?

    // MARK: Interface

    func start() {
        // Setup
        let error = setupCaptureSession()
        guard error == nil, captureSession != nil else {
            fatalError("Unable to create metal device")
        }
        
        captureSession?.startRunning()
    }
    
    func stop() {
      captureSession?.stopRunning()
    }
    
    // MARK: Internal

    private func setupCaptureSession() -> Error? {
        
        // Setup camera session using the back camera
        let session = AVCaptureSession()
        session.beginConfiguration()
        
        session.sessionPreset = capturePreset
        session.usesApplicationAudioSession = false

        guard let videoInputRef = self.addVideoInput(session: session),
            let videoOutputRef = self.addVideoOutput(session: session),
            let audioInputRef = self.addAudioInput(session: session),
            let audioOutputRef = self.addAudioOutput(session: session) else {
            return CaptureSessionError.deviceNotFound
        }
        
        videoInput = videoInputRef
        videoOutput = videoOutputRef
        audioInput = audioInputRef
        audioOutput = audioOutputRef
        
        session.commitConfiguration()
        session.startRunning()
        captureSession = session
        
        return nil
    }
    
    func addVideoInput(session: AVCaptureSession) -> AVCaptureDeviceInput? {
        guard let device = CameraController.camera(withPosition: .back) else {
            return nil
        }
     
        return self.addInput(device: device, session: session)
    }
    
    func addAudioInput(session: AVCaptureSession) -> AVCaptureDeviceInput? {
        guard let device = CameraController.microphone() else {
            return nil
        }
        
        return self.addInput(device: device, session: session)
    }
    
    func addInput(device:AVCaptureDevice, session: AVCaptureSession) -> AVCaptureDeviceInput? {
        do {
            let input = try AVCaptureDeviceInput(device: device)
            guard session.canAddInput(input) else {
                return nil
            }
            
            session.addInput(input)
            
            return input
        } catch let error {
            print("Error adding video input: \(error)")
            return nil
        }
    }

    func addVideoOutput(session: AVCaptureSession) -> AVCaptureVideoDataOutput? {
        let output = AVCaptureVideoDataOutput()
        output.videoSettings = [
            kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA)
        ]
        output.alwaysDiscardsLateVideoFrames = true
        
        guard session.canAddOutput(output) else {
            return nil
        }
        
        output.setSampleBufferDelegate(self, queue: captureQueue)
        session.addOutput(output)
        return output
    }
    
    func addAudioOutput(session: AVCaptureSession) -> AVCaptureAudioDataOutput? {
        let output = AVCaptureAudioDataOutput()
        
        guard session.canAddOutput(output) else {
            return nil
        }
        
        output.setSampleBufferDelegate(self, queue: captureQueue)
        session.addOutput(output)
        return output
    }
    
    // MARK: Helpers

    private class func camera(withPosition position: AVCaptureDevice.Position) -> AVCaptureDevice? {
        
        return AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInWideAngleCamera],
                                                mediaType: AVMediaType.video,
                                                position: position).devices.filter({ $0.position == position }).first
    }

    private class func microphone() -> AVCaptureDevice? {
        return AVCaptureDevice.default(for: .audio)
    }

}

// MARK: AVCaptureVideoDataOutputSampleBufferDelegate

extension CameraController: AVCaptureVideoDataOutputSampleBufferDelegate, AVCaptureAudioDataOutputSampleBufferDelegate {
    
    public func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        if sampleBuffer.isVideoBuffer(),
            let orientation = AVCaptureVideoOrientation(orientation: UIDevice.current.orientation) {
            connection.videoOrientation = orientation
        }
        
        self.output?(sampleBuffer)
    }
}

extension CMSampleBuffer {
    func isVideoBuffer() -> Bool {
        guard let formatDescription = CMSampleBufferGetFormatDescription(self),
            CMFormatDescriptionGetMediaType(formatDescription) == kCMMediaType_Video else {
            return false
        }

        return true
    }
    
    func isAudioBuffer() -> Bool {
        guard let formatDescription = CMSampleBufferGetFormatDescription(self),
            CMFormatDescriptionGetMediaType(formatDescription) == kCMMediaType_Audio else {
                return false
        }
        
        return true
    }
}

extension AVCaptureVideoOrientation {
    var uiInterfaceOrientation: UIInterfaceOrientation {
        get {
            switch self {
            case .landscapeLeft:        return .landscapeLeft
            case .landscapeRight:       return .landscapeRight
            case .portrait:             return .portrait
            case .portraitUpsideDown:   return .portraitUpsideDown
            }
        }
    }
    
    init(ui:UIInterfaceOrientation) {
        switch ui {
        case .landscapeRight:       self = .landscapeRight
        case .landscapeLeft:        self = .landscapeLeft
        case .portrait:             self = .portrait
        case .portraitUpsideDown:   self = .portraitUpsideDown
        default:                    self = .portrait
        }
    }
    
    init?(orientation:UIDeviceOrientation) {
        switch orientation {
        case .landscapeRight:       self = .landscapeLeft
        case .landscapeLeft:        self = .landscapeRight
        case .portrait:             self = .portrait
        case .portraitUpsideDown:   self = .portraitUpsideDown
        default:
            return nil
        }
    }
}
