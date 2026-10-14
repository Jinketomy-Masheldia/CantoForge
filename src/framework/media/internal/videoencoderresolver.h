/*
 * SPDX-License-Identifier: GPL-3.0-only
 * MuseScore-Studio-CLA-applies
 *
 * MuseScore Studio
 * Music Composition & Notation
 *
 * Copyright (C) 2025 MuseScore Limited and others
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License version 3 as
 * published by the Free Software Foundation.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <https://www.gnu.org/licenses/>.
 */

#pragma once

#include "modularity/ioc.h"
#include "async/asyncable.h"
#include "io/filesystemwatcher.h"
#include "imediaconfiguration.h"

#ifndef Q_OS_IOS
#include "ffmpegutils.h"
#endif

#include "../ivideoencoderresolver.h"

namespace muse {
class Timer;
}

namespace muse::media {
class VideoEncoderResolver : public IVideoEncoderResolver, public muse::async::Asyncable
{
    GlobalInject<IMediaConfiguration> configuration;

public:
    void init();
    void deinit();

    void loadFFmpeg(const muse::io::path_t& ffmpegLibsDir) override;
    io::path_t loadedFFmpegDir() const override;
    FFmpegVersion loadedFFmpegVersion() const override;
    async::Notification loadedFFmpegChanged() const override;

    IVideoEncoderPtr currentVideoEncoder() const override;
    void setCurrentVideoEncoder(IVideoEncoderPtr encoder) override;

    void setIsSettingMode(bool arg) override;

private:
#ifndef Q_OS_IOS
    void resetFFmpegSettings();
    void startWatchingFfmpegsDirs();

    struct EncoderInfo {
        IVideoEncoderPtr encoder;
        FFmpegVersion ffmpegVersion = FFMPEG_INVALID_VERSION;
        io::path_t ffmpegLibsDir;
    };

    EncoderInfo makeEncoder(const FFmpegLibPaths& ffmpegLibsPaths) const;
#endif

    IVideoEncoderPtr m_encoder;
#ifndef Q_OS_IOS
    FFmpegVersion m_currentEncoderFFmpegVersion = FFMPEG_INVALID_VERSION;
#endif

    async::Notification m_loadedFFmpegChanged;

#ifndef Q_OS_IOS
    muse::io::FileSystemWatcher m_ffmpegLibWatcher;
    std::shared_ptr<Timer> m_reloadFfmpegTimer;
#endif
};
}
