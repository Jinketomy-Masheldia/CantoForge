/*
 * SPDX-License-Identifier: GPL-3.0-only
 * Copyright (C) 2026 Contributors to the unofficial MuseScore Studio iPadOS port
 */
#pragma once

#include <AudioToolbox/AudioToolbox.h>
#include <cstdint>
#include <string>
#include <vector>

namespace muse::audio::encode {
// AudioToolbox owns buffering, AAC-LC conversion and the ADTS file transport.
// This class accepts the engine's interleaved float PCM, without a Qt dependency.
class AppleAacWriter
{
public:
    ~AppleAacWriter();
    AppleAacWriter() = default;
    AppleAacWriter(const AppleAacWriter&) = delete;
    AppleAacWriter& operator=(const AppleAacWriter&) = delete;

    bool open(const std::string& path, uint32_t sampleRate, uint32_t channels, uint32_t bitRate);
    bool write(uint64_t frames, const float* input);
    bool finish();
    OSStatus error() const { return m_error; }

    // Query the current OS codec so the export dialog offers only accepted rates.
    static std::vector<uint32_t> supportedBitRates(uint32_t sampleRate, uint32_t channels)
    {
        AudioStreamBasicDescription input = {};
        input.mSampleRate = sampleRate;
        input.mFormatID = kAudioFormatLinearPCM;
        input.mFormatFlags = kAudioFormatFlagsNativeFloatPacked;
        input.mChannelsPerFrame = channels;
        input.mBitsPerChannel = 32;
        input.mFramesPerPacket = 1;
        input.mBytesPerFrame = channels * sizeof(float);
        input.mBytesPerPacket = input.mBytesPerFrame;
        AudioStreamBasicDescription output = {};
        output.mSampleRate = sampleRate;
        output.mFormatID = kAudioFormatMPEG4AAC;
        output.mFormatFlags = kMPEG4Object_AAC_LC;
        output.mChannelsPerFrame = channels;
        output.mFramesPerPacket = 1024;
        AudioConverterRef converter = nullptr;
        std::vector<uint32_t> result;
        if (AudioConverterNew(&input, &output, &converter) != noErr) {
            return result;
        }
        for (UInt32 rate : {32000u, 40000u, 48000u, 56000u, 64000u, 80000u, 96000u,
                            112000u, 128000u, 160000u, 192000u, 224000u, 256000u, 320000u}) {
            if (AudioConverterSetProperty(converter, kAudioConverterEncodeBitRate, sizeof(rate), &rate) == noErr) {
                result.push_back(rate);
            }
        }
        AudioConverterDispose(converter);
        return result;
    }

private:
    bool check(OSStatus status);
    ExtAudioFileRef m_file = nullptr;
    uint32_t m_channels = 0;
    OSStatus m_error = noErr;
};
}
