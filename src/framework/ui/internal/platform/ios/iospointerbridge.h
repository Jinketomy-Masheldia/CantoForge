/* SPDX-License-Identifier: GPL-3.0-only */
#pragma once

class QQuickWindow;

namespace muse::ui {
// Install once on the UIKit view backing each Qt window.
void installIosPointerSupport(QQuickWindow* window);
}
