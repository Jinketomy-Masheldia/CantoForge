// SPDX-License-Identifier: GPL-3.0-only
// Copyright (C) 2026 CantoForge contributors
#include "applevideowriter.h"

#import <AVFoundation/AVFoundation.h>
#import <CoreVideo/CoreVideo.h>

#include <atomic>
#include <chrono>
#include <cstring>
#include <thread>
#include <QDebug>
#include <QUuid>

namespace muse::media {
namespace {
NSURL* fileUrl(const QString& path)
{
    return [NSURL fileURLWithPath:path.toNSString()];
}

constexpr auto WAIT_LIMIT = std::chrono::seconds(120);
}

struct AppleVideoWriter::Impl {
    AVAssetWriter* writer = nil;
    AVAssetWriterInput* input = nil;
    AVAssetWriterInputPixelBufferAdaptor* adaptor = nil;
    QString outputPath;
    unsigned width = 0;
    unsigned height = 0;
    unsigned fps = 0;
    int64_t frames = 0;
    bool finished = false;
    std::atomic<bool> cancelled { false };
    std::atomic<bool> failed { false };

    bool fail(const char* operation, NSError* error = nil)
    {
        failed = true;
        qWarning() << "Apple video export:" << operation
                   << (error ? QString::fromNSString(error.localizedDescription) : QString());
        return false;
    }

