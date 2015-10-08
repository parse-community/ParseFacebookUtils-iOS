/**
 * Copyright (c) 2015-present, Parse, LLC.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import "PFFacebookPrivateUtilities.h"

#import <Parse/PFConstants.h>

@implementation PFFacebookPrivateUtilities

+ (UIViewController *)applicationTopViewController {
    UIViewController *viewController = [UIApplication sharedApplication].keyWindow.rootViewController;
    while (viewController.presentedViewController) {
        viewController = viewController.presentedViewController;
    }
    return viewController;
}

@end

@implementation BFTask (ParseFacebookUtils)

- (instancetype)pffb_continueWithMainThreadUserBlock:(PFUserResultBlock)block {
    return [self pffb_continueWithMainThreadBlock:^id(BFTask *task) {
        if (block) {
            block(task.result, task.error);
        }
        return nil;
    }];
}

- (instancetype)pffb_continueWithMainThreadBooleanBlock:(PFBooleanResultBlock)block {
    return [self pffb_continueWithMainThreadBlock:^id(BFTask *task) {
        if (block) {
            block([task.result boolValue], task.error);
        }
        return nil;
    }];
}

- (instancetype)pffb_continueWithMainThreadBlock:(BFContinuationBlock)block {
    return [self continueWithExecutor:[BFExecutor mainThreadExecutor] withBlock:block];
}

@end

@implementation NSError (ParseFacebookUtils)

+ (instancetype)pffb_invalidFacebookSessionError {
    return [NSError errorWithDomain:PFParseErrorDomain
                               code:kPFErrorFacebookInvalidSession
                           userInfo:@{ NSLocalizedDescriptionKey : @"Supplied access token is missing required data." }];
}

@end

@implementation NSDateFormatter (ParseFacebookUtils)

+ (instancetype)pffb_preciseDateFormatter {
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    formatter.locale = [NSLocale localeWithLocaleIdentifier:@"en_US_POSIX"];
    formatter.timeZone = [NSTimeZone timeZoneForSecondsFromGMT:0];
    formatter.dateFormat = @"yyyy-MM-dd'T'HH:mm:ss.SSS'Z'";
    return formatter;
}

@end
