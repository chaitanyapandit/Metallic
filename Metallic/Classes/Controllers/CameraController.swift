//
//  CameraController.swift
//  Metallic
//
//  Created by Chaitanya Pandit on 13/01/19.
//  Copyright © 2019 Chaitanya Pandit. All rights reserved.
//

import AVFoundation

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

        guard let device = CameraController.camera(withPosition: .front) else {
            return CaptureSessionError.deviceNotFound
        }
        
        do {
            let input = try AVCaptureDeviceInput(device: device)
            session.addInput(input)
            videoInput = input

        } catch let error {
            return error
        }

        let output = AVCaptureVideoDataOutput()
        output.videoSettings = [
            kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA)
        ]
        output.alwaysDiscardsLateVideoFrames = true
        output.setSampleBufferDelegate(self, queue: captureQueue)
        session.addOutput(output)
        videoOutput = output
        
        session.commitConfiguration()
        session.startRunning()
        captureSession = session
        
        return nil
    }
    
    // MARK: Helpers

    private class func camera(withPosition position: AVCaptureDevice.Position) -> AVCaptureDevice? {
        
        return AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInWideAngleCamera],
                                                mediaType: AVMediaType.video,
                                                position: position).devices.filter({ $0.position == position }).first
    }

}

// MARK: AVCaptureVideoDataOutputSampleBufferDelegate

extension CameraController: AVCaptureVideoDataOutputSampleBufferDelegate {
    
    public func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        self.output?(sampleBuffer)
    }
}
