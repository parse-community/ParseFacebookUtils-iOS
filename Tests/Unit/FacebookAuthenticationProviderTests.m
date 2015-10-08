/**
 * Copyright (c) 2015-present, Parse, LLC.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import <FacebookSDK/FBRequest.h>
#import <FacebookSDK/FBSession.h>
#import <OCMock/OCMock.h>

#import <Bolts/BFTask.h>

#import "PFFacebookAuthenticationProvider_Private.h"
#import "PFFacebookTestCase.h"
#import "PFFacebookTokenCachingStrategy.h"

@interface FBSession ()

/*!
 Internal only method on FBSession that clears the thread affinity information.
 We need this to be able to use FBSession from multiple threads.
 */
- (void)clearAffinitizedThread;


@end

@interface FacebookAuthenticationProviderTests : PFFacebookTestCase

@end

@implementation FacebookAuthenticationProviderTests

///--------------------------------------
#pragma mark - Helpers
///--------------------------------------

- (id)mockedSessionProvider {
    return PFStrictProtocolMock(@protocol(PFFacebookSessionProvider));
}

///--------------------------------------
#pragma mark - Tests
///--------------------------------------

- (void)testProperties {
    PFFacebookAuthenticationProvider *provider = [[PFFacebookAuthenticationProvider alloc] init];
    provider.appId = @"appId";
    provider.permissions = @[ @1, @2 ];
    provider.urlSchemeSuffix = @"suffix";
    provider.audience = FBSessionDefaultAudienceEveryone;
    provider.loginBehavior = FBSessionLoginBehaviorForcingSafari;

    XCTAssertEqualObjects(provider.appId, @"appId");
    XCTAssertEqualObjects(provider.permissions, (@[ @1, @2 ]));
    XCTAssertEqualObjects(provider.urlSchemeSuffix, @"suffix");
    XCTAssertEqual(provider.audience, FBSessionDefaultAudienceEveryone);
    XCTAssertEqual(provider.loginBehavior, FBSessionLoginBehaviorForcingSafari);
}

- (void)testAuthType {
    XCTAssertEqualObjects(PFFacebookUserAuthenticationType, @"facebook");
}

- (void)testAuthData {
    PFFacebookAuthenticationProvider *provider = [[PFFacebookAuthenticationProvider alloc] init];

    XCTAssertEqualObjects([provider authDataWithFacebookId:@"fbId"
                                               accessToken:@"token"
                                                expiration:[NSDate dateWithTimeIntervalSince1970:1337]], (@{
                                                    @"id": @"fbId",
                                                    @"access_token": @"token",
                                                    @"expiration_date": @"1970-01-01T00:22:17.000Z"
                                                }));
}

