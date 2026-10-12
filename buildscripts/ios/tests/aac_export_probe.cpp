/* SPDX-License-Identifier: GPL-3.0-only
 * Copyright (C) 2026 Contributors to the unofficial MuseScore Studio iPadOS port
 */
#include "appleaacwriter.h"
#include <cassert>
#include <cmath>
#include <filesystem>
#include <iostream>
#include <vector>

using muse::audio::encode::AppleAacWriter;

static void checkExport(const std::string& path, uint32_t rate, uint32_t channels, uint32_t bitrate, uint32_t frames)
{
    std::vector<float> pcm(static_cast<size_t>(frames) * channels);
    for (uint32_t i = 0; i < frames; ++i) {
        for (uint32_t c = 0; c < channels; ++c) {
            const double frequency = i > frames - std::min(frames, rate / 5) ? 660.0 : 440.0 + c * 440.0;
            pcm[i * channels + c] = 0.3f * std::sin(6.283185307179586 * frequency * i / rate);
        }
    }
    AppleAacWriter writer;
    if (!writer.open(path, rate, channels, bitrate)) {
        std::cerr << "open failed: " << writer.error() << " rate=" << rate << " bitrate=" << bitrate << '\n';
        std::abort();
    }
    const uint32_t chunks[] = {1, 127, 1024, 777, 65537};
    uint32_t offset = 0, index = 0;
    while (offset < frames) {
        const uint32_t count = std::min(chunks[index++ % 5], frames - offset);
        assert(writer.write(count, pcm.data() + static_cast<size_t>(offset) * channels));
        offset += count;
    }
    assert(writer.finish());
    assert(writer.finish());
    assert(std::filesystem::file_size(path) > 7);
    CFURLRef url = CFURLCreateFromFileSystemRepresentation(nullptr,
                                                          reinterpret_cast<const UInt8*>(path.data()), path.size(), false);
    ExtAudioFileRef reader = nullptr;
    assert(ExtAudioFileOpenURL(url, &reader) == noErr);
    CFRelease(url);
    AudioStreamBasicDescription format = {};
    UInt32 size = sizeof(format);
    assert(ExtAudioFileGetProperty(reader, kExtAudioFileProperty_FileDataFormat, &size, &format) == noErr);
    assert(format.mFormatID == kAudioFormatMPEG4AAC);
    assert(format.mChannelsPerFrame == channels && format.mSampleRate == rate);
    format.mFormatID = kAudioFormatLinearPCM;
    format.mFormatFlags = kAudioFormatFlagsNativeFloatPacked;
    format.mFramesPerPacket = 1;
    format.mBytesPerFrame = channels * sizeof(float);
    format.mBytesPerPacket = format.mBytesPerFrame;
    format.mBitsPerChannel = 32;
    assert(ExtAudioFileSetProperty(reader, kExtAudioFileProperty_ClientDataFormat, sizeof(format), &format) == noErr);
    std::vector<float> decoded;
    std::vector<float> buffer(4096 * channels);
    for (;;) {
        UInt32 count = 4096;
        AudioBufferList list = {};
        list.mNumberBuffers = 1;
        list.mBuffers[0] = {channels, static_cast<UInt32>(buffer.size() * sizeof(float)), buffer.data()};
        assert(ExtAudioFileRead(reader, &count, &list) == noErr);
        if (!count) {
            break;
        }
        decoded.insert(decoded.end(), buffer.begin(), buffer.begin() + count * channels);
    }
    assert(ExtAudioFileDispose(reader) == noErr);
    const uint64_t decodedFrames = decoded.size() / channels;
    // ADTS has packet padding/encoder delay and no gapless container metadata.
    assert(decodedFrames >= frames && decodedFrames < frames + 4096);
    if (frames > rate) {
        for (uint32_t c = 0; c < channels; ++c) {
            double energy = 0;
            for (uint64_t i = decodedFrames - rate / 5; i < decodedFrames; ++i) {
                const float value = decoded[i * channels + c];
                assert(std::isfinite(value));
                energy += value * value;
            }
            assert(energy / (rate / 5) > 0.01); // Last audio is retained, not just a playable header.
        }
    }
    std::cout << rate << " Hz, " << channels << " channels, " << bitrate << " bit/s: "
              << frames << " input frames, " << decodedFrames << " decoded frames\n";
}

int main(int argc, char** argv)
{
    assert(argc == 2);
    const std::filesystem::path dir(argv[1]);
    std::filesystem::create_directories(dir);
    for (auto rate : {44100u, 48000u}) {
        for (auto channels : {1u, 2u}) {
            checkExport((dir / "aac-probe.aac").string(), rate, channels, 128000, 2 * rate + 173);
        }
    }
    for (auto rate : {32000u, 44100u, 48000u}) {
        const auto bitrates = AppleAacWriter::supportedBitRates(rate, 2);
        assert(!bitrates.empty());
        for (auto bitrate : bitrates) {
            checkExport((dir / "aac-probe.aac").string(), rate, 2, bitrate, rate + 209);
        }
    }
    checkExport((dir / u8"Unicode-\u4e50\u8c31-\u00e9.aac").string(), 44100, 2, 128000, 137);
    AppleAacWriter invalid;
    assert(!invalid.open((dir / "invalid.aac").string(), 0, 2, 128000));
    assert(!invalid.open((dir / "missing/invalid.aac").string(), 44100, 2, 128000));
    assert(invalid.open((dir / "reused.aac").string(), 44100, 2, 128000));
    assert(!invalid.write(1, nullptr));
    assert(!invalid.finish());
    std::cout << "AAC export probe passed\n";
}
