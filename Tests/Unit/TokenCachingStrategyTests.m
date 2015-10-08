/**
 * Copyright (c) 2015-present, Parse, LLC.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

@import XCTest;

#import "PFFacebookTokenCachingStrategy.h"

@interface TokenCachingStrategyTests : XCTestCase

@end

@implementation TokenCachingStrategyTests

- (void)testProperties {
    NSDate *expectedDate = [NSDate dateWithTimeIntervalSince1970:1337];
    PFFacebookTokenCachingStrategy *strategy = [[PFFacebookTokenCachingStrategy alloc] init];
    strategy.accessToken = @"token";
    strategy.facebookId = @"fbid";
    strategy.expirationDate = expectedDate;

    XCTAssertEqualObjects(strategy.accessToken, @"token");
    XCTAssertEqualObjects(strategy.facebookId, @"fbid");
    XCTAssertEqualObjects(strategy.expirationDate, expectedDate);

    XCTAssertEqualObjects([strategy fetchTokenInformation][FBTokenInformationTokenKey], @"token");
    XCTAssertEqualObjects([strategy fetchTokenInformation][FBTokenInformationUserFBIDKey], @"fbid");
    XCTAssertEqualObjects([strategy fetchTokenInformation][FBTokenInformationExpirationDateKey], expectedDate);
}

- (void)testSimpleCaching {
    PFFacebookTokenCachingStrategy *strategy = [[PFFacebookTokenCachingStrategy alloc] init];
    NSDictionary *tokenInfo = @{ @"custom1": @"value1", FBTokenInformationTokenKey: @"token" };

    [strategy cacheTokenInformation:tokenInfo];
    XCTAssertEqualObjects(tokenInfo, [strategy fetchTokenInformation]);
    XCTAssertEqualObjects(@"token", strategy.accessToken);
}

- (void)testFutureCaching {
    PFFacebookTokenCachingStrategy *strategy = [[PFFacebookTokenCachingStrategy alloc] init];
    NSDictionary *tokenInfo = @{
        FBTokenInformationTokenKey: @"token",
        FBTokenInformationExpirationDateKey: [NSDate distantFuture]
    };

    [strategy cacheTokenInformation:tokenInfo];
    XCTAssertEqualObjects(strategy.accessToken, @"token");

    NSDate *actual = [strategy fetchTokenInformation][FBTokenInformationExpirationDateKey];

    // Give an epsilon of 10 seconds, in case this test some how ends up running super slow.
    NSTimeInterval twoYears = 63072000;
    XCTAssertLessThan(fabs([actual timeIntervalSinceNow] - twoYears), 10);
}

- (void)testClear {
    PFFacebookTokenCachingStrategy *strategy = [[PFFacebookTokenCachingStrategy alloc] init];
    strategy.accessToken = @"token";
    [strategy clearToken];

    XCTAssertNil(strategy.accessToken);
    XCTAssertNil([strategy fetchTokenInformation]);

    NSDate *date = [NSDate dateWithTimeIntervalSince1970:1337];
    strategy.accessToken = @"token";
    strategy.expirationDate = date;
    strategy.facebookId = @"fbId";

    XCTAssertNotNil([strategy fetchTokenInformation]);

    strategy.accessToken = nil;
    XCTAssertNil(strategy.accessToken);
    XCTAssertNotNil([strategy fetchTokenInformation]);
    XCTAssertNil([strategy fetchTokenInformation][FBTokenInformationTokenKey]);

    strategy.expirationDate = nil;

    XCTAssertNil(strategy.expirationDate);
    XCTAssertNotNil([strategy fetchTokenInformation]);
    XCTAssertNil([strategy fetchTokenInformation][FBTokenInformationExpirationDateKey]);

    strategy.facebookId = nil;

    XCTAssertNil(strategy.facebookId);
    XCTAssertNotNil([strategy fetchTokenInformation]);
    XCTAssertNil([strategy fetchTokenInformation][FBTokenInformationUserFBIDKey]);
}

@end
