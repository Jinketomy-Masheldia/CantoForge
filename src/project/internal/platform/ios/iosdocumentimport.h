/* SPDX-License-Identifier: GPL-3.0-only */
#pragma once
#include "io/path.h"
#include "types/retval.h"

namespace mu::project {
// External Files providers grant temporary access. Keep an editable local copy
// so saving, autosave, and recent files do not depend on that access remaining.
muse::RetVal<muse::io::path_t> importIosDocument(const muse::io::path_t& path);
}
