/* SPDX-License-Identifier: GPL-3.0-only */
#pragma once

#include <QElapsedTimer>
#include <QPointer>
#include <QTimer>
#include <QTouchEvent>
#include <memory>

class QQuickWindow;

namespace muse::ui {
class HoldIndicator;

// Observe touch events without delaying Qt's normal scrolling or button feedback.
// A recognized hold cancels the active touch grab before sending a right click.
class IosTouchController : public QObject
{
public:
    explicit IosTouchController(QObject* parent = nullptr);
    ~IosTouchController() override;

protected:
    bool eventFilter(QObject* watched, QEvent* event) override;

private:
    void begin(QQuickWindow* window, QTouchEvent* event);
    void recognizeHold();
    void reset();
    void updateIndicator();

    QPointer<QQuickWindow> m_window;
    QPointer<HoldIndicator> m_indicator;
    std::unique_ptr<QTouchEvent> m_pendingBegin;
    QTimer m_holdTimer;
    QTimer m_feedbackTimer;
    QElapsedTimer m_elapsed;
    QPointF m_position;
    QPointF m_globalPosition;
    Qt::KeyboardModifiers m_modifiers = Qt::NoModifier;
    bool m_dispatching = false;
    bool m_recognized = false;
};
}
