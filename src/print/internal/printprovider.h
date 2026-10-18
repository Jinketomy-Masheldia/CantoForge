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
#pragma once

#include "print/iprintprovider.h"

#include "global/modularity/ioc.h"
#include "ui/imainwindow.h"

#ifdef Q_OS_IOS
#include "iinteractive.h"
#include "project/inotationwritersregister.h"
#endif

namespace mu::print {
class PrintProvider : public IPrintProvider, public muse::Contextable, public std::enable_shared_from_this<PrintProvider>
{
    muse::ContextInject<muse::ui::IMainWindow> mainWindow{ this };
#ifdef Q_OS_IOS
    muse::ContextInject<muse::IInteractive> interactive{ this };
    muse::ContextInject<project::INotationWritersRegister> writers{ this };
    bool m_isPrinting = false;
#endif

public:
    explicit PrintProvider(const muse::modularity::ContextPtr&);

    muse::Ret printNotation(notation::INotationPtr notation) override;
};
}
