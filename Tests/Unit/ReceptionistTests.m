/**
 * Copyright (c) 2015-present, Parse, LLC.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import <OCMock/OCMock.h>

#import "PFFacebookTestCase.h"
#import "PFReceptionist.h"

@interface TestObject : NSObject

- (void)someMethod;
- (void)someMethodWithArg:(id)argument;
- (id)someMethodReturningValue;

@end

@implementation TestObject

- (void)someMethod {
}

- (void)someMethodWithArg:(id)argument {
}

- (id)someMethodReturningValue {
    return nil;
}

@end

@interface ReceptionistTests : PFFacebookTestCase

@end

@implementation ReceptionistTests

- (void)testConstructors {
    NSObject *theObject = [NSObject new];
    PFReceptionist *receptionist = [[PFReceptionist alloc] initWithFactory:^NSObject *{
        return theObject;
    } thread:[NSThread currentThread]];
    XCTAssertNotNil(receptionist);
    XCTAssertEqualObjects([(id)receptionist valueForKey:@"self"], theObject);

    receptionist = [[PFReceptionist alloc] initWithTarget:theObject thread:[NSThread currentThread]];
    XCTAssertEqualObjects([(id)receptionist valueForKey:@"self"], theObject);

    XCTAssertNil([[PFReceptionist alloc] initWithTarget:nil thread:nil]);
    XCTAssertNil([[PFReceptionist alloc] initWithFactory:^NSObject *{
        return nil;
    } thread:[NSThread currentThread]]);
}

- (void)testForwardFromTargetThread {
    id mockTarget = PFStrictClassMock([TestObject class]);
    TestObject *receptionist = (TestObject *) [[PFReceptionist alloc] initWithTarget:mockTarget
                                                                              thread:[NSThread currentThread]];

    OCMExpect([mockTarget someMethod]);
    OCMExpect([mockTarget someMethodWithArg:@"foo"]);
    OCMExpect([mockTarget someMethodReturningValue]).andReturn(@"foo");

    [receptionist someMethod];
    [receptionist someMethodWithArg:@"foo"];

    XCTAssertEqualObjects([receptionist someMethodReturningValue], @"foo");

    OCMVerifyAll(mockTarget);
}

- (void)testForwardFromDifferentThread {
    // Spawn a background thread which just runs a run-loop.
    __block NSThread *backgroundThread = nil;
    XCTestExpectation *expectation = [self currentSelectorTestExpectation];
    [NSThread detachNewThreadSelector:@selector(invoke) toTarget:[^{
        backgroundThread = [NSThread currentThread];
        [expectation performSelector:@selector(fulfill) withObject:0 afterDelay:0];
        while (![backgroundThread isCancelled]) {
            [[NSRunLoop currentRunLoop] runUntilDate:[NSDate distantFuture]];
        }
    } copy] withObject:nil];
    [self waitForTestExpectations];

    id mockTarget = PFStrictClassMock([TestObject class]);
    TestObject *receptionist = (TestObject *) [[PFReceptionist alloc] initWithFactory:^NSObject *{
        XCTAssertEqualObjects([NSThread currentThread], backgroundThread);
        return mockTarget;
    } thread:backgroundThread];

    OCMExpect([mockTarget someMethod]).andDo(^(NSInvocation *invocation) {
        XCTAssertEqualObjects([NSThread currentThread], backgroundThread);
    });

    OCMExpect([mockTarget someMethodWithArg:@"foo"]).andDo(^(NSInvocation *invocation) {
        XCTAssertEqualObjects([NSThread currentThread], backgroundThread);
    });

    OCMExpect([mockTarget someMethodReturningValue]).andDo(^(NSInvocation *invocation) {
        XCTAssertEqualObjects([NSThread currentThread], backgroundThread);
    }).andReturn(@"foo");

    [receptionist someMethod];
    [receptionist someMethodWithArg:@"foo"];

    XCTAssertEqualObjects([receptionist someMethodReturningValue], @"foo");

    OCMVerifyAll(mockTarget);
    [backgroundThread cancel];
}

@end
