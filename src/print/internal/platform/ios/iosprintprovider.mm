// SPDX-License-Identifier: GPL-3.0-only
// Copyright (C) 2026 CantoForge contributors
#include "internal/printprovider.h"

#import <UIKit/UIKit.h>

#include <QGuiApplication>
#include <QThread>
#include <QTimer>
#include <QWindow>

#include "io/buffer.h"
#include "notation/inotationpainting.h"
#include "project/inotationwriter.h"
#include "defer.h"
#include "log.h"
#include "translation.h"

using namespace muse;
using namespace mu::notation;
using namespace mu::project;

namespace mu::print {
PrintProvider::PrintProvider(const muse::modularity::ContextPtr& iocCtx)
    : Contextable(iocCtx)
{
}

Ret PrintProvider::printNotation(INotationPtr notation)
{
    if (!notation || !qGuiApp || QThread::currentThread() != qGuiApp->thread()) {
        return make_ret(Ret::Code::InternalError);
    }
    // Repeated shortcuts must not toggle the shared system popover or replace
    // the PDF while a previous print job is still using it.
    if (m_isPrinting) {
        return make_ok();
    }

    @autoreleasepool {
        if (![UIPrintInteractionController isPrintingAvailable]) {
            return make_ret(Ret::Code::NotSupported,
                            trc("cantoforge/print", "Printing is unavailable on this device. You can export a PDF and print it from Files."));
        }
        QWindow* window = mainWindow() ? mainWindow()->qWindow() : nullptr;
        UIView* view = window ? (__bridge UIView*)reinterpret_cast<void*>(window->winId()) : nil;
        if (!view.window || CGRectIsEmpty(view.bounds)) {
            return make_ret(Ret::Code::UnknownError,
                            trc("cantoforge/print", "Could not open the system print dialog. You can export a PDF and print it from Files."));
        }
        // Do not compete with a native document picker or another UIKit sheet.
        if (view.window.rootViewController.presentedViewController) {
            return make_ret(Ret::Code::Cancel);
        }

        auto writer = writers()->writer("pdf");
        if (!writer) {
            return make_ret(Ret::Code::NotSupported,
                            trc("cantoforge/print", "Could not prepare the score for printing. Try exporting it as a PDF."));
        }

        io::Buffer buffer;
        QSizeF pageSize;
        {
            // Match the existing export workflow. Complete generation and
            // restoration synchronously, before showing any native UI that
            // may process events, trigger autosave or outlive this notation.
            auto painting = notation->painting();
            const auto previousView = painting->viewMode();
            DEFER { painting->setViewMode(previousView); };
            painting->setViewMode(ViewMode::PAGE);
            if (painting->pageCount() <= 0 || !buffer.open(io::IODevice::WriteOnly)) {
                return make_ret(Ret::Code::UnknownError,
                                trc("cantoforge/print", "Could not prepare the score for printing. Try exporting it as a PDF."));
            }
            pageSize = painting->pageSizeInch().toQSizeF();
            INotationWriter::Options options {
                { INotationWriter::OptionKey::UNIT_TYPE, Val(INotationWriter::UnitType::PER_PART) },
                { INotationWriter::OptionKey::TRANSPARENT_BACKGROUND, Val(false) }
            };
            const Ret result = writer->write(notation, buffer, options);
            buffer.close();
            if (!result) {
                LOGE() << "Could not render print PDF: " << result.toString();
                return make_ret(Ret::Code::UnknownError,
                                trc("cantoforge/print", "Could not prepare the score for printing. Try exporting it as a PDF."));
            }
        }

        const auto& bytes = buffer.data();
        NSData* pdf = [NSData dataWithBytes:bytes.constData() length:bytes.size()];
        if (![UIPrintInteractionController canPrintData:pdf]) {
            return make_ret(Ret::Code::UnknownError,
                            trc("cantoforge/print", "Could not prepare the score for printing. Try exporting it as a PDF."));
        }

        UIPrintInteractionController* controller = UIPrintInteractionController.sharedPrintController;
        UIPrintInfo* info = [UIPrintInfo printInfo];
        const QString title = notation->projectWorkTitleAndPartName();
        info.jobName = (title.isEmpty() ? QGuiApplication::applicationDisplayName() : title).toNSString();
        info.outputType = UIPrintInfoOutputGeneral;
        info.orientation = pageSize.width() > pageSize.height() ? UIPrintInfoOrientationLandscape : UIPrintInfoOrientationPortrait;
        controller.printInfo = info;
        controller.printingItem = pdf;
        controller.showsNumberOfCopies = YES;
        controller.showsPaperSelectionForLoadedPapers = YES;

        std::weak_ptr<PrintProvider> weakSelf = shared_from_this();
        auto finished = std::make_shared<bool>(false);
        m_isPrinting = true;
        UIPrintInteractionCompletionHandler completion = ^(UIPrintInteractionController* sender, BOOL completed, NSError* error) {
            dispatch_async(dispatch_get_main_queue(), ^{
                if (*finished) {
                    return;
                }
                *finished = true;
                // The system retains the PDF until the job completes. No file is
                // left in Documents, including when the user cancels printing.
                sender.printingItem = nil;
                sender.printInfo = nil;
                if (auto self = weakSelf.lock()) {
                    self->m_isPrinting = false;
                }
                if (error) {
                    LOGE() << "iPad print job failed: " << QString::fromNSString(error.localizedDescription);
                    QTimer::singleShot(0, qGuiApp, [weakSelf]() {
                        if (auto self = weakSelf.lock()) {
                            self->interactive()->error(trc("cantoforge/print", "Printing"),
                                trc("cantoforge/print", "Printing failed. Check the printer and connection, or export a PDF and print it from Files."),
                                { IInteractive::Button::Ok });
                        }
                    });
                } else {
                    LOGI() << (completed ? "iPad print job completed" : "iPad print job cancelled");
                }
            });
        };

        // An iPad print popover needs an anchor in the application's UIView.
        const CGRect anchor = CGRectMake(CGRectGetMidX(view.bounds), CGRectGetMinY(view.bounds) + 8, 1, 1);
        const BOOL presented = [controller presentFromRect:anchor inView:view animated:YES completionHandler:completion];
        if (!presented && !*finished) {
            *finished = true;
            m_isPrinting = false;
            controller.printingItem = nil;
            controller.printInfo = nil;
            return make_ret(Ret::Code::UnknownError,
                            trc("cantoforge/print", "Could not open the system print dialog. You can export a PDF and print it from Files."));
        }
        return make_ok();
    }
}
}
