// SPDX-License-Identifier: GPL-3.0-only
// Copyright (C) 2026 CantoForge contributors
#pragma once

#include <memory>
#include <QImage>
#include <QString>

namespace muse::media {
// Platform implementation kept independent of the application IoC so the
// actual encoder and audio muxer can also be exercised on the host Mac.
class AppleVideoWriter
{
public:
    AppleVideoWriter();
    ~AppleVideoWriter();
    AppleVideoWriter(const AppleVideoWriter&) = delete;
    AppleVideoWriter& operator=(const AppleVideoWriter&) = delete;

    bool open(const QString& path, unsigned width, unsigned height, unsigned fps,
              unsigned bitrate, unsigned gop);
    bool encodeImage(const QImage& image);
    bool finish();
    bool addAudio(const QString& path);
    void abort();
    void close();
    bool hasError() const;

private:
    struct Impl;
    std::unique_ptr<Impl> m_impl;
};
}
