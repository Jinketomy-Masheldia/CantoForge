/* SPDX-License-Identifier: GPL-3.0-only */
#pragma once
#include "media/ivideoencoderresolver.h"

namespace muse::media {
// A disabled media module must not pull in FFmpeg loaders and configuration.
class VideoEncoderResolverStub : public IVideoEncoderResolver
{
public:
    void loadFFmpeg(const io::path_t&) override {}
    io::path_t loadedFFmpegDir() const override { return {}; }
    FFmpegVersion loadedFFmpegVersion() const override { return FFMPEG_INVALID_VERSION; }
    async::Notification loadedFFmpegChanged() const override { return m_changed; }
    IVideoEncoderPtr currentVideoEncoder() const override { return m_encoder; }
    void setCurrentVideoEncoder(IVideoEncoderPtr encoder) override { m_encoder = encoder; }
    void setIsSettingMode(bool) override {}
private:
    IVideoEncoderPtr m_encoder;
    async::Notification m_changed;
};
}
