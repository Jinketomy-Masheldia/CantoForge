/* SPDX-License-Identifier: GPL-3.0-only */
#include "iosgesturebridge.h"

#import <UIKit/UIKit.h>
#import <objc/runtime.h>

#include <QByteArray>
#include <QDebug>
#include <QQuickWindow>

namespace {
char gestureProtectionKey;

UIRectEdge deferredEdges(id, SEL)
{
    return UIRectEdgeBottom;
}
}

void muse::ui::installIosGestureProtection(QQuickWindow* window)
{
    if (!window || UIDevice.currentDevice.userInterfaceIdiom != UIUserInterfaceIdiomPad) {
        return;
    }

    UIView* view = (__bridge UIView*)reinterpret_cast<void*>(window->winId());
    UIViewController* controller = view.window.rootViewController;
    if (!controller || objc_getAssociatedObject(controller, &gestureProtectionKey)) {
        return;
    }

    // Qt owns the native controller. Extend this instance with a subclass that
    // inherits Qt's rotation, keyboard, status-bar and lifecycle behavior.
    // Native document pickers and other presented UIKit controllers retain
    // their own system-gesture preferences.
    Class base = object_getClass(controller);
    const QByteArray name = QByteArray("CantoForgeGestureProtected_") + class_getName(base);
    Class subclass = objc_lookUpClass(name.constData());
    if (!subclass) {
        subclass = objc_allocateClassPair(base, name.constData(), 0);
        Method getter = class_getInstanceMethod(UIViewController.class,
                                               @selector(preferredScreenEdgesDeferringSystemGestures));
        if (!subclass || !getter
            || !class_addMethod(subclass, @selector(preferredScreenEdgesDeferringSystemGestures),
                                reinterpret_cast<IMP>(deferredEdges), method_getTypeEncoding(getter))) {
            if (subclass) {
                objc_disposeClassPair(subclass);
            }
            qWarning() << "Could not configure iPad bottom gesture protection";
            return;
        }
        objc_registerClassPair(subclass);
    }

    object_setClass(controller, subclass);
    objc_setAssociatedObject(controller, &gestureProtectionKey, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    [controller setNeedsUpdateOfScreenEdgesDeferringSystemGestures];
    qInfo() << "iPad bottom system gesture protection enabled";
}