- (void)testAuthenticateSuccess {
    NSDictionary *expectedAuthData = @{
        @"id": @"fbId",
        @"access_token": @"token",
        @"expiration_date":  @"1970-01-01T00:22:17.000Z"
    };

    PFFacebookAuthenticationProvider *provider = [[PFFacebookAuthenticationProvider alloc] init];

    id mockedSession = PFStrictClassMock([FBSession class]);
    id mockedTokenData = PFStrictClassMock([FBAccessTokenData class]);
    id mockedRequest = PFStrictClassMock([FBRequest class]);
    id mockedSessionProvider = [self mockedSessionProvider];

    OCMStub([mockedSession valueForKey:@"self"]).andReturnWeak(mockedSession);
    OCMStub([[mockedSession ignoringNonObjectArgs] openWithBehavior:0
                                                  completionHandler:OCMOCK_ANY]).andDo(^(NSInvocation *invocation) {
        __unsafe_unretained FBSession *theSession = nil;
        __unsafe_unretained FBSessionStateHandler handler = nil;

        [invocation getArgument:&theSession atIndex:0];
        [invocation getArgument:&handler atIndex:3];

        [provider.tokenCache setAccessToken:@"token"];
        [provider.tokenCache setExpirationDate:[NSDate dateWithTimeIntervalSince1970:1337]];

        handler(theSession, FBSessionStateOpen, nil);
    });

    OCMStub([mockedSession isOpen]).andReturn(YES);
    OCMStub([mockedSession appID]).andReturn(@"appId");
    OCMStub([mockedSession accessTokenData]).andReturn(mockedTokenData);
    OCMStub([mockedSession close]);

    OCMStub([mockedTokenData accessToken]).andReturn(@"token");
    OCMStub([mockedTokenData loginType]).andReturn(FBSessionLoginTypeFacebookApplication);
    OCMStub([mockedTokenData userID]).andReturn(@"fbId");

    OCMStub(ClassMethod([mockedRequest requestWithGraphPath:@"me"
                                                 parameters:@{ @"fields": @"id" }
                                                 HTTPMethod:@"GET"])).andReturnWeak(mockedRequest);

    OCMStub([mockedRequest setSession:mockedSession]);
    OCMStub([mockedRequest startWithCompletionHandler:OCMOCK_ANY]).andDo(^(NSInvocation *invocation) {
        __unsafe_unretained FBRequestHandler handler = nil;
        [invocation getArgument:&handler atIndex:2];

        handler(nil, @{ @"id": @"fbId" }, nil);
    });

    OCMStub([mockedSessionProvider sessionWithAppID:@"appId"
                                        permissions:@[ @"permission" ]
                                    urlSchemeSuffix:nil
                                 tokenCacheStrategy:OCMOCK_ANY]).andReturn(mockedSession);

    provider.sessionProvider = mockedSessionProvider;
    provider.appId = @"appId";
    provider.permissions = @[ @"permission" ];

    XCTestExpectation *expectation = [self currentSelectorTestExpectation];
    [[provider authenticateAsync] continueWithBlock:^id(BFTask *task) {
        XCTAssertEqualObjects(task.result, expectedAuthData);
        [expectation fulfill];
        return nil;
    }];

    [self waitForTestExpectations];
}

- (void)testAuthenticateIncompleteCachedSession {
    NSDictionary *expectedAuthData = @{
                                       @"id": @"fbId",
                                       @"access_token": @"token",
                                       @"expiration_date":  @"1970-01-01T00:22:17.000Z"
                                       };

    PFFacebookAuthenticationProvider *provider = [[PFFacebookAuthenticationProvider alloc] init];

    id mockedSession = PFStrictClassMock([FBSession class]);
    id mockedTokenData = PFStrictClassMock([FBAccessTokenData class]);
    id mockedRequest = PFStrictClassMock([FBRequest class]);
    id mockedSessionProvider = [self mockedSessionProvider];

    OCMStub([mockedSession valueForKey:@"self"]).andReturnWeak(mockedSession);
    OCMStub([[mockedSession ignoringNonObjectArgs] openWithBehavior:0
                                                  completionHandler:OCMOCK_ANY]).andDo(^(NSInvocation *invocation) {
        __unsafe_unretained FBSession *theSession = nil;
        __unsafe_unretained FBSessionStateHandler handler = nil;

        [invocation getArgument:&theSession atIndex:0];
        [invocation getArgument:&handler atIndex:3];

        [provider.tokenCache setAccessToken:@"token"];
        [provider.tokenCache setExpirationDate:[NSDate dateWithTimeIntervalSince1970:1337]];

        handler(theSession, FBSessionStateOpen, nil);
    });

    OCMStub([mockedSession isOpen]).andReturn(YES);
    OCMStub([mockedSession appID]).andReturn(@"appId");
    OCMStub([mockedSession accessTokenData]).andReturn(mockedTokenData);
    OCMStub([mockedSession close]);

    OCMStub([mockedTokenData accessToken]).andReturn(@"token");
    OCMStub([mockedTokenData loginType]).andReturn(FBSessionLoginTypeFacebookApplication);
    OCMStub([mockedTokenData userID]).andReturn(nil);

    OCMStub(ClassMethod([mockedRequest requestWithGraphPath:@"me"
                                                 parameters:@{ @"fields": @"id" }
                                                 HTTPMethod:@"GET"])).andReturnWeak(mockedRequest);

    OCMStub([mockedRequest setSession:mockedSession]);
    OCMStub([mockedRequest startWithCompletionHandler:OCMOCK_ANY]).andDo(^(NSInvocation *invocation) {
        __unsafe_unretained FBRequestHandler handler = nil;
        [invocation getArgument:&handler atIndex:2];

        handler(nil, @{ @"id": @"fbId" }, nil);
    });

    OCMStub([mockedSessionProvider sessionWithAppID:@"appId"
                                        permissions:@[ @"permission" ]
                                    urlSchemeSuffix:nil
                                 tokenCacheStrategy:OCMOCK_ANY]).andReturn(mockedSession);

    OCMStub([mockedSessionProvider sessionWithAppID:@"appId"
                                        permissions:nil
                                    urlSchemeSuffix:nil
                                 tokenCacheStrategy:OCMOCK_ANY]).andReturn(mockedSession);

    OCMStub([mockedSession clearAffinitizedThread]);

    provider.sessionProvider = mockedSessionProvider;
    provider.appId = @"appId";
    provider.permissions = @[ @"permission" ];

    XCTestExpectation *expectation = [self currentSelectorTestExpectation];
    [[provider authenticateAsync] continueWithBlock:^id(BFTask *task) {
        XCTAssertEqualObjects(task.result, expectedAuthData);
        [expectation fulfill];
        return nil;
    }];

    [self waitForTestExpectations];
}

