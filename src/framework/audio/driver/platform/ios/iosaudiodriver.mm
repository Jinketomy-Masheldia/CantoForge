/* SPDX-License-Identifier: GPL-3.0-only */
#include "iosaudiodriver.h"

#import <AVFAudio/AVFAudio.h>
#import <AudioToolbox/AudioToolbox.h>
#include <QGuiApplication>
#include <cstring>
#include "log.h"

using namespace muse::audio;

struct IosAudioDriver::Data {
    AudioQueueRef queue = nullptr;
    Spec spec;
    id interruptionObserver = nil;
    id routeObserver = nil;
    bool interrupted = false;

    static void fill(void* context, AudioQueueRef queue, AudioQueueBufferRef buffer)
    {
        auto* data = static_cast<Data*>(context);
        // Queue disposal waits for in-flight callbacks before Data is destroyed.
        data->spec.callback(static_cast<uint8_t*>(buffer->mAudioData), buffer->mAudioDataByteSize);
        AudioQueueEnqueueBuffer(queue, buffer, 0, nullptr);
    }
};

IosAudioDriver::IosAudioDriver() : m_data(std::make_unique<Data>()) {}

IosAudioDriver::~IosAudioDriver()
{
    NSNotificationCenter* center = [NSNotificationCenter defaultCenter];
    if (m_data->interruptionObserver) {
        [center removeObserver:m_data->interruptionObserver];
    }
    if (m_data->routeObserver) {
        [center removeObserver:m_data->routeObserver];
    }
    close();
}

void IosAudioDriver::init()
{
    NSNotificationCenter* center = [NSNotificationCenter defaultCenter];
    m_data->interruptionObserver = [center addObserverForName:AVAudioSessionInterruptionNotification
        object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification* note) {
        const auto type = [note.userInfo[AVAudioSessionInterruptionTypeKey] unsignedIntegerValue];
        m_data->interrupted = type == AVAudioSessionInterruptionTypeBegan;
        if (m_data->queue && m_data->interrupted) {
            AudioQueuePause(m_data->queue);
        } else if ([note.userInfo[AVAudioSessionInterruptionOptionKey] unsignedIntegerValue]
                   & AVAudioSessionInterruptionOptionShouldResume) {
            resume();
        }
    }];
    m_data->routeObserver = [center addObserverForName:AVAudioSessionRouteChangeNotification
        object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification*) {
        // AudioQueue follows the system route; the device list represents that route.
        m_devicesChanged.notify();
    }];
    connect(qGuiApp, &QGuiApplication::applicationStateChanged, this, [this](Qt::ApplicationState state) {
        if (state == Qt::ApplicationActive) {
            resume();
        } else if (state == Qt::ApplicationSuspended || state == Qt::ApplicationHidden) {
            if (m_data->queue) {
                AudioQueuePause(m_data->queue);
            }
        }
    });
}

bool IosAudioDriver::open(const Spec& spec, Spec* active)
{
    if (isOpened() || !spec.isValid()) {
        return false;
    }
    AVAudioSession* session = [AVAudioSession sharedInstance];
    NSError* error = nil;
    if (![session setCategory:AVAudioSessionCategoryPlayback error:&error]
        || ![session setActive:YES error:&error]) {
        LOGE() << "iOS audio session: " << [[error localizedDescription] UTF8String];
        return false;
    }
    [session setPreferredSampleRate:spec.output.sampleRate error:nil];
    [session setPreferredIOBufferDuration:double(spec.output.samplesPerChannel) / spec.output.sampleRate error:nil];
    m_data->spec = spec;
    m_data->spec.deviceId = DEFAULT_DEVICE_ID;

    AudioStreamBasicDescription format = {};
    format.mSampleRate = spec.output.sampleRate;
    format.mFormatID = kAudioFormatLinearPCM;
    format.mFormatFlags = kAudioFormatFlagsNativeFloatPacked;
    format.mChannelsPerFrame = spec.output.audioChannelCount;
    format.mBitsPerChannel = 32;
    format.mFramesPerPacket = 1;
    format.mBytesPerFrame = sizeof(float) * format.mChannelsPerFrame;
    format.mBytesPerPacket = format.mBytesPerFrame;

    OSStatus status = AudioQueueNewOutput(&format, Data::fill, m_data.get(), nullptr, nullptr, 0, &m_data->queue);
    if (status != noErr) {
        LOGE() << "AudioQueueNewOutput: " << status;
        close();
        return false;
    }
    const UInt32 bytes = spec.output.samplesPerChannel * format.mBytesPerFrame;
    for (int i = 0; i < 3; ++i) {
        AudioQueueBufferRef buffer = nullptr;
        status = AudioQueueAllocateBuffer(m_data->queue, bytes, &buffer);
        if (status != noErr) {
            close();
            return false;
        }
        buffer->mAudioDataByteSize = bytes;
        std::memset(buffer->mAudioData, 0, bytes);
        status = AudioQueueEnqueueBuffer(m_data->queue, buffer, 0, nullptr);
        if (status != noErr) {
            close();
            return false;
        }
    }
    status = AudioQueueStart(m_data->queue, nullptr);
    if (status != noErr) {
        LOGE() << "AudioQueueStart: " << status;
        close();
        return false;
    }
    if (active) {
        *active = m_data->spec;
    }
    m_specChanged.send(m_data->spec);
    return true;
}

void IosAudioDriver::close()
{
    if (m_data->queue) {
        AudioQueueStop(m_data->queue, true);
        AudioQueueDispose(m_data->queue, true);
        m_data->queue = nullptr;
    }
}

void IosAudioDriver::resume()
{
    if (m_data->queue && !m_data->interrupted && qGuiApp->applicationState() == Qt::ApplicationActive) {
        NSError* error = nil;
        if ([[AVAudioSession sharedInstance] setActive:YES error:&error]) {
            AudioQueueStart(m_data->queue, nullptr);
        }
    }
}

bool IosAudioDriver::isOpened() const { return m_data->queue != nullptr; }
const IosAudioDriver::Spec& IosAudioDriver::activeSpec() const { return m_data->spec; }
AudioDeviceList IosAudioDriver::availableOutputDevices() const
{
    return { { DEFAULT_DEVICE_ID, "System output" } };
}
std::vector<samples_t> IosAudioDriver::availableOutputDeviceBufferSizes() const
{
    return { 128, 256, 512, 1024, 2048 };
}
std::vector<sample_rate_t> IosAudioDriver::availableOutputDeviceSampleRates() const
{
    return { 44100, 48000 };
}
