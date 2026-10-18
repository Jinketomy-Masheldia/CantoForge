/* SPDX-License-Identifier: GPL-3.0-only */
#include "iosdocumentimport.h"
#import <Foundation/Foundation.h>
#include <QStandardPaths>
#include "project/projecterrors.h"

static NSString* importDirectoryName(NSURL* source)
{
    NSMutableCharacterSet* invalid = [NSCharacterSet.controlCharacterSet mutableCopy];
    [invalid addCharactersInString:@"/\\:"];
    NSString* name = [[[source.lastPathComponent stringByDeletingPathExtension]
        componentsSeparatedByCharactersInSet:invalid] componentsJoinedByString:@"_"];
    NSMutableCharacterSet* edges = [NSCharacterSet.whitespaceAndNewlineCharacterSet mutableCopy];
    [edges addCharactersInString:@"."];
    name = [name stringByTrimmingCharactersInSet:edges];

    // Leave room for collision suffixes without splitting Unicode characters.
    NSUInteger end = 0;
    while (end < name.length) {
        const NSRange character = [name rangeOfComposedCharacterSequenceAtIndex:end];
        const NSUInteger next = NSMaxRange(character);
        if ([[name substringToIndex:next] lengthOfBytesUsingEncoding:NSUTF8StringEncoding] > 200) {
            break;
        }
        end = next;
    }
    name = [name substringToIndex:end];
    return name.length ? name : @"Untitled";
}

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
        NSURL* imports = [NSURL fileURLWithPath:[documents stringByAppendingPathComponent:@"Imported Scores"] isDirectory:YES];
        NSURL* directory = nil;
        NSFileManager* manager = [NSFileManager defaultManager];
        NSError* error = nil;
        __block NSError* copyError = nil;
        BOOL created = NO;
        if ([manager createDirectoryAtURL:imports withIntermediateDirectories:YES attributes:nil error:&error]) {
            NSString* name = importDirectoryName(source);
            for (NSUInteger number = 1; ; ++number) {
                NSString* candidate = number == 1 ? name : [NSString stringWithFormat:@"%@ (%lu)", name, (unsigned long)number];
                directory = [imports URLByAppendingPathComponent:candidate isDirectory:YES];
                error = nil;
                // Reserve a fresh directory; never reuse or overwrite an existing import.
                created = [manager createDirectoryAtURL:directory withIntermediateDirectories:NO attributes:nil error:&error];
                if (created || ![error.domain isEqualToString:NSCocoaErrorDomain] || error.code != NSFileWriteFileExistsError) {
                    break;
                }
            }
        }
        NSURL* destination = [directory URLByAppendingPathComponent:source.lastPathComponent];
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
            if (created) {
                [manager removeItemAtURL:directory error:nil];
            }
            return make_ret(Err::FileOpenError, failure ? failure.localizedDescription.UTF8String : "Could not import document");
        }
        return muse::RetVal<muse::io::path_t>::make_ok(muse::io::path_t(destination.path.UTF8String));
    }
}
