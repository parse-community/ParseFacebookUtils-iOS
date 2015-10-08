/**
 * Copyright (c) 2015-present, Parse, LLC.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import "PFFacebookPrivateUtilities.h"

#import <Bolts/BFExecutor.h>

@implementation PFFacebookPrivateUtilities

+ (void)safePerformSelector:(SEL)selector
                   onTarget:(id)target
                 withObject:(id)object
                     object:(id)anotherObject {
    if (target == nil || selector == nil || ![target respondsToSelector:selector]) {
        return;
    }

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
    [target performSelector:selector withObject:object withObject:anotherObject];
#pragma clang diagnostic pop
}

@end

@implementation BFTask (ParseFacebookUtils)

- (id)pffb_waitForResult:(NSError **)error {
    [self waitUntilFinished];

    if (self.cancelled) {
        return nil;
    } else if (self.exception) {
        @throw self.exception;
    }
    if (self.error && error) {
        *error = self.error;
    }
    return self.result;
}

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

@implementation NSDateFormatter (ParseFacebookUtils)

+ (instancetype)pffb_preciseDateFormatter {
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    formatter.locale = [NSLocale localeWithLocaleIdentifier:@"en_US_POSIX"];
    formatter.timeZone = [NSTimeZone timeZoneForSecondsFromGMT:0];
    formatter.dateFormat = @"yyyy-MM-dd'T'HH:mm:ss.SSS'Z'";
    return formatter;
}

@end