    bool waitForInput()
    {
        const auto deadline = std::chrono::steady_clock::now() + WAIT_LIMIT;
        while (!input.readyForMoreMediaData) {
            if (cancelled || writer.status != AVAssetWriterStatusWriting) {
                return fail("video input stopped", writer.error);
            }
            if (std::chrono::steady_clock::now() >= deadline) {
                return fail("video input timed out", writer.error);
            }
            std::this_thread::sleep_for(std::chrono::milliseconds(2));
        }
        return !cancelled && writer.status == AVAssetWriterStatusWriting;
    }
};

AppleVideoWriter::AppleVideoWriter() : m_impl(std::make_unique<Impl>()) {}
AppleVideoWriter::~AppleVideoWriter() { close(); }

bool AppleVideoWriter::open(const QString& path, unsigned width, unsigned height,
                            unsigned fps, unsigned bitrate, unsigned gop)
{
    close();
    auto& d = *m_impl;
    d.cancelled = false;
    d.failed = false;
    d.frames = 0;
    d.finished = false;
    if (path.isEmpty() || !width || !height || width > 3840 || height > 2160
        || (width % 2) || (height % 2) || !fps || fps > 60 || !bitrate || !gop) {
        return d.fail("invalid MP4 options");
    }
    @autoreleasepool {
        d.outputPath = path;
        d.width = width;
        d.height = height;
        d.fps = fps;
        NSURL* url = fileUrl(path);
        NSError* error = nil;
        NSFileManager* files = [NSFileManager defaultManager];
        if ([files fileExistsAtPath:url.path] && ![files removeItemAtURL:url error:&error]) {
            return d.fail("cannot replace output", error);
        }
        d.writer = [[AVAssetWriter alloc] initWithURL:url fileType:AVFileTypeMPEG4 error:&error];
        if (!d.writer) {
            return d.fail("cannot create MP4 writer", error);
        }
        d.writer.shouldOptimizeForNetworkUse = YES;
        NSDictionary* settings = @{
            AVVideoCodecKey: AVVideoCodecTypeH264,
            AVVideoWidthKey: @(width),
            AVVideoHeightKey: @(height),
            AVVideoCompressionPropertiesKey: @{
                AVVideoAverageBitRateKey: @(bitrate),
                AVVideoExpectedSourceFrameRateKey: @(fps),
                AVVideoMaxKeyFrameIntervalKey: @(gop),
                AVVideoAllowFrameReorderingKey: @NO,
                AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel
            }
        };
        if (![d.writer canApplyOutputSettings:settings forMediaType:AVMediaTypeVideo]) {
            return d.fail("H.264 settings unavailable");
        }
        d.input = [AVAssetWriterInput assetWriterInputWithMediaType:AVMediaTypeVideo outputSettings:settings];
        d.input.expectsMediaDataInRealTime = NO;
        if (![d.writer canAddInput:d.input]) {
            return d.fail("cannot add video input");
        }
        [d.writer addInput:d.input];
        d.adaptor = [AVAssetWriterInputPixelBufferAdaptor assetWriterInputPixelBufferAdaptorWithAssetWriterInput:d.input
             sourcePixelBufferAttributes:@{
                 (NSString*)kCVPixelBufferPixelFormatTypeKey: @(kCVPixelFormatType_32BGRA),
                 (NSString*)kCVPixelBufferWidthKey: @(width),
                 (NSString*)kCVPixelBufferHeightKey: @(height),
                 (NSString*)kCVPixelBufferIOSurfacePropertiesKey: @{}
             }];
        if (![d.writer startWriting]) {
            return d.fail("cannot start H.264 encoding", d.writer.error);
        }
        [d.writer startSessionAtSourceTime:kCMTimeZero];
        return true;
    }
}

bool AppleVideoWriter::encodeImage(const QImage& image)
{
    auto& d = *m_impl;
    if (!d.writer || d.finished || hasError() || image.width() != int(d.width) || image.height() != int(d.height)) {
        return d.fail("invalid frame or inactive writer");
    }
    @autoreleasepool {
        if (!d.waitForInput()) {
            return false;
        }
        // On Apple little-endian targets ARGB32 is laid out as BGRA bytes.
        const QImage bgra = image.convertToFormat(QImage::Format_ARGB32);
        CVPixelBufferRef buffer = nullptr;
        if (!d.adaptor.pixelBufferPool
            || CVPixelBufferPoolCreatePixelBuffer(kCFAllocatorDefault, d.adaptor.pixelBufferPool, &buffer) != kCVReturnSuccess) {
            return d.fail("cannot allocate video frame");
        }
        if (CVPixelBufferLockBaseAddress(buffer, 0) != kCVReturnSuccess) {
            CVPixelBufferRelease(buffer);
            return d.fail("cannot lock video frame");
        }
        auto* dest = static_cast<unsigned char*>(CVPixelBufferGetBaseAddress(buffer));
        const size_t stride = CVPixelBufferGetBytesPerRow(buffer);
        for (unsigned y = 0; y < d.height; ++y) {
            std::memcpy(dest + y * stride, bgra.constScanLine(y), size_t(d.width) * 4);
        }
        CVPixelBufferUnlockBaseAddress(buffer, 0);
        const bool appended = [d.adaptor appendPixelBuffer:buffer withPresentationTime:CMTimeMake(d.frames, int32_t(d.fps))];
        CVPixelBufferRelease(buffer);
        if (!appended) {
            return d.fail("cannot encode video frame", d.writer.error);
        }
        ++d.frames;
        return true;
    }
}

bool AppleVideoWriter::finish()
{
    auto& d = *m_impl;
    if (d.finished) {
        return !hasError();
    }
    if (!d.writer || hasError() || !d.frames) {
        return d.fail("cannot finish empty or failed video");
    }
    @autoreleasepool {
        // Explicit end time retains the final frame for a full frame interval.
        [d.writer endSessionAtSourceTime:CMTimeMake(d.frames, int32_t(d.fps))];
        [d.input markAsFinished];
        dispatch_semaphore_t done = dispatch_semaphore_create(0);
        [d.writer finishWritingWithCompletionHandler:^{ dispatch_semaphore_signal(done); }];
        const auto deadline = std::chrono::steady_clock::now() + WAIT_LIMIT;
        while (dispatch_semaphore_wait(done, dispatch_time(DISPATCH_TIME_NOW, 50 * NSEC_PER_MSEC)) != 0) {
            if (d.cancelled || std::chrono::steady_clock::now() >= deadline) {
                [d.writer cancelWriting];
                return d.fail("video finalization cancelled or timed out", d.writer.error);
            }
        }
        d.finished = d.writer.status == AVAssetWriterStatusCompleted;
        return d.finished ? true : d.fail("cannot finalize MP4", d.writer.error);
    }
}

bool AppleVideoWriter::addAudio(const QString& path)
{
    auto& d = *m_impl;
    if (!d.finished || hasError()) {
        return d.fail("video must be finished before adding audio");
    }
    @autoreleasepool {
        AVURLAsset* video = [AVURLAsset URLAssetWithURL:fileUrl(d.outputPath) options:nil];
        AVURLAsset* audio = [AVURLAsset URLAssetWithURL:fileUrl(path) options:nil];
        AVAssetTrack* videoTrack = [video tracksWithMediaType:AVMediaTypeVideo].firstObject;
        AVAssetTrack* audioTrack = [audio tracksWithMediaType:AVMediaTypeAudio].firstObject;
        if (!videoTrack || !audioTrack) {
            return d.fail("cannot read video or AAC track");
        }
        AVMutableComposition* composition = [AVMutableComposition composition];
        AVMutableCompositionTrack* picture = [composition addMutableTrackWithMediaType:AVMediaTypeVideo
                                                                     preferredTrackID:kCMPersistentTrackID_Invalid];
        AVMutableCompositionTrack* sound = [composition addMutableTrackWithMediaType:AVMediaTypeAudio
                                                                   preferredTrackID:kCMPersistentTrackID_Invalid];
        NSError* error = nil;
        CMTime duration = video.duration;
        if (!CMTIME_IS_NUMERIC(duration) || CMTimeCompare(duration, kCMTimeZero) <= 0
            || ![picture insertTimeRange:CMTimeRangeMake(kCMTimeZero, duration) ofTrack:videoTrack atTime:kCMTimeZero error:&error]) {
            return d.fail("cannot insert video track", error);
        }
        picture.preferredTransform = videoTrack.preferredTransform;
        // ADTS includes AAC packet padding. Keep the picture duration unchanged.
        CMTime audioDuration = CMTimeMinimum(duration, audio.duration);
        if (!CMTIME_IS_NUMERIC(audioDuration) || CMTimeCompare(audioDuration, kCMTimeZero) <= 0
            || ![sound insertTimeRange:CMTimeRangeMake(kCMTimeZero, audioDuration) ofTrack:audioTrack atTime:kCMTimeZero error:&error]) {
            return d.fail("cannot insert AAC track", error);
        }
        QString tempPath = d.outputPath + "." + QUuid::createUuid().toString(QUuid::WithoutBraces) + ".mux.mp4";
        NSURL* tempUrl = fileUrl(tempPath);
        AVAssetExportSession* exporter = [[AVAssetExportSession alloc] initWithAsset:composition presetName:AVAssetExportPresetPassthrough];
        if (!exporter || ![exporter.supportedFileTypes containsObject:AVFileTypeMPEG4]) {
            return d.fail("MP4 audio muxing unavailable");
        }
        exporter.outputURL = tempUrl;
        exporter.outputFileType = AVFileTypeMPEG4;
        exporter.shouldOptimizeForNetworkUse = YES;
        exporter.timeRange = CMTimeRangeMake(kCMTimeZero, duration);
        dispatch_semaphore_t done = dispatch_semaphore_create(0);
        auto discardOutput = std::make_shared<std::atomic<bool>>(false);
        [exporter exportAsynchronouslyWithCompletionHandler:^{
            // Cancellation may finish after the caller returns. Clean up on
            // completion too, without capturing the C++ writer's lifetime.
            if (*discardOutput || exporter.status != AVAssetExportSessionStatusCompleted) {
                [[NSFileManager defaultManager] removeItemAtURL:tempUrl error:nil];
            }
            dispatch_semaphore_signal(done);
        }];
        const auto deadline = std::chrono::steady_clock::now() + WAIT_LIMIT;
        bool timedOut = false;
        while (dispatch_semaphore_wait(done, dispatch_time(DISPATCH_TIME_NOW, 50 * NSEC_PER_MSEC)) != 0) {
            if (d.cancelled || std::chrono::steady_clock::now() >= deadline) {
                timedOut = !d.cancelled;
                *discardOutput = true;
                [exporter cancelExport];
                // The completion handler still owns the exporter/semaphore.
                break;
            }
        }
        NSFileManager* files = [NSFileManager defaultManager];
        if (d.cancelled || timedOut || exporter.status != AVAssetExportSessionStatusCompleted) {
            [files removeItemAtURL:tempUrl error:nil];
            return d.fail("cannot mux audio into MP4", exporter.error);
        }
        // Replace only after a complete mux, preserving the video on failure.
        if (![files replaceItemAtURL:fileUrl(d.outputPath) withItemAtURL:tempUrl backupItemName:nil
                            options:0 resultingItemURL:nil error:&error]) {
            [files removeItemAtURL:tempUrl error:nil];
            return d.fail("cannot replace video with muxed MP4", error);
        }
        return true;
    }
}

void AppleVideoWriter::abort() { m_impl->cancelled = true; }
bool AppleVideoWriter::hasError() const { return m_impl->failed || m_impl->cancelled; }

void AppleVideoWriter::close()
{
    @autoreleasepool {
        auto& d = *m_impl;
        if (d.writer.status == AVAssetWriterStatusWriting) {
            [d.writer cancelWriting];
        }
        d.adaptor = nil;
        d.input = nil;
        d.writer = nil;
    }
}
}
