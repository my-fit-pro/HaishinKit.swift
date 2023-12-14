//
//  SampleBufferRTMPStream.swift
//  HaishinKit
//
//  Created by Zachary Simone on 9/7/2023.
//  Copyright © 2023 Shogo Endo. All rights reserved.
//

// Inspired by: https://github.com/shogo4405/HaishinKit.swift/pull/1074/files

open class SampleBufferRTMPStream: RTMPStream {

    public var includeVideoMetaData: Bool = true
    public var includeAudioMetaData: Bool = true

    override open func makeMetaData() -> ASObject {
        var metadata: ASObject = [:]
        #if os(iOS) || os(macOS)
        if includeVideoMetaData {
            metadata["width"] = videoSettings.videoSize.width
            metadata["height"] = videoSettings.videoSize.height
            #if os(iOS) || os(macOS) || os(tvOS)
            metadata["framerate"] = frameRate
            #endif
            switch videoSettings.format {
            case .h264:
                metadata["videocodecid"] = FLVVideoCodec.avc.rawValue
            case .hevc:
                metadata["videocodecid"] = FLVVideoFourCC.hevc.rawValue
            }
            metadata["videodatarate"] = videoSettings.bitRate / 1000
        }
        if includeAudioMetaData {
            metadata["audiocodecid"] = FLVAudioCodec.aac.rawValue
            metadata["audiodatarate"] = audioSettings.bitRate / 1000
            if let outputFormat = mixer.audioIO.outputFormat {
                metadata["audiosamplerate"] = outputFormat.sampleRate
            }
        }
        #endif
        return metadata
    }

}
