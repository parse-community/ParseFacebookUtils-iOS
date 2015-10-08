/**
 * Copyright (c) 2015-present, Parse, LLC.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import <Foundation/Foundation.h>

/*!
 Provides a proxy that will make all calls synchronously on the affinitized thread.
 */
@interface PFReceptionist : NSProxy

@property (nonatomic, strong, readonly) id rawReceiver;

- (instancetype)initWithTarget:(id)target thread:(NSThread *)thread;
- (instancetype)initWithFactory:(id (^)())factory thread:(NSThread *)thread;

@end
