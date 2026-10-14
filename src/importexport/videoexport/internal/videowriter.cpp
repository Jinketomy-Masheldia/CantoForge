/*
 * SPDX-License-Identifier: GPL-3.0-only
 * MuseScore-Studio-CLA-applies
 *
 * MuseScore Studio
 * Music Composition & Notation
 *
 * Copyright (C) 2021 MuseScore Limited and others
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
#include "videowriter.h"

#include <cmath>

#include <QPainter>
#include <QThread>

#include "global/concurrency/concurrent.h"
#include "io/buffer.h"
#include "io/file.h"

#include "engraving/dom/page.h"
#include "engraving/dom/repeatlist.h"
#include "engraving/dom/masterscore.h"

#include "notation/imasternotation.h"
#include "notation/notationtypes.h"

#include "notationscene/qml/MuseScore/NotationScene/playbackcursor.h"

#include "draw/fontmetrics.h"

#include "defer.h"
#include "log.h"

using namespace mu::iex::videoexport;
using namespace mu::project;
using namespace mu::notation;
using namespace muse::draw;
using namespace muse::midi;

static muse::String notationTitle(const INotationPtr notation)
{
    muse::String title;
    mu::engraving::Score* score = notation->elements()->msScore();
    mu::engraving::Score* masterScore = notation->masterNotation()->masterScore();

    if (const mu::engraving::Text* text = score->getText(mu::engraving::TextStyleType::TITLE)) {
        title = text->plainText();
    }

    if (title.isEmpty()) {
        if (const mu::engraving::Text* text = masterScore->getText(mu::engraving::TextStyleType::TITLE)) {
            title = text->plainText();
        }
    }

    if (title.isEmpty()) {
        title = masterScore->metaTag(u"workTitle");
    }

    return title;
}

static muse::String notationSubtitle(const INotationPtr notation)
{
    if (notation->isMaster()) {
        return muse::String();
    }

    return notation->name();
}

std::vector<INotationWriter::UnitType> VideoWriter::supportedUnitTypes() const
{
    return { UnitType::PER_PART };
}

bool VideoWriter::supportsUnitType(UnitType unitType) const
{
    std::vector<UnitType> unitTypes = supportedUnitTypes();
    return std::find(unitTypes.cbegin(), unitTypes.cend(), unitType) != unitTypes.cend();
}

muse::Ret VideoWriter::write(INotationPtr notation, muse::io::IODevice& device, const Options& options)
{
    std::string filePath = device.meta("file_path");
    IF_ASSERT_FAILED(!filePath.empty()) {
        return make_ret(muse::Ret::Code::InternalError);
    }

    bool withAudio = muse::value(options, OptionKey::WITH_AUDIO, muse::Val(true)).toBool();

    Config cfg = makeConfig();

    muse::io::path_t finalPath(filePath);
    muse::io::path_t tempAudioPath = finalPath + ".tmp_audio.aac";

    auto encoder = videoEncodeResolver()->currentVideoEncoder();
    if (!encoder) {
        return make_ret(muse::Ret::Code::NotSupported);
    }

    muse::media::IVideoEncoder::Options encoderOptions;
    encoderOptions.format = "mp4";
    encoderOptions.width = cfg.width;
    encoderOptions.height = cfg.height;
    encoderOptions.bitrate = cfg.bitrate;
    encoderOptions.gop = cfg.fps / 2;
    encoderOptions.fps = cfg.fps;

    if (!encoder->open(finalPath, encoderOptions)) {
        LOGE() << "failed to open video encoder";
        return make_ret(muse::Ret::Code::UnknownError);
    }

    m_isCompleted = false;
    m_audioCompleted = false;
    m_abort = false;
    m_writeRet = muse::Ret();
    m_audioRet = muse::Ret();

#ifdef Q_OS_IOS
    // Score layout and restoration must stay on the UI thread. Prepare before
    // either rendering or audio export starts, so both see a stable layout.
    auto restoreData = prepareScore(notation, cfg);
    if (!restoreData) {
        encoder->close();
        return make_ret(muse::Ret::Code::UnknownError);
    }
#endif
    m_progress.start();

    startVideoExport(encoder, notation, cfg);

    if (withAudio) {
        startAudioExport(notation, tempAudioPath, cfg);
    } else {
        m_audioCompleted = true;
        m_audioRet = muse::make_ok();
    }

    while (!m_isCompleted || !m_audioCompleted) {
        application()->processEvents();
        QThread::msleep(2);
    }

    if (m_audioWriter) {
        m_audioWriter->progress()->finished().disconnect(this);
        m_audioWriter = nullptr;
    }

#ifdef Q_OS_IOS
    restoreScore(notation, restoreData.value());
#endif

    muse::Ret result = m_writeRet;

    // Release the device's file handle before add audio replaces the file
    device.close();

    // AVFoundation finalization/muxing is asynchronous internally. Keep its
    // waits off the UI thread so the progress dialog can still be cancelled.
    m_finalizing = true;
    muse::Concurrent::run([this, encoder, withAudio, tempAudioPath, &result]() {
        if (result && !m_abort) {
            encoder->finishEncode();
            if (encoder->hasError()) {
                result = make_ret(muse::Ret::Code::UnknownError);
            }
            if (withAudio && result) {
                if (!m_audioRet) {
                    result = m_audioRet;
                } else if (!encoder->addAudio(tempAudioPath)) {
                    result = make_ret(muse::Ret::Code::UnknownError);
                }
            }
        }
        if (m_abort) {
            result = make_ret(muse::Ret::Code::Cancel);
        }
        encoder->close();
        m_finalizing = false;
    });
    while (m_finalizing) {
        application()->processEvents();
        QThread::msleep(2);
    }

    if (withAudio) {
        muse::io::File::remove(tempAudioPath);
    }
    m_progress.finish(result);
    return result;
}

VideoWriter::Config VideoWriter::makeConfig() const
{
    Config cfg;

    cfg.fps = configuration()->fps();

    std::string resolution = configuration()->resolution();
    if (resolution == "2160p") {
        cfg.width = 3840;
        cfg.height = 2160;
    } else if (resolution == "1440p") {
        cfg.width = 2560;
        cfg.height = 1440;
    } else if (resolution == "1080p") {
        cfg.width = 1920;
        cfg.height = 1080;
    } else if (resolution == "720p") {
        cfg.width = 1280;
        cfg.height = 720;
    } else if (resolution == "480p") {
        cfg.width = 854;
        cfg.height = 480;
    } else if (resolution == "360p") {
        cfg.width = 640;
        cfg.height = 360;
    } else {
        cfg.width = 1920;
        cfg.height = 1080;
    }

    // compute bitrate according to Google recommended settings
    // https://support.google.com/youtube/answer/1722171?hl=en
    float br = 8;
    if (cfg.height == 2160) {
        br = cfg.fps < 35 ? 40 : 60;
    } else if (cfg.height == 1440) {
        br = cfg.fps < 35 ? 16 : 24;
    } else if (cfg.height == 1080) {
        br = cfg.fps < 35 ? 10 : 15;
    } else if (cfg.height == 720) {
        br = cfg.fps < 35 ? 5 : 7.5;
    } else if (cfg.height == 480) {
        br = cfg.fps < 35 ? 2.5 : 4;
    } else if (cfg.height == 360) {
        br = cfg.fps < 35 ? 1 : 1.5;
    }
    cfg.bitrate = int(br * 1000000);

    cfg.leadingSec = configuration()->leadingSec();
    cfg.trailingSec = configuration()->trailingSec();

    cfg.viewMode = configuration()->viewMode();

    return cfg;
}

void VideoWriter::startVideoExport(muse::media::IVideoEncoderPtr encoder, INotationPtr notation, const Config& cfg)
{
    muse::Concurrent::run([this, encoder, notation, cfg]() {
        doGenerate(encoder, notation, cfg);
    });
}

void VideoWriter::startAudioExport(INotationPtr notation, const muse::io::path_t& audioPath, const Config& cfg)
{
    m_audioWriter = writers()->writer("aac");
    if (!m_audioWriter) {
        LOGE() << "aac writer not found";
        m_audioRet = make_ret(muse::Ret::Code::InternalError);
        m_audioCompleted = true;
        return;
    }

    m_audioWriter->progress()->finished().onReceive(this, [this](const muse::ProgressResult& res) {
        m_audioRet = res.ret;
        m_audioCompleted = true;
    });

    Options audioOpts;
    audioOpts[OptionKey::WAIT_FOR_COMPLETION] = muse::Val(false);
    audioOpts[OptionKey::LEADING_SILENCE_SEC] = muse::Val(static_cast<double>(cfg.leadingSec));
    audioOpts[OptionKey::TRAILING_SILENCE_SEC] = muse::Val(static_cast<double>(cfg.trailingSec));

    muse::io::Buffer audioDevice;
    audioDevice.setMeta("file_path", audioPath.toStdString());
    audioDevice.open(muse::io::IODevice::WriteOnly);

    muse::Ret ret = m_audioWriter->write(notation, audioDevice, audioOpts);
    // Undefined is the existing asynchronous writer's "still running" result.
    if (!ret && ret.code() != int(muse::Ret::Code::Undefined) && !m_audioCompleted) {
        m_audioRet = ret;
        m_audioCompleted = true;
    }
}

muse::Ret VideoWriter::writeList(const INotationPtrList&, muse::io::IODevice&, const Options&)
{
    NOT_SUPPORTED;
    return make_ret(muse::Ret::Code::NotSupported);
}

muse::Progress* VideoWriter::progress()
{
    return &m_progress;
}

void VideoWriter::abort()
{
    m_abort = true;

    if (auto encoder = videoEncodeResolver()->currentVideoEncoder()) {
        encoder->abort();
    }

    if (m_audioWriter) {
        m_audioWriter->abort();
        m_audioRet = make_ret(muse::Ret::Code::Cancel);
        m_audioCompleted = true;
    }

    // Wait abort completion
    while (!m_isCompleted || !m_audioCompleted || m_finalizing) {
        application()->processEvents();
        QThread::msleep(2);
    }
}

std::optional<VideoWriter::ScoreRestoreData> VideoWriter::prepareScore(INotationPtr notation, Config& config)
{
    ScoreRestoreData result;
    engraving::Score* score = notation->elements()->msScore();

    result.style = score->style();

    result.layoutMode = score->layoutMode();

    result.showFrames = score->showFrames();
    result.showInstrumentNames = score->showInstrumentNames();
    result.showInvisible = score->isShowInvisible();
    result.showPageborders = score->showPageborders();
    result.showUnprintable = score->showUnprintable();
    result.showVBox = score->layoutOptions().isShowVBox;

    score->setLayoutMode(engraving::LayoutMode::PAGE);

    score->setShowFrames(false);
    score->setShowInvisible(false);
    score->setShowPageborders(false);
    score->setShowUnprintable(false);

    if (config.viewMode == ViewMode::Flexible) {
        score->setShowInstrumentNames(false);
        score->setShowVBox(false);
    }

    score->doLayout();

    PageList pages = notation->elements()->pages();
    if (pages.empty()) {
        LOGE() << "No pages";
        restoreScore(notation, result);
        return std::nullopt;
    }

    const Page* page = pages.front();

    if (config.viewMode == ViewMode::PageFull) {
        double scaleX = config.width / page->width();
        double scaleY = config.height / page->height();
        double scale = std::min(scaleX, scaleY);
        config.canvasDpi = scale * engraving::DPI;
        config.moveToCenter = muse::PointF(0.5 * (config.width / scale - page->width()), 0.5 * (config.height / scale - page->height()));
        return result;
    }

    if (score->staves().size() > 3) {
        //! NOTE: Calculate the dpi to display all page elements
        double originalPageHeight = page->height() - score->style().styleD(engraving::Sid::pageOddTopMargin)
                                    - score->style().styleD(engraving::Sid::pageOddBottomMargin);
        double margin = 100.0;
        double ttboxHeight = originalPageHeight + margin * 2;
        double scale = config.height / ttboxHeight;
        config.canvasDpi = scale * engraving::DPI;
    }

    score->style().set(engraving::Sid::pageHeight, config.height / config.canvasDpi);
    score->style().set(engraving::Sid::pageWidth, config.width / config.canvasDpi);
    score->style().set(engraving::Sid::pagePrintableWidth, score->style().styleD(engraving::Sid::pageWidth)
                       - score->style().styleD(engraving::Sid::pageOddLeftMargin)
                       - score->style().styleD(engraving::Sid::pageEvenLeftMargin));

    score->style().set(engraving::Sid::pageEvenTopMargin, 0.0);
    score->style().set(engraving::Sid::pageEvenBottomMargin, 0.0);
    score->style().set(engraving::Sid::pageOddTopMargin, 0.0);
    score->style().set(engraving::Sid::pageOddBottomMargin, 0.0);
    score->style().set(engraving::Sid::pageTwosided, false);
    score->style().set(engraving::Sid::showHeader, false);
    score->style().set(engraving::Sid::showFooter, false);

    score->style().set(engraving::Sid::minSystemDistance, engraving::Spatium(10));
    score->style().set(engraving::Sid::maxSystemDistance, engraving::Spatium(10));
    score->style().set(engraving::Sid::staffLowerBorder, engraving::Spatium(5));
    score->style().set(engraving::Sid::staffUpperBorder, engraving::Spatium(7));

    score->setLayoutAll();
    score->doLayout();

    return result;
}

void VideoWriter::restoreScore(INotationPtr notation, const ScoreRestoreData& data)
{
    engraving::Score* score = notation->elements()->msScore();

    score->style() = data.style;

    score->setShowFrames(data.showFrames);
    score->setShowInstrumentNames(data.showInstrumentNames);
    score->setShowInvisible(data.showInvisible);
    score->setShowPageborders(data.showPageborders);
    score->setShowUnprintable(data.showUnprintable);
    score->setShowVBox(data.showVBox);

    score->setLayoutMode(data.layoutMode);

    score->setLayoutAll();
    score->update();
}

void VideoWriter::doGenerate(muse::media::IVideoEncoderPtr encoder, INotationPtr notation, const Config& config)
{
    Config actualConfig = config;
#ifndef Q_OS_IOS
    auto restoreData = prepareScore(notation, actualConfig);
    if (!restoreData) {
        m_writeRet = make_ret(muse::Ret::Code::UnknownError);
        m_isCompleted = true;
        return;
    }
#endif

    DEFER {
#ifndef Q_OS_IOS
        restoreScore(notation, restoreData.value());
#endif
        m_isCompleted = true;
    };

    // Setup painting
    QImage frame(actualConfig.width, actualConfig.height, QImage::Format_RGB32);
    frame.fill(Qt::black);
    frame.setDotsPerMeterX(std::lrint((actualConfig.canvasDpi * 1000) / engraving::INCH));
    frame.setDotsPerMeterY(std::lrint((actualConfig.canvasDpi * 1000) / engraving::INCH));

    QPainter qp(&frame);
    qp.setRenderHint(QPainter::Antialiasing, true);
    qp.setRenderHint(QPainter::TextAntialiasing, true);

    Painter painter(&qp, "video_writer");

    // Setup duration
    INotationPlaybackPtr playback = notation->masterNotation()->playback();
    float totalPlayTimeSec = playback->totalPlayTime();

    int leadingFrameCount = static_cast<int>(actualConfig.leadingSec * actualConfig.fps);
    int scoreFrameCount = static_cast<int>(totalPlayTimeSec * actualConfig.fps);
    int trailingFrameCount = static_cast<int>(actualConfig.trailingSec * actualConfig.fps);
    int totalFrameCount = leadingFrameCount + scoreFrameCount + trailingFrameCount;
    LOGI() << "totalPlayTime: " << totalPlayTimeSec << " sec" << " frame count " << totalFrameCount;

    // Add score title
    if (!generateLeadingFrames(encoder, notation, painter, frame, actualConfig, totalFrameCount)) {
        return;
    }

    // Add score frames
    if (!generateScoreFrames(encoder, notation, painter, frame, actualConfig, totalPlayTimeSec, leadingFrameCount, totalFrameCount)) {
        return;
    }

    // iOS holds the final score frame; desktop retains its existing outro.
    if (!generateTrailingFrames(encoder, actualConfig, frame)) {
        return;
    }

    m_writeRet = muse::make_ok();
}

bool VideoWriter::encodeFrame(muse::media::IVideoEncoderPtr encoder, const QImage& frame)
{
    if (!m_abort && encoder->encodeImage(frame)) {
        return true;
    }
    m_writeRet = make_ret(m_abort ? muse::Ret::Code::Cancel : muse::Ret::Code::UnknownError);
    return false;
}

bool VideoWriter::generateLeadingFrames(muse::media::IVideoEncoderPtr encoder, INotationPtr notation,
                                        Painter& painter, QImage& frame,
                                        const Config& config, int totalFrameCount)
{
    int leadingFrameCount = static_cast<int>(config.leadingSec * config.fps);
    if (leadingFrameCount <= 0) {
        return true;
    }

    muse::String title = notationTitle(notation);
    muse::String subtitle = notationSubtitle(notation);

    auto scaledFontPointSize = [&config](double basePixelSize) {
        double pixelSize = basePixelSize * config.height / 1080.0;
        return pixelSize * 72.0 / engraving::DPI;
    };

    Font titleFont(Font::FontFamily(u"Muse Sans"), Font::Type::Text);
    titleFont.setPointSizeF(scaledFontPointSize(128.0));
    titleFont.setWeight(Font::Weight::Medium);

    Font subtitleFont(titleFont);
    subtitleFont.setPointSizeF(scaledFontPointSize(48.0));

    muse::RectF frameRect = muse::RectF::fromQRectF(QRectF(frame.rect()));

    const double maxTextWidth = frameRect.width() * 0.9;
    const double textLeft = (frameRect.width() - maxTextWidth) / 2.0;

    auto lineCount = [&](const FontMetrics& fm, const muse::String& text) {
        if (text.isEmpty()) {
            return 0;
        }
        double textWidth = fm.horizontalAdvance(text);
        return std::max(1, static_cast<int>(std::ceil(textWidth / maxTextWidth)));
    };

    FontMetrics titleFontMetrics(titleFont);
    const int titleLines = lineCount(titleFontMetrics, title);
    const double titleHeight = titleLines * titleFontMetrics.lineSpacing();

    FontMetrics subtitleFontMetrics(subtitleFont);
    const int subtitleLines = lineCount(subtitleFontMetrics, subtitle);
    const double subtitleHeight = subtitleLines * subtitleFontMetrics.lineSpacing();

    double centerY = frameRect.center().y();
    double titleTop = centerY - titleHeight / 2.0;
    muse::RectF titleRect(textLeft, titleTop, maxTextWidth, titleHeight);

    const double subtitleOffset = config.height / 20.0;
    double subtitleTop = titleRect.bottom() + subtitleOffset;
    muse::RectF subtitleRect(textLeft, subtitleTop, maxTextWidth, subtitleHeight);

    const int textFlags = AlignCenter | TextWordWrap;

    for (int f = 0; f < leadingFrameCount; f++) {
        if (m_abort) {
            m_writeRet = make_ret(muse::Ret::Code::Cancel);
            return false;
        }

        m_progress.progress(f, totalFrameCount);

        painter.fillRect(frameRect, Color::BLACK);
        painter.setPen(Color::WHITE);
        painter.setFont(titleFont);
        painter.drawText(titleRect, textFlags, title);

        if (!subtitle.isEmpty()) {
            painter.setFont(subtitleFont);
            painter.drawText(subtitleRect, textFlags, subtitle);
        }

        if (!encodeFrame(encoder, frame)) {
            return false;
        }
    }

    return true;
}

bool VideoWriter::generateTrailingFrames(muse::media::IVideoEncoderPtr encoder, const Config& config, const QImage& lastFrame)
{
    int trailingFrameCount = static_cast<int>(config.trailingSec * config.fps);
    if (trailingFrameCount <= 0) {
        return true;
    }

#ifdef Q_OS_IOS
    for (int f = 0; f < trailingFrameCount; ++f) {
        if (!encodeFrame(encoder, lastFrame)) {
            return false;
        }
    }
    return true;
#else
    Q_UNUSED(lastFrame);
    static const muse::io::path_t RESOURCE_PATH = ":/videoexport/internal/resources/video_made_with.mp4";

    muse::io::File resource(RESOURCE_PATH);
    if (!resource.open(muse::io::File::ReadOnly)) {
        return true;
    }

    muse::ByteArray videoData = resource.readAll();
    resource.close();

    if (!encoder->encodeVideo(videoData, trailingFrameCount)) {
        m_writeRet = make_ret(muse::Ret::Code::UnknownError);
        return false;
    }
    return true;
#endif
}

bool VideoWriter::generateScoreFrames(muse::media::IVideoEncoderPtr encoder, INotationPtr notation,
                                      Painter& painter, QImage& frame,
                                      const Config& config, float totalPlayTimeSec,
                                      int leadingFrameCount, int totalFrameCount)
{
    int scoreFrameCount = static_cast<int>(totalPlayTimeSec * config.fps);
    if (scoreFrameCount <= 0) {
        return true;
    }

    PageList pages = notation->elements()->pages();
    auto painting = notation->painting();
    INotationPlaybackPtr playback = notation->masterNotation()->playback();
    muse::RectF frameRect = muse::RectF::fromQRectF(QRectF(frame.rect()));

    auto pageByTick = [](const PageList& pages, tick_t tick) -> const Page* {
        for (const Page* p : pages) {
            if (tick < static_cast<tick_t>(p->endTick().ticks())) {
                return p;
            }
        }
        return nullptr;
    };

    const Color CURSOR_COLOR = Color(2, 109, 203, 127);

    PlaybackCursor cursor(iocContext());
    cursor.setNotation(notation);

    for (int f = 0; f < scoreFrameCount; f++) {
        if (m_abort) {
            m_writeRet = make_ret(muse::Ret::Code::Cancel);
            return false;
        }

        m_progress.progress(leadingFrameCount + f, totalFrameCount);

        float currentTimeSec = static_cast<float>(f) / config.fps;
        if (currentTimeSec > totalPlayTimeSec) {
            currentTimeSec = totalPlayTimeSec;
        }

        tick_t tick = playback->secToTick(currentTimeSec);

        const Page* page = pageByTick(pages, tick);
        if (!page) {
            break;
        }

        if (!page->firstMeasure()) {
            // Skip pages with no notation
            continue;
        }

        INotationPainting::Options opt;
        opt.fromPage = static_cast<int>(page->pageNumber());
        opt.toPage = opt.fromPage;
        opt.deviceDpi = config.canvasDpi;

        painter.fillRect(frameRect, Color::BLACK);

        painter.save();
        painter.translate(config.moveToCenter);

        painting->paintPrint(&painter, opt);

        cursor.move(tick);

        muse::RectF cursorRect = cursor.rect();
        muse::PointF pagePos = page->pos();
        muse::RectF cursorAbsRect = cursorRect.translated(-pagePos);

        painter.fillRect(cursorAbsRect, CURSOR_COLOR);

        painter.restore();

        if (!encodeFrame(encoder, frame)) {
            return false;
        }
    }

    return true;
}
