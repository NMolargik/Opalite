//
//  AudioPlayer.swift
//  Opalite
//
//  Created by Nick Molargik on 1/21/26.
//

import AVFoundation
import SwiftUI

/// A simple audio player manager for playing sound effects from the app bundle.
///
/// Uses AVAudioPlayer to play MP3 or other audio files. Designed for one-shot
/// playback of sound effects like launch sounds and transitions.
@MainActor
@Observable
final class AudioPlayer {
    private var audioPlayer: AVAudioPlayer?

    /// Plays an audio file from the app bundle.
    ///
    /// - Parameters:
    ///   - name: The name of the audio file (without extension)
    ///   - extension: The file extension (default: "mp3")
    ///   - volume: Playback volume from 0.0 to 1.0 (default: 1.0)
    func play(_ name: String, withExtension ext: String = "mp3", volume: Float = 1.0) {
        guard let url = Bundle.main.url(forResource: name, withExtension: ext) else {
            #if DEBUG
            print("[AudioPlayer] Could not find audio file: \(name).\(ext)")
            #endif
            return
        }

        do {
            audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer?.volume = volume
            audioPlayer?.prepareToPlay()
            audioPlayer?.play()
        } catch {
            #if DEBUG
            print("[AudioPlayer] Failed to play audio: \(error)")
            #endif
        }
    }

    /// Stops any currently playing audio.
    func stop() {
        audioPlayer?.stop()
        audioPlayer = nil
    }
}
