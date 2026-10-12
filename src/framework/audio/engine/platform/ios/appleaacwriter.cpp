/*
 * SPDX-License-Identifier: GPL-3.0-only
 * Copyright (C) 2026 Contributors to the unofficial MuseScore Studio iPadOS port
 */
#include "appleaacwriter.h"

#include <algorithm>
#include <limits>
#include <utility>

using namespace muse::audio::encode;

AppleAacWriter::~AppleAacWriter()
{
    finish();
}

bool AppleAacWriter::check(OSStatus status)
{
    if (status != noErr && m_error == noErr) {
        m_error = status;
    }
    return status == noErr;
}

bool AppleAacWriter::open(const std::string& path, uint32_t sampleRate, uint32_t channels, uint32_t bitRate)
{
    finish();
    m_error = noErr;
    m_channels = channels;
    if (path.empty() || !sampleRate || !channels || channels > 6 || !bitRate) {
        return check(kAudio_ParamError);
    }

    CFURLRef url = CFURLCreateFromFileSystemRepresentation(kCFAllocatorDefault,
                                                         reinterpret_cast<const UInt8*>(path.data()),
                                                         static_cast<CFIndex>(path.size()), false);
    if (!url) {
        return check(kAudio_ParamError);
    }

    AudioStreamBasicDescription output = {};
    output.mSampleRate = sampleRate;
    output.mFormatID = kAudioFormatMPEG4AAC;
    output.mFormatFlags = kMPEG4Object_AAC_LC;
    output.mChannelsPerFrame = channels;
    UInt32 size = sizeof(output);
    OSStatus status = AudioFormatGetProperty(kAudioFormatProperty_FormatInfo, 0, nullptr, &size, &output);
    if (check(status)) {
        status = ExtAudioFileCreateWithURL(url, kAudioFileAAC_ADTSType, &output, nullptr,
                                          kAudioFileFlags_EraseFile, &m_file);
    }
    CFRelease(url);
    if (!check(status)) {
        finish();
        return false;
    }

    AudioStreamBasicDescription input = {};
    input.mSampleRate = sampleRate;
    input.mFormatID = kAudioFormatLinearPCM;
    input.mFormatFlags = kAudioFormatFlagsNativeFloatPacked;
    input.mChannelsPerFrame = channels;
    input.mBitsPerChannel = sizeof(float) * 8;
    input.mFramesPerPacket = 1;
    input.mBytesPerFrame = channels * sizeof(float);
    input.mBytesPerPacket = input.mBytesPerFrame;
    if (!check(ExtAudioFileSetProperty(m_file, kExtAudioFileProperty_ClientDataFormat, sizeof(input), &input))) {
        finish();
        return false;
    }

    AudioConverterRef converter = nullptr;
    size = sizeof(converter);
    if (!check(ExtAudioFileGetProperty(m_file, kExtAudioFileProperty_AudioConverter, &size, &converter))
        || !converter) {
        check(kAudio_ParamError);
        finish();
        return false;
    }
    if (!check(AudioConverterSetProperty(converter, kAudioConverterEncodeBitRate, sizeof(bitRate), &bitRate))) {
        finish();
        return false;
    }
    // Apple requires resynchronizing the file format after changing the converter.
    CFArrayRef configuration = nullptr;
    if (!check(ExtAudioFileSetProperty(m_file, kExtAudioFileProperty_ConverterConfig,
                                     sizeof(configuration), &configuration))) {
        finish();
        return false;
    }
    return true;
}

bool AppleAacWriter::write(uint64_t frames, const float* input)
{
    if (!m_file || m_error != noErr || (frames && !input)
        || frames > std::numeric_limits<size_t>::max() / (m_channels * sizeof(float))) {
        return check(kAudio_ParamError);
    }
    // Bound byte counts and avoid truncation to the AudioToolbox UInt32 fields.
    while (frames) {
        const UInt32 count = static_cast<UInt32>(std::min<uint64_t>(frames, 65536));
        AudioBufferList buffer = {};
        buffer.mNumberBuffers = 1;
        buffer.mBuffers[0].mNumberChannels = m_channels;
        buffer.mBuffers[0].mDataByteSize = count * m_channels * sizeof(float);
        buffer.mBuffers[0].mData = const_cast<float*>(input);
        if (!check(ExtAudioFileWrite(m_file, count, &buffer))) {
            return false;
        }
        frames -= count;
        input += static_cast<size_t>(count) * m_channels;
    }
    return true;
}

bool AppleAacWriter::finish()
{
    if (m_file) {
        // Dispose drains the encoder and closes the file, including a partial last frame.
        check(ExtAudioFileDispose(std::exchange(m_file, nullptr)));
    }
    return m_error == noErr;
}
