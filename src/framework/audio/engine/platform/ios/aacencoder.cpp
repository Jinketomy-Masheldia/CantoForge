/*
 * SPDX-License-Identifier: GPL-3.0-only
 * Copyright (C) 2026 Contributors to the unofficial MuseScore Studio iPadOS port
 */
#include "../../internal/export/aacencoder.h"
#include "appleaacwriter.h"

#include <limits>
#include "log.h"

using namespace muse::audio;
using namespace muse::audio::encode;

struct AacEncoderHandler {
    AppleAacWriter writer;
};

AacEncoder::~AacEncoder()
{
    closeDestination();
}

bool AacEncoder::init(const io::path_t& path, const SoundTrackFormat& format, const samples_t /*totalSamplesNumber*/)
{
    closeDestination();
    if (!format.isValid() || format.bitRate <= 0
        || static_cast<uint32_t>(format.bitRate) > std::numeric_limits<uint32_t>::max() / 1000u) {
        return false;
    }
    m_format = format;
    return openDestination(path);
}

bool AacEncoder::openDestination(const io::path_t& path)
{
    m_handler = new AacEncoderHandler();
    if (!m_handler->writer.open(path.toStdString(), m_format.outputSpec.sampleRate,
                               m_format.outputSpec.audioChannelCount, static_cast<uint32_t>(m_format.bitRate) * 1000u)) {
        LOGE() << "AudioToolbox AAC initialization failed: " << m_handler->writer.error();
        delete m_handler;
        m_handler = nullptr;
        return false;
    }
    return true;
}

size_t AacEncoder::encode(samples_t frames, const float* input)
{
    if (!m_handler || !m_handler->writer.write(frames, input)) {
        LOGE() << "AudioToolbox AAC encoding failed: " << (m_handler ? m_handler->writer.error() : -1);
        return 0;
    }
    return static_cast<size_t>(frames) * m_format.outputSpec.audioChannelCount;
}

bool AacEncoder::finalize()
{
    if (!m_handler) {
        return false;
    }
    if (!m_handler->writer.finish()) {
        LOGE() << "AudioToolbox AAC finalization failed: " << m_handler->writer.error();
        return false;
    }
    return true;
}

size_t AacEncoder::flush()
{
    finalize();
    return 0;
}

void AacEncoder::closeDestination()
{
    delete m_handler;
    m_handler = nullptr;
}

size_t AacEncoder::requiredOutputBufferSize(samples_t /*totalSamplesNumber*/) const
{
    return 0;
}

void AacEncoder::prepareOutputBuffer(samples_t /*totalSamplesNumber*/)
{
    m_outputBuffer.clear();
}
