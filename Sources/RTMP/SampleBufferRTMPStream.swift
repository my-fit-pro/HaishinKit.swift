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

    override open func createMetaData() -> ASObject {
        var metadata: ASObject = [:]
        #if os(iOS) || os(macOS)
        if includeVideoMetaData {
            metadata["width"] = mixer.videoIO.codec.settings.videoSize.width
            metadata["height"] = mixer.videoIO.codec.settings.videoSize.height
            metadata["framerate"] = mixer.videoIO.frameRate
            if mixer.videoIO.codec.settings.format == .h264 {
                metadata["videocodecid"] = FLVVideoCodec.avc.rawValue
            }
            metadata["videodatarate"] = mixer.videoIO.codec.settings.bitRate / 1000
        }
        if includeAudioMetaData {
            metadata["audiocodecid"] = FLVAudioCodec.aac.rawValue
            metadata["audiodatarate"] = mixer.audioIO.codec.settings.bitRate / 1000
        }
        #endif
        return metadata
    }

}
