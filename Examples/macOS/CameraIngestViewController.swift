import AVFoundation
import Cocoa
import HaishinKit
import VideoToolbox

extension NSPopUpButton {
    fileprivate func present(mediaType: AVMediaType) {
        let devices = AVCaptureDevice.devices(for: mediaType)
        devices.forEach {
            self.addItem(withTitle: $0.localizedName)
        }
    }
}

final class CameraIngestViewController: NSViewController {
    @IBOutlet private weak var lfView: MTHKView!
    @IBOutlet private weak var audioPopUpButton: NSPopUpButton!
    @IBOutlet private weak var cameraPopUpButton: NSPopUpButton!
    @IBOutlet private weak var urlField: NSTextField!
    private let netStreamSwitcher: NetStreamSwitcher = .init()
    private var stream: (any IOStreamConvertible)? {
        return netStreamSwitcher.stream
    }
    private var mixer = IOMixer()
    private var textScreenObject = TextScreenObject()

    override func viewDidLoad() {
        super.viewDidLoad()
        urlField.stringValue = Preference.default.uri ?? ""
        audioPopUpButton?.present(mediaType: .audio)
        cameraPopUpButton?.present(mediaType: .video)

        netStreamSwitcher.uri = Preference.default.uri ?? ""

        Task {
            stream.map {
                lfView?.attachStream($0)
                mixer.addStream($0)
            }
        }
    }

    override func viewDidAppear() {
        super.viewDidAppear()

        mixer.isMultiTrackAudioMixingEnabled = true

        mixer.videoMixerSettings.mode = .offscreen
        mixer.screen.startRunning()
        textScreenObject.horizontalAlignment = .right
        textScreenObject.verticalAlignment = .bottom
        textScreenObject.layoutMargin = .init(top: 0, left: 0, bottom: 16, right: 16)

        mixer.screen.backgroundColor = NSColor.black.cgColor

        let videoScreenObject = VideoTrackScreenObject()
        videoScreenObject.cornerRadius = 32.0
        videoScreenObject.track = 1
        videoScreenObject.horizontalAlignment = .right
        videoScreenObject.layoutMargin = .init(top: 16, left: 0, bottom: 0, right: 16)
        videoScreenObject.size = .init(width: 160 * 2, height: 90 * 2)
        _ = videoScreenObject.registerVideoEffect(MonochromeEffect())

        let imageScreenObject = ImageScreenObject()
        let imageURL = URL(fileURLWithPath: Bundle.main.path(forResource: "game_jikkyou", ofType: "png") ?? "")
        if let provider = CGDataProvider(url: imageURL as CFURL) {
            imageScreenObject.verticalAlignment = .bottom
            imageScreenObject.layoutMargin = .init(top: 0, left: 0, bottom: 16, right: 0)
            imageScreenObject.cgImage = CGImage(
                pngDataProviderSource: provider,
                decode: nil,
                shouldInterpolate: false,
                intent: .defaultIntent
            )
        } else {
            logger.info("no image")
        }

        let assetScreenObject = AssetScreenObject()
        assetScreenObject.size = .init(width: 180, height: 180)
        assetScreenObject.layoutMargin = .init(top: 16, left: 16, bottom: 0, right: 0)
        try? assetScreenObject.startReading(AVAsset(url: URL(fileURLWithPath: Bundle.main.path(forResource: "SampleVideo_360x240_5mb", ofType: "mp4") ?? "")))
        try? mixer.screen.addChild(assetScreenObject)
        try? mixer.screen.addChild(videoScreenObject)
        try? mixer.screen.addChild(imageScreenObject)
        try? mixer.screen.addChild(textScreenObject)
        mixer.screen.delegate = self

        Task {
            try? await mixer.attachAudio(DeviceUtil.device(withLocalizedName: audioPopUpButton.titleOfSelectedItem!, mediaType: .audio))

            var audios = AVCaptureDevice.devices(for: .audio)
            audios.removeFirst()
            if let device = audios.first, mixer.isMultiTrackAudioMixingEnabled {
                try? await mixer.attachAudio(device, track: 1)
            }

            try? await mixer.attachCamera(DeviceUtil.device(withLocalizedName: cameraPopUpButton.titleOfSelectedItem!, mediaType: .video), track: 0)
            var videos = AVCaptureDevice.devices(for: .video)
            videos.removeFirst()
            if let device = videos.first {
                try? await mixer.attachCamera(device, track: 1)
            }
        }
    }

    @IBAction private func publishOrStop(_ sender: NSButton) {
        // Publish
        if sender.title == "Publish" {
            sender.title = "Stop"
            netStreamSwitcher.open(.ingest)
        } else {
            // Stop
            sender.title = "Publish"
            netStreamSwitcher.close()
        }
    }

    @IBAction private func orientation(_ sender: AnyObject) {
        // lfView.rotate(byDegrees: 90)
        mixer.videoMixerSettings.isMuted.toggle()
    }

    @IBAction private func mirror(_ sender: AnyObject) {
        mixer.videoCapture(for: 0)?.isVideoMirrored.toggle()
    }

    @IBAction private func selectAudio(_ sender: AnyObject) {
        Task {
            let device = DeviceUtil.device(withLocalizedName: audioPopUpButton.titleOfSelectedItem!, mediaType: .audio)
            try? await mixer.attachAudio(device)
        }
    }

    @IBAction private func selectCamera(_ sender: AnyObject) {
        Task {
            let device = DeviceUtil.device(withLocalizedName: cameraPopUpButton.titleOfSelectedItem!, mediaType: .video)
            try? await mixer.attachCamera(device, track: 0)
        }
    }
}

extension CameraIngestViewController: ScreenDelegate {
    func screen(_ screen: Screen, willLayout time: CMTime) {
        textScreenObject.string = Date().description
    }
}
