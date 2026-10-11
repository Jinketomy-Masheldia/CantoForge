/* SPDX-License-Identifier: GPL-3.0-only */
#pragma once

#include <QObject>
#include <memory>
#include "iaudiodriver.h"

namespace muse::audio {
class IosAudioDriver : public QObject, public IAudioDriver
{
public:
    IosAudioDriver();
    ~IosAudioDriver() override;
    void init() override;
    std::string name() const override { return "CoreAudio"; }
    AudioDeviceID defaultDevice() const override { return DEFAULT_DEVICE_ID; }
    bool open(const Spec& spec, Spec* activeSpec) override;
    void close() override;
    bool isOpened() const override;
    const Spec& activeSpec() const override;
    async::Channel<Spec> activeSpecChanged() const override { return m_specChanged; }
    AudioDeviceList availableOutputDevices() const override;
    async::Notification availableOutputDevicesChanged() const override { return m_devicesChanged; }
    std::vector<samples_t> availableOutputDeviceBufferSizes() const override;
    std::vector<sample_rate_t> availableOutputDeviceSampleRates() const override;

private:
    void resume();
    struct Data;
    std::unique_ptr<Data> m_data;
    async::Channel<Spec> m_specChanged;
    async::Notification m_devicesChanged;
};
}
