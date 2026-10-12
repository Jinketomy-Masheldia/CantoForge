/* SPDX-License-Identifier: GPL-3.0-only */
#include "iostouchcontroller.h"

#include <QCoreApplication>
#include <QGuiApplication>
#include <QMouseEvent>
#include <QPainter>
#include <QQuickPaintedItem>
#include <QQuickWindow>
#include <QScopedValueRollback>

#ifdef Q_OS_IOS
#include "iospointerbridge.h"
#include "iosgesturebridge.h"
#endif

namespace muse::ui {
static constexpr int HOLD_INTERVAL = 600;

static bool isEditingTouchDrag(QQuickWindow* window)
{
    return window && window->property("museTouchDragEditing").toBool();
}

class HoldIndicator : public QQuickPaintedItem
{
public:
    explicit HoldIndicator(QQuickItem* parent) : QQuickPaintedItem(parent)
    {
        setSize(QSizeF(48, 48));
        setZ(1000000);
        setEnabled(false);
        setAcceptedMouseButtons(Qt::NoButton);
        setAcceptTouchEvents(false);
        setAntialiasing(true);
    }

    void setProgress(qreal progress)
    {
        m_progress = progress;
        update();
    }

    void paint(QPainter* painter) override
    {
        painter->setRenderHint(QPainter::Antialiasing);
        const QRectF circle(4, 4, 40, 40);
        painter->setBrush(QColor(35, 50, 70, 80));
        painter->setPen(QPen(QColor(230, 240, 255, 130), 2));
        painter->drawEllipse(circle);
        painter->setPen(QPen(QColor("#70a9ff"), 4, Qt::SolidLine, Qt::RoundCap));
        painter->drawArc(circle, 90 * 16, -qRound(360 * 16 * m_progress));
    }

private:
    qreal m_progress = 0;
};

IosTouchController::IosTouchController(QObject* parent) : QObject(parent)
{
    m_holdTimer.setSingleShot(true);
    m_holdTimer.setInterval(HOLD_INTERVAL);
    connect(&m_holdTimer, &QTimer::timeout, this, &IosTouchController::recognizeHold);
    m_feedbackTimer.setInterval(16);
    connect(&m_feedbackTimer, &QTimer::timeout, this, &IosTouchController::updateIndicator);
    qApp->installEventFilter(this);
}

IosTouchController::~IosTouchController()
{
    reset();
    delete m_indicator;
}

void IosTouchController::begin(QQuickWindow* window, QTouchEvent* event)
{
    reset();
    m_window = window;
    // The view sets this for the new press after Qt synthesizes its mouse
    // event. A window property also works with touchscreen exclusive grabs,
    // which are not exposed by QQuickWindow::mouseGrabberItem().
    window->setProperty("museTouchDragEditing", false);
    m_position = event->point(0).position();
    m_globalPosition = event->point(0).globalPosition();
    m_modifiers = event->modifiers();
    m_pendingBegin.reset(event->clone());
    if (!m_indicator || m_indicator->window() != window) {
        delete m_indicator;
        m_indicator = new HoldIndicator(window->contentItem());
    }
    m_indicator->setPosition(m_position - QPointF(24, 24));
    m_indicator->setProgress(0);
    // Brief taps do not flash the indicator; show it only after 150 ms.
    m_indicator->setVisible(false);
    m_elapsed.start();
    m_holdTimer.start();
    m_feedbackTimer.start();
}

void IosTouchController::updateIndicator()
{
    if (!m_window || !m_indicator || isEditingTouchDrag(m_window)) {
        reset();
        return;
    }
    m_indicator->setVisible(m_elapsed.elapsed() >= 150);
    m_indicator->setProgress(qMin(1.0, m_elapsed.elapsed() / qreal(HOLD_INTERVAL)));
}

void IosTouchController::recognizeHold()
{
    if (!m_pendingBegin || !m_window || !m_window->isVisible() || isEditingTouchDrag(m_window)) {
        reset();
        return;
    }
    const auto* device = m_pendingBegin->pointingDevice();
    m_pendingBegin.reset();
    m_recognized = true;
    m_feedbackTimer.stop();
    if (m_indicator) {
        m_indicator->setVisible(true);
        m_indicator->setProgress(1);
    }

    QPointer<QQuickWindow> window = m_window;
    QScopedValueRollback<bool> guard(m_dispatching, true);
    QTouchEvent cancel(QEvent::TouchCancel, device, m_modifiers);
    QCoreApplication::sendEvent(window, &cancel);
    if (!window) {
        reset();
        return;
    }
    QMouseEvent press(QEvent::MouseButtonPress, m_position, m_position, m_globalPosition,
                      Qt::RightButton, Qt::RightButton, m_modifiers);
    QCoreApplication::sendEvent(window, &press);
    if (!window) {
        reset();
        return;
    }
    QMouseEvent release(QEvent::MouseButtonRelease, m_position, m_position, m_globalPosition,
                        Qt::RightButton, Qt::NoButton, m_modifiers);
    QCoreApplication::sendEvent(window, &release);
    if (window) {
        QContextMenuEvent menu(QContextMenuEvent::Mouse, m_position.toPoint(), m_globalPosition.toPoint(), m_modifiers);
        QCoreApplication::sendEvent(window, &menu);
    }
}

void IosTouchController::reset()
{
    m_holdTimer.stop();
    m_feedbackTimer.stop();
    m_pendingBegin.reset();
    m_recognized = false;
    m_window.clear();
    if (m_indicator) {
        m_indicator->setVisible(false);
    }
}

bool IosTouchController::eventFilter(QObject* watched, QEvent* event)
{
    if (m_dispatching) {
        return false;
    }
    auto* window = qobject_cast<QQuickWindow*>(watched);
    if (!window) {
        return false;
    }
#ifdef Q_OS_IOS
    if (event->type() == QEvent::Show) {
        installIosPointerSupport(window);
    }
    if (event->type() == QEvent::Show || event->type() == QEvent::WindowActivate) {
        // Apply after UIKit has attached the Qt view to its native window.
        QTimer::singleShot(0, window, [window = QPointer<QQuickWindow>(window)] {
            if (window && window->isVisible()) {
                installIosGestureProtection(window);
            }
        });
    }
#endif
    if (window == m_window && (event->type() == QEvent::Hide
                              || (event->type() == QEvent::FocusOut && !m_recognized))) {
        reset();
        return false;
    }
    if (event->type() == QEvent::TouchBegin) {
        auto* touch = static_cast<QTouchEvent*>(event);
        // Menus own their touch selection; holding a menu row is not a right click.
        if (window->property("museImmediateTouch").toBool()
            || window->property("museIosIndirectPointer").toBool()) {
            reset();
            return false;
        }
        if (touch->pointCount() == 1 && touch->device()->type() == QInputDevice::DeviceType::TouchScreen) {
            begin(window, touch);
            return false;
        }
    } else if (window == m_window) {
        if (event->type() == QEvent::TouchCancel) {
            const bool consumed = m_recognized;
            reset();
            if (consumed) {
                event->accept();
            }
            return consumed;
        }
        if (event->type() == QEvent::TouchUpdate || event->type() == QEvent::TouchEnd) {
            auto* touch = static_cast<QTouchEvent*>(event);
            if (m_recognized) {
                if (event->type() == QEvent::TouchEnd) {
                    reset();
                }
                touch->accept();
                return true;
            }
            if (m_pendingBegin) {
                const bool moved = touch->pointCount() == 1
                                   && (touch->point(0).position() - m_position).manhattanLength()
                                   > 4;
                if (event->type() == QEvent::TouchEnd || touch->pointCount() > 1 || moved) {
                    reset();
                }
                return false;
            }
        }
    }
    return false;
}
}