- (void)testTokenExtension {
    NSDictionary *expectedAuthData = @{
                                       @"id": @"fbId",
                                       @"access_token": @"token",
                                       @"expiration_date":  @"1970-01-01T00:22:17.000Z"
                                       };

    PFFacebookAuthenticationProvider *provider = [[PFFacebookAuthenticationProvider alloc] init];

    id mockedSession = PFStrictClassMock([FBSession class]);
    id mockedTokenData = PFStrictClassMock([FBAccessTokenData class]);
    id mockedRequest = PFStrictClassMock([FBRequest class]);
    id mockedSessionProvider = [self mockedSessionProvider];

    OCMStub([mockedSession valueForKey:@"self"]).andReturnWeak(mockedSession);
    OCMStub([[mockedSession ignoringNonObjectArgs] openWithBehavior:0
                                                  completionHandler:OCMOCK_ANY]).andDo(^(NSInvocation *invocation) {
        __unsafe_unretained FBSession *theSession = nil;
        __unsafe_unretained FBSessionStateHandler handler = nil;

        [invocation getArgument:&theSession atIndex:0];
        [invocation getArgument:&handler atIndex:3];

        [provider.tokenCache setAccessToken:@"token"];
        [provider.tokenCache setExpirationDate:[NSDate dateWithTimeIntervalSince1970:1337]];

        handler(theSession, FBSessionStateOpen, nil);
        handler(theSession, FBSessionStateOpenTokenExtended, nil);
    });

    OCMStub([mockedSession isOpen]).andReturn(YES);
    OCMStub([mockedSession appID]).andReturn(@"appId");
    OCMStub([mockedSession accessTokenData]).andReturn(mockedTokenData);
    OCMStub([mockedSession close]);

    OCMStub([mockedTokenData accessToken]).andReturn(@"token");
    OCMStub([mockedTokenData loginType]).andReturn(FBSessionLoginTypeFacebookApplication);
    OCMStub([mockedTokenData userID]).andReturn(@"fbId");

    OCMStub(ClassMethod([mockedRequest requestWithGraphPath:@"me"
                                                 parameters:@{ @"fields": @"id" }
                                                 HTTPMethod:@"GET"])).andReturnWeak(mockedRequest);

    OCMStub([mockedRequest setSession:mockedSession]);
    OCMStub([mockedRequest startWithCompletionHandler:OCMOCK_ANY]).andDo(^(NSInvocation *invocation) {
        __unsafe_unretained FBRequestHandler handler = nil;
        [invocation getArgument:&handler atIndex:2];

        handler(nil, @{ @"id": @"fbId" }, nil);
    });

    OCMStub([mockedSessionProvider sessionWithAppID:@"appId"
                                        permissions:@[ @"permission" ]
                                    urlSchemeSuffix:nil
                                 tokenCacheStrategy:OCMOCK_ANY]).andReturn(mockedSession);

    provider.sessionProvider = mockedSessionProvider;
    provider.appId = @"appId";
    provider.permissions = @[ @"permission" ];

    XCTestExpectation *expectation = [self currentSelectorTestExpectation];
    provider.tokenExtensionCallback = ^(NSDictionary *authData) {
        XCTAssertEqualObjects(expectedAuthData, authData);
        [expectation fulfill];
    };
    [[provider authenticateAsync] continueWithBlock:^id(BFTask *task) {
        XCTAssertEqualObjects(task.result, expectedAuthData);
        return nil;
    }];

    [self waitForTestExpectations];
}

