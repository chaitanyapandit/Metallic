# Metallic

An iOS project to demonstrate use of Metal shaders with Camera Output and Video Recording.

This project has three main controllers

- CameraController: Handles capturing live frames from the iOS camera.
- MetalController: Processes incoming video frames and applies filters using Metal Shaders. 
- RecordingController: Records the incoming frames to a mp4 file.

# Filters
This project has three filters  - Brightness, Saturation and Contrast which use Metal Compute Shaders at their core.
These filters are added to a FilteringPipeline which applies them on the incoming frames.

# Architecture
The controllers are chained by coupling the output of one to the other.

They're linked as:
`CameraController` -> `MetalController` -> `RecordingController`

```swift
captureSession?.output = metalSession?.input
metalSession?.output = recorder.input
```

CameraController consumes the frames from camera and outputs CMSampleBuffer frames. This output is linked to the input of `MetalController`. The MetalController's input consumes these buffers and applies the filters using the `FilteringPipeline`.
The output of MetalController is again a CMSampleBuffer but with the filtering applied. This output is again linked to the input of RecordingController, which writes these buffers to a video file.

# Dependencies
This project uses [FPSCounter](https://github.com/konoma/fps-counter) Pod to display the real time frames/second on the screen.
