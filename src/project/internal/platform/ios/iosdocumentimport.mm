/* SPDX-License-Identifier: GPL-3.0-only */
#include "iosdocumentimport.h"
#import <Foundation/Foundation.h>
#include <QStandardPaths>
#include "project/projecterrors.h"

muse::RetVal<muse::io::path_t> mu::project::importIosDocument(const muse::io::path_t& path)
{
    @autoreleasepool {
        NSString* sourcePath = [NSString stringWithUTF8String:path.toStdString().c_str()];
        NSString* canonical = [sourcePath stringByResolvingSymlinksInPath];
        NSString* home = [[NSHomeDirectory() stringByResolvingSymlinksInPath] stringByAppendingString:@"/"];
        if ([canonical hasPrefix:home]) {
            return muse::RetVal<muse::io::path_t>::make_ok(path);
        }

        NSURL* source = [NSURL fileURLWithPath:sourcePath];
        const BOOL scoped = [source startAccessingSecurityScopedResource];
        NSString* documents = [NSString stringWithUTF8String:
            QStandardPaths::writableLocation(QStandardPaths::DocumentsLocation).toUtf8().constData()];
        NSURL* directory = [NSURL fileURLWithPath:[[documents stringByAppendingPathComponent:@"Imported Scores"]
            stringByAppendingPathComponent:NSUUID.UUID.UUIDString] isDirectory:YES];
        NSURL* destination = [directory URLByAppendingPathComponent:source.lastPathComponent];
        NSFileManager* manager = [NSFileManager defaultManager];
        NSError* error = nil;
        __block NSError* copyError = nil;
        BOOL created = [manager createDirectoryAtURL:directory withIntermediateDirectories:YES attributes:nil error:&error];
        if (created) {
            NSFileCoordinator* coordinator = [[NSFileCoordinator alloc] initWithFilePresenter:nil];
            [coordinator coordinateReadingItemAtURL:source options:0 error:&error byAccessor:^(NSURL* readable) {
                [manager copyItemAtURL:readable toURL:destination error:&copyError];
            }];
        }
        if (scoped) {
            [source stopAccessingSecurityScopedResource];
        }
        NSError* failure = error ?: copyError;
        if (!created || failure || ![manager fileExistsAtPath:destination.path]) {
            [manager removeItemAtURL:directory error:nil];
            return make_ret(Err::FileOpenError, failure ? failure.localizedDescription.UTF8String : "Could not import document");
        }
        return muse::RetVal<muse::io::path_t>::make_ok(muse::io::path_t(destination.path.UTF8String));
    }
}