- (void)testReauthorize {
    NSDictionary *expectedAuthData = @{
                                       @"id": @"fbId",
                                       @"access_token": @"token",
                                       @"expiration_date":  @"1970-01-01T00:22:17.000Z"
                                       };

    PFFacebookAuthenticationProvider *provider = [[PFFacebookAuthenticationProvider alloc] init];

    id mockedSession = PFStrictClassMock([FBSession class]);
    id mockedSessionProvider = [self mockedSessionProvider];

    OCMStub([mockedSession valueForKey:@"self"]).andReturnWeak(mockedSession);
    OCMStub([[mockedSession ignoringNonObjectArgs] requestNewPublishPermissions:OCMOCK_ANY
                                                                defaultAudience:0
                                                              completionHandler:OCMOCK_ANY]).andDo(^(NSInvocation *invocation) {
        __unsafe_unretained FBSession *theSession = nil;
        __unsafe_unretained FBSessionRequestPermissionResultHandler handler = nil;

        [invocation getArgument:&theSession atIndex:0];
        [invocation getArgument:&handler atIndex:4];

        [provider.tokenCache setAccessToken:@"token"];
        [provider.tokenCache setExpirationDate:[NSDate dateWithTimeIntervalSince1970:1337]];

        handler(theSession, nil);
    });

    OCMStub([mockedSession isOpen]).andReturn(YES);
    OCMStub([mockedSession appID]).andReturn(@"appId");
    OCMStub([mockedSession close]);

    OCMStub([mockedSessionProvider sessionWithAppID:@"appId"
                                        permissions:@[ @"permission" ]
                                    urlSchemeSuffix:nil
                                 tokenCacheStrategy:OCMOCK_ANY]).andReturn(mockedSession);

    provider.sessionProvider = mockedSessionProvider;
    provider.appId = @"appId";
    provider.permissions = @[ @"permission" ];
    [provider initializeSession];

    provider.tokenCache.facebookId = @"fbId";
    provider.tokenCache.accessToken = @"token";
    provider.tokenCache.expirationDate = [NSDate dateWithTimeIntervalSince1970:1337];

    XCTestExpectation *expectation = [self currentSelectorTestExpectation];
    [[provider reauthorizeInBackground] continueWithBlock:^id(BFTask *task) {
        XCTAssertEqualObjects(task.result, expectedAuthData);
        [expectation fulfill];
        return nil;
    }];

    [self waitForTestExpectations];
}

- (void)testInitialize {
    PFFacebookAuthenticationProvider *provider = [[PFFacebookAuthenticationProvider alloc] init];
    provider.appId = @"appId";
    provider.permissions = @[ @"permission" ];
    provider.urlSchemeSuffix = @"suffix";

    [provider initializeSession];

    XCTAssertEqualObjects(FBSession.activeSession.appID, @"appId");
    XCTAssertEqualObjects(FBSession.activeSession.permissions, @[ @"permission" ]);
    XCTAssertEqualObjects(FBSession.activeSession.urlSchemeSuffix, @"suffix");
}

@end
