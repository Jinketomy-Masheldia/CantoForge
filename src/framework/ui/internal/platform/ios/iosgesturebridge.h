/* SPDX-License-Identifier: GPL-3.0-only */
#pragma once

class QQuickWindow;

namespace muse::ui {
// Give the editor priority over the bottom system gesture on iPad.
void installIosGestureProtection(QQuickWindow* window);
}
