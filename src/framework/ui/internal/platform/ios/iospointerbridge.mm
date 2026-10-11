/* SPDX-License-Identifier: GPL-3.0-only */
#include "iospointerbridge.h"

#import <UIKit/UIKit.h>
#include <QCoreApplication>
#include <QContextMenuEvent>
#include <QDebug>
#include <QMouseEvent>
#include <QPointer>
#include <QQuickWindow>
#include <QTimer>

// Qt's iOS view handles pointer hover, but does not preserve UIKit's
// secondary button mask in its touch-to-mouse conversion. Recognize only
// indirect secondary clicks before they reach that conversion.
@interface MuseSecondaryClick : UITapGestureRecognizer <UIGestureRecognizerDelegate> {
    QPointer<QQuickWindow> _qtWindow;
}
- (instancetype)initWithQtWindow:(QQuickWindow*)window;
- (void)clicked:(UITapGestureRecognizer*)recognizer;
@end

@implementation MuseSecondaryClick
- (instancetype)initWithQtWindow:(QQuickWindow*)window
{
    self = [super initWithTarget:nil action:nil];
    if (self) {
        _qtWindow = window;
        [self addTarget:self action:@selector(clicked:)];
        self.delegate = self;
        self.allowedTouchTypes = @[@(UITouchTypeIndirectPointer)];
        self.buttonMaskRequired = UIEventButtonMaskSecondary;
        self.cancelsTouchesInView = YES;
        self.delaysTouchesBegan = YES;
        self.delaysTouchesEnded = NO;
    }
    return self;
}

- (BOOL)gestureRecognizer:(UIGestureRecognizer*)recognizer shouldReceiveEvent:(UIEvent*)event
{
    // Reject primary clicks immediately, so mouse dragging and all direct
    // finger input retain their normal delivery and latency.
    return event.type == UIEventTypeTouches && (event.buttonMask & UIEventButtonMaskSecondary) != 0;
}

- (BOOL)gestureRecognizer:(UIGestureRecognizer*)recognizer shouldReceiveTouch:(UITouch*)touch
{
    return touch.type == UITouchTypeIndirectPointer;
}

- (void)clicked:(UITapGestureRecognizer*)recognizer
{
    if (recognizer.state != UIGestureRecognizerStateRecognized || !_qtWindow) {
        return;
    }
    const CGPoint location = [recognizer locationInView:self.view];
    const QPointF position(location.x, location.y);
    qInfo() << "iPad secondary pointer click" << position;
    const QPointer<QQuickWindow> window = _qtWindow;
    // Finish UIKit's cancellation before opening a Qt popup. Capture the
    // original window: a newly opened menu must not receive this release.
    QTimer::singleShot(0, window, [window, position]() {
        if (!window || !window->isVisible()) {
            return;
        }
        const QPointF global = window->mapToGlobal(position);
        const auto modifiers = QGuiApplication::keyboardModifiers();
        QMouseEvent press(QEvent::MouseButtonPress, position, position, global,
                          Qt::RightButton, Qt::RightButton, modifiers);
        QCoreApplication::sendEvent(window, &press);
        if (!window) {
            return;
        }
        QMouseEvent release(QEvent::MouseButtonRelease, position, position, global,
                            Qt::RightButton, Qt::NoButton, modifiers);
        QCoreApplication::sendEvent(window, &release);
        if (window) {
            QContextMenuEvent context(QContextMenuEvent::Mouse, position.toPoint(), global.toPoint(), modifiers);
            QCoreApplication::sendEvent(window, &context);
        }
    });
}
@end

void muse::ui::installIosSecondaryClick(QQuickWindow* window)
{
    UIView* view = (__bridge UIView*)reinterpret_cast<void*>(window->winId());
    if (!view) {
        return;
    }
    for (UIGestureRecognizer* recognizer in view.gestureRecognizers) {
        if ([recognizer isKindOfClass:MuseSecondaryClick.class]) {
            return;
        }
    }
    MuseSecondaryClick* recognizer = [[MuseSecondaryClick alloc] initWithQtWindow:window];
    [view addGestureRecognizer:recognizer];
    [recognizer release];
}
