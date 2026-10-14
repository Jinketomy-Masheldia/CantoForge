// SPDX-License-Identifier: GPL-3.0-only
// Copyright (C) 2026 CantoForge contributors
#import <AVFoundation/AVFoundation.h>

#include "applevideowriter.h"
#include <QCoreApplication>
#include <QDir>
#include <QFileInfo>
#include <cmath>
#include <cstdio>
#include <cstdlib>

using muse::media::AppleVideoWriter;

static void check(bool success, const char* message)
{
    if (!success) {
        fprintf(stderr, "FAIL: %s\n", message);
        exit(1);
    }
}

static void inspect(const QString& path, bool audio, int width, int height)
{
    @autoreleasepool {
        AVURLAsset* asset = [AVURLAsset URLAssetWithURL:[NSURL fileURLWithPath:path.toNSString()] options:nil];
        NSArray<AVAssetTrack*>* picture = [asset tracksWithMediaType:AVMediaTypeVideo];
        NSArray<AVAssetTrack*>* sound = [asset tracksWithMediaType:AVMediaTypeAudio];
        check(picture.count == 1 && sound.count == (audio ? 1u : 0u), "expected video/audio tracks");
        check(std::abs(CMTimeGetSeconds(asset.duration) - 1.0) < 1.0 / 24, "one-second output duration");
        check(picture.firstObject.naturalSize.width == width && picture.firstObject.naturalSize.height == height,
              "video dimensions");
        AVAssetReader* reader = [[AVAssetReader alloc] initWithAsset:asset error:nil];
        AVAssetReaderTrackOutput* frames = [AVAssetReaderTrackOutput assetReaderTrackOutputWithTrack:picture.firstObject
            outputSettings:@{ (NSString*)kCVPixelBufferPixelFormatTypeKey: @(kCVPixelFormatType_32BGRA) }];
        [reader addOutput:frames];
        check([reader startReading], "read back encoded H.264");
        int count = 0;
        while (CMSampleBufferRef sample = [frames copyNextSampleBuffer]) {
            CVPixelBufferRef pixels = CMSampleBufferGetImageBuffer(sample);
            if (!count) {
                CVPixelBufferLockBaseAddress(pixels, kCVPixelBufferLock_ReadOnly);
                const auto* p = static_cast<const unsigned char*>(CVPixelBufferGetBaseAddress(pixels));
                const size_t stride = CVPixelBufferGetBytesPerRow(pixels);
                const auto* top = p + 20 * stride + 20 * 4;
                const auto* bottom = p + (height - 20) * stride + 20 * 4;
                check(top[2] > top[0] + 80 && bottom[0] > bottom[2] + 80, "BGRA colors and upright frame orientation");
                CVPixelBufferUnlockBaseAddress(pixels, kCVPixelBufferLock_ReadOnly);
            }
            ++count;
            CFRelease(sample);
        }
        check(reader.status == AVAssetReaderStatusCompleted && count == 24, "all 24 frames decode");
        if (audio) {
            AVAssetReader* audioReader = [[AVAssetReader alloc] initWithAsset:asset error:nil];
            AVAssetReaderTrackOutput* samples = [AVAssetReaderTrackOutput assetReaderTrackOutputWithTrack:sound.firstObject
                outputSettings:@{ AVFormatIDKey: @(kAudioFormatLinearPCM), AVLinearPCMBitDepthKey: @16,
                                  AVLinearPCMIsFloatKey: @NO, AVLinearPCMIsBigEndianKey: @NO }];
            [audioReader addOutput:samples];
            check([audioReader startReading], "decode muxed AAC");
            size_t sampleCount = 0;
            while (CMSampleBufferRef sample = [samples copyNextSampleBuffer]) {
                sampleCount += CMSampleBufferGetNumSamples(sample);
                CFRelease(sample);
            }
            check(audioReader.status == AVAssetReaderStatusCompleted && sampleCount > 30000, "AAC contains readable samples");
        }
    }
}

int main(int argc, char** argv)
{
    QCoreApplication app(argc, argv);
    check(argc == 3, "usage: video-export-probe output-directory existing-ADTS-aac-file");
    QDir output(QString::fromLocal8Bit(argv[1]));
    check(QDir().mkpath(output.path()), "create output directory");
    check(QFileInfo::exists(QString::fromLocal8Bit(argv[2])), "AAC input exists");
    AppleVideoWriter writer;
    for (int width : { 1920, 3840 }) {
        int height = width == 1920 ? 1080 : 2160;
        QString path = output.filePath(QStringLiteral("乐谱-é-%1.mp4").arg(width));
        check(writer.open(path, width, height, 24, width == 1920 ? 10000000 : 40000000, 12), "open system H.264 encoder");
        QImage frame(width, height, QImage::Format_RGB32);
        for (int y = 0; y < height; ++y) {
            auto* row = reinterpret_cast<QRgb*>(frame.scanLine(y));
            std::fill(row, row + width, y < height / 2 ? qRgb(220, 20, 20) : qRgb(20, 20, 220));
        }
        for (int i = 0; i < 24; ++i) {
            check(writer.encodeImage(frame), "append score image");
        }
        check(writer.finish() && writer.finish(), "finalize video and allow repeated finish");
        inspect(path, false, width, height);
        check(writer.addAudio(QString::fromLocal8Bit(argv[2])), "mux ADTS AAC into MP4 without reencoding");
        inspect(path, true, width, height);
        writer.close();
        printf("PASS: %dx%d, 24 frames, H.264 + AAC, Unicode path, colors, duration\n", width, height);
    }
    check(!writer.open(output.filePath("invalid.mp4"), 1, 1080, 24, 10000000, 12), "reject invalid dimensions");
    check(writer.open(output.filePath("cancelled.mp4"), 640, 360, 24, 1000000, 12), "reuse after error");
    writer.abort();
    check(!writer.encodeImage(QImage(640, 360, QImage::Format_RGB32)) && !writer.finish() && writer.hasError(), "cancel is propagated");
    writer.close();
    check(writer.open(output.filePath("bad-frame.mp4"), 640, 360, 24, 1000000, 12), "reuse after cancellation");
    check(!writer.encodeImage(QImage(320, 180, QImage::Format_RGB32)) && writer.hasError(), "reject mismatched frame");
    writer.close();
    puts("System video export probe passed");
}
