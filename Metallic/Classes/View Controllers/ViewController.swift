//
//  ViewController.swift
//  Metallic
//
//  Created by Chaitanya Pandit on 13/01/19.
//  Copyright © 2019 Chaitanya Pandit. All rights reserved.
//

import UIKit
import MetalKit
import AVFoundation
import Photos

class ViewController: UIViewController {

    @IBOutlet var metalView: MTKView!
    @IBOutlet var startStopButton: PaddedButton!
    @IBOutlet var contrastSlider: UISlider!
    @IBOutlet var saturationSlider: UISlider!
    @IBOutlet var brightnessSlider: UISlider!

    private var cameraController: CameraController?
    private var metalController: MetalController?
    private var recordingController: RecordingController?

    private let contrastFilter = ContrastFilter()
    private let saturationFilter = SaturationFilter()
    private let brightnessFilter = BrightnessFilter()
    private let pipeline = FilteringPipeline()

    // MARK: View Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Configure ui elements
        startStopButton.setTitle("start_recording".localized, for: .normal)
        startStopButton.titleEdgeInsets = UIEdgeInsets(top: 0, left: 10, bottom: 0, right: 10)
        contrastSlider.value = contrastFilter.contrast
        saturationSlider.value = saturationFilter.saturation
        brightnessSlider.value = brightnessFilter.brightness
        
        // Setup the controllers
        metalController = MetalController()
        cameraController = CameraController()
        metalController?.view = metalView
        
        // Add filters to pipline
        pipeline.addFilter(filter: contrastFilter)
        pipeline.addFilter(filter: saturationFilter)
        pipeline.addFilter(filter: brightnessFilter)
        metalController?.filteringPipeline = pipeline
        
        // chain the controllers
        cameraController?.output = metalController?.input
        _ = cameraController?.start()
    }
    
    // MARK: Actions

    @IBAction func contrastValueChanged(_ slider: UISlider) {
        contrastFilter.contrast = slider.value
    }
    
    @IBAction func saturationValueChanged(_ slider: UISlider) {
        saturationFilter.saturation = slider.value
    }
    
    @IBAction func brightnessValueChanged(_ slider: UISlider) {
        brightnessFilter.brightness = slider.value
    }
    
    @IBAction func startStopButtonTapped(_ sender: Any) {
        if let recorder = recordingController {
            recorder.stopRecording {[weak self] (url) in
                self?.recordingController = nil

                self?.checkLibraryAuth { (allowed) in
                    guard allowed else {
                        return
                    }
                    
                    UISaveVideoAtPathToSavedPhotosAlbum(url.path, self, #selector(ViewController.video(_:didFinishSavingWithError:contextInfo:)), nil)
                }
            }
            
            startStopButton.setTitle("start_recording".localized, for: .normal)
            startStopButton.backgroundColor = .blue
        } else {
            if let recorder = RecordingController() {
                self.recordingController = recorder
                metalController?.output = recorder.input
                recorder.startRecording()
                startStopButton.setTitle("stop_recording".localized, for: .normal)
                startStopButton.backgroundColor = .red
            }
        }
    }
    
    // MARK: Callbacks

    @objc func video(_ videoPath: NSString?, didFinishSavingWithError error:NSError?, contextInfo:UnsafeRawPointer) {
        let alertController = UIAlertController(title: "alert_saved_title".localized, message: "alert_saved_message".localized, preferredStyle: .alert)
        alertController.addAction(UIAlertAction(title: "ok".localized, style: .default, handler: nil))
        
        present(alertController, animated: true)
    }
    
    // MARK: Private

    private func checkLibraryAuth(completion: @escaping ((_ authorized: Bool)->Void)) {
        guard PHPhotoLibrary.authorizationStatus() != .authorized else {
            completion(true)
            return
        }
        
        guard PHPhotoLibrary.authorizationStatus() != .denied else {
            completion(false)
            return
        }
        
        PHPhotoLibrary.requestAuthorization({ (status: PHAuthorizationStatus) in
            DispatchQueue.main.async {
                completion(status == .authorized)
            }
        })
    }
}
