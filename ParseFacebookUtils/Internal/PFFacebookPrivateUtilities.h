/**
 * Copyright (c) 2015-present, Parse, LLC.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

#import <Bolts/BFExecutor.h>
#import <Bolts/BFTask.h>

#import <Parse/PFConstants.h>

@interface PFFacebookPrivateUtilities : NSObject

+ (UIViewController *)applicationTopViewController;

@end

@interface BFTask (ParseFacebookUtils)

- (instancetype)pffb_continueWithMainThreadUserBlock:(PFUserResultBlock)block;
- (instancetype)pffb_continueWithMainThreadBooleanBlock:(PFBooleanResultBlock)block;
- (instancetype)pffb_continueWithMainThreadBlock:(BFContinuationBlock)block;

@end

@interface NSError (ParseFacebookUtils)

+ (instancetype)pffb_invalidFacebookSessionError;

@end

@interface NSDateFormatter (ParseFacebookUtils)

+ (instancetype)pffb_preciseDateFormatter;

@end
