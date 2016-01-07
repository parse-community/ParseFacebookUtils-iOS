/**
 * Copyright (c) 2015-present, Parse, LLC.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import "PFReceptionist.h"

/*!
 Allows a factory block to be run on some other thread.
 */
@interface PFThreadFactoryBlockRunner : NSObject

@property (nonatomic, strong) id result;

@end

@implementation PFThreadFactoryBlockRunner

- (void)invokeFactory:(id (^)())factory {
    self.result = factory();
}

@end

@implementation PFReceptionist {
    id _target;
    NSThread *_affinitizedThread;
}

- (instancetype)initWithTarget:(id)target thread:(NSThread *)thread {
    if (!target) {
        return nil;
    }

    _target = target;
    _affinitizedThread = thread;

    return self;
}

- (instancetype)initWithFactory:(id (^)())factory thread:(NSThread *)thread {
    // If you pass a stack block into performSelector:... it will copy it and leak.
    // If you copy the block to the heap here, it will autorelease.
    // So adding this random copy actually removes a memory leak.
    factory = [factory copy];

    _affinitizedThread = thread;
    PFThreadFactoryBlockRunner *runner = [[PFThreadFactoryBlockRunner alloc] init];
    [runner performSelector:@selector(invokeFactory:)
                   onThread:_affinitizedThread
                 withObject:factory
              waitUntilDone:YES];
    _target = runner.result;
    if (!_target) {
        return nil;
    }
    return self;
}

- (id)rawReceiver {
    return _target;
}

- (void)forwardInvocation:(NSInvocation *)invocation {
    [invocation performSelector:@selector(invokeWithTarget:)
                       onThread:_affinitizedThread
                     withObject:_target
                  waitUntilDone:YES];
}

- (NSMethodSignature *)methodSignatureForSelector:(SEL)sel {
    return [_target methodSignatureForSelector:sel];
}

@end
