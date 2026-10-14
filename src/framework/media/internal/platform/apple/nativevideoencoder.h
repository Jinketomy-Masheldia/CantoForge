// SPDX-License-Identifier: GPL-3.0-only
// Copyright (C) 2026 CantoForge contributors
#pragma once

#include "media/ivideoencoder.h"
#include "applevideowriter.h"

namespace muse::media {
class NativeVideoEncoder : public IVideoEncoder
{
public:
    bool open(const io::path_t& path, const Options& options) override
    {
        return options.format == "mp4" && m_writer.open(path.toQString(), options.width, options.height,
                                                       options.fps, options.bitrate, options.gop);
    }
    bool encodeImage(const QImage& image) override { return m_writer.encodeImage(image); }
    void finishEncode() override { m_writer.finish(); }
    bool addAudio(const io::path_t& path) override { return m_writer.addAudio(path.toQString()); }
    void close() override { m_writer.close(); }
    void abort() override { m_writer.abort(); }
    bool hasError() const override { return m_writer.hasError(); }
    // iOS uses the last score frame for the outro instead of an embedded clip.
    bool encodeVideo(const ByteArray&, int = -1) override { return false; }

private:
    AppleVideoWriter m_writer;
};
}
