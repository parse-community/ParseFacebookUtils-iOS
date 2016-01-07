/**
 * Copyright (c) 2015-present, Parse, LLC.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import "PFFacebookAuthenticationProvider_Private.h"

#import <FacebookSDK/FBAppCall.h>
#import <FacebookSDK/FBRequest.h>
#import <FacebookSDK/FBSession.h>

#import <Bolts/BFTask.h>
#import <Bolts/BFTaskCompletionSource.h>

#import <libkern/OSAtomic.h>

#import "PFFacebookPrivateUtilities.h"
#import "PFReceptionist.h"

NSString *const PFFacebookUserAuthenticationType = @"facebook";

@interface PFFacebookAuthenticationProvider () <PFFacebookSessionProvider>

@property (nonatomic, strong) FBSession *session;

@property (atomic, assign) int32_t currentOperationId;
@property (nonatomic, assign) BOOL useCustomLoginBehavior;

@end

@interface FBSession ()

/*!
 Internal only method on FBSession that clears the thread affinity information.
 We need this to be able to use FBSession from multiple threads.
 */
- (void)clearAffinitizedThread;


@end

@implementation PFFacebookAuthenticationProvider

///--------------------------------------
#pragma mark - Init
///--------------------------------------

- (instancetype)init {
    self = [super init];
    if (!self) return nil;

    self.sessionProvider = self;
    self.tokenCache = [[PFFacebookTokenCachingStrategy alloc] init];

    return self;
}

- (FBSession *)_rawSession {
    return [(PFReceptionist *)self.session rawReceiver];
}

+ (NSString *)authType {
    return @"facebook";
}

- (NSDictionary *)authDataWithFacebookId:(NSString *)facebookIdString
                             accessToken:(NSString *)accessToken
                              expiration:(NSDate *)expiration {
    return @{
             @"id" : facebookIdString,
             @"access_token" : accessToken,
             @"expiration_date" : [[NSDateFormatter pffb_preciseDateFormatter] stringFromDate:expiration]
             };
}

- (BOOL)containsPublishPermission {
    for (NSString *permission in _permissions) {
        NSRange publishRange = [permission rangeOfString:@"publish"];
        if (publishRange.location != NSNotFound) {
            return YES;
        }
    }
    return NO;
}

- (BFTask *)authenticateAsync {
    BFTaskCompletionSource *source = [BFTaskCompletionSource taskCompletionSource];

    // Hold onto the tokenCache and associate it with this callback.
    PFFacebookTokenCachingStrategy *scopedCache = self.tokenCache;

    int32_t scopedOperationId = OSAtomicIncrement32(&_currentOperationId);
    __block BOOL called = NO;
    id sessionProxy = [[PFReceptionist alloc] initWithFactory:^id{
        return [self.sessionProvider sessionWithAppID:self.appId
                                          permissions:self.permissions
                                      urlSchemeSuffix:self.urlSchemeSuffix
                                   tokenCacheStrategy:scopedCache];
    } thread:[NSThread mainThread]];

    self.session = sessionProxy;

    FBSessionLoginBehavior behavior = 0;
    if (self.useCustomLoginBehavior) {
        behavior = self.loginBehavior;
    } else {
        behavior = FBSessionLoginBehaviorUseSystemAccountIfPresent;
        if ([self containsPublishPermission]) {
            behavior = FBSessionLoginBehaviorWithFallbackToWebView;
        }
    }
    [self.session openWithBehavior:behavior
                fromViewController:nil
                 completionHandler:^(FBSession *callingSession, FBSessionState status, NSError *openError) {
                     if (called) {
                         if ((status & FBSessionStateOpenTokenExtended) == FBSessionStateOpenTokenExtended &&
                             _tokenExtensionCallback) {
                             _tokenExtensionCallback([self authDataWithFacebookId:scopedCache.facebookId
                                                                      accessToken:scopedCache.accessToken
                                                                       expiration:scopedCache.expirationDate]);
                         }
                         return;
                     }
                     called = YES;
                     if (scopedOperationId != self.currentOperationId) {
                         [source trySetCancelled];
                         return;
                     }
                     if (callingSession.isOpen) {
                         // Success!  Now we need to get the FBID for the current user.
                         FBRequest *meRequest = [FBRequest requestWithGraphPath:@"me"
                                                                     parameters:@{ @"fields" : @"id" }
                                                                     HTTPMethod:@"GET"];
                         meRequest.session = callingSession;
                         [meRequest startWithCompletionHandler:^(FBRequestConnection *connection,
                                                                 id result,
                                                                 NSError *meError) {
                             if (scopedOperationId != self.currentOperationId) {
                                 [source trySetCancelled];
                                 return;
                             }
                             scopedCache.facebookId = result[@"id"];
                             if (meError) {
                                 [source trySetError:meError];
                             } else {
                                 NSDictionary *authData = [self authDataWithFacebookId:scopedCache.facebookId
                                                                           accessToken:scopedCache.accessToken
                                                                            expiration:scopedCache.expirationDate];

                                 // Check if this session has userID cached, if not - recreate the full
                                 // session from the authData we got.
                                 // This is done to make sure FBSession has `userID` cached and won't strip it away.
                                 if (!self.session.accessTokenData.userID) {
                                     [self restoreAuthenticationWithAuthData:nil];
                                     [self restoreAuthenticationWithAuthData:authData];
                                 } else {
                                     [FBSession setActiveSession:sessionProxy];
                                 }
                                 [source trySetResult:authData];
                             }
                         }];
                     } else if (openError) {
                         // An error occurred
                         [source trySetError:openError];
                     } else {
                         // Cancellation
                         [source trySetCancelled];
                     }
                 }];

    return source.task;
}

- (void)initializeSession {
    id sessionProxy = [[PFReceptionist alloc] initWithFactory:^id{
        FBSession.activeSession = nil;
        return [self.sessionProvider sessionWithAppID:self.appId
                                          permissions:self.permissions
                                      urlSchemeSuffix:self.urlSchemeSuffix
                                   tokenCacheStrategy:self.tokenCache];
    } thread:[NSThread mainThread]];
    self.session = FBSession.activeSession = sessionProxy;
}

- (BOOL)restoreAuthenticationWithAuthData:(nullable NSDictionary<NSString *, NSString *> *)authData {
    if (!authData) {
        OSAtomicIncrement32(&_currentOperationId);
        self.tokenCache.facebookId = nil;
        self.tokenCache.expirationDate = nil;
        self.tokenCache.accessToken = nil;
        self.session = nil;
        return YES;
    }

    NSString *accessToken = authData[@"access_token"];
    NSString *expirationDateString = authData[@"expiration_date"];
    if (accessToken && expirationDateString) {
        PFFacebookTokenCachingStrategy *newTokenCache;
        if (![accessToken isEqualToString:self.tokenCache.accessToken]) {
            // Only swap out the token cache if the access token changed (so that permissions, etc. are still cached).
            newTokenCache = [[PFFacebookTokenCachingStrategy alloc] init];
            newTokenCache.facebookId = authData[@"id"];
            newTokenCache.accessToken = accessToken;
            newTokenCache.expirationDate = [[NSDateFormatter pffb_preciseDateFormatter] dateFromString:expirationDateString];
            self.tokenCache = newTokenCache;
        } else {
            newTokenCache = self.tokenCache;
        }
        FBSession *rawSession = self._rawSession;
        if (!rawSession.isOpen ||
            !([rawSession.accessTokenData.accessToken isEqualToString:self.tokenCache.accessToken] &&
              [rawSession.accessTokenData.expirationDate isEqualToDate:self.tokenCache.expirationDate])) {
                // We don't pass the permissions here because we don't actually know the permissions for this access token at this point.
                rawSession = [self.sessionProvider sessionWithAppID:self.appId
                                                        permissions:nil
                                                    urlSchemeSuffix:self.urlSchemeSuffix
                                                 tokenCacheStrategy:self.tokenCache];
                if ([rawSession respondsToSelector:@selector(clearAffinitizedThread)]) {
                    [rawSession performSelector:@selector(clearAffinitizedThread)];
                }

                id sessionProxy = [[PFReceptionist alloc] initWithTarget:rawSession thread:[NSThread mainThread]];
                self.session = sessionProxy;

                // The session has changed altogether.  Open a new one if the token hasn't already expired.
                if (NSOrderedAscending == [self.tokenCache.expirationDate compare:[NSDate date]]) {
                    return YES;
                }

                int32_t scopedOperationId = OSAtomicIncrement32(&_currentOperationId);
                __block BOOL called = NO;

                if (rawSession.state == FBSessionStateCreatedTokenLoaded) {
                    [rawSession openWithBehavior:FBSessionLoginBehaviorWithNoFallbackToWebView
                              fromViewController:nil
                               completionHandler:^(FBSession *callingSession, FBSessionState status, NSError *error) {
                                   if (!called) {
                                       if (callingSession.isOpen && self.currentOperationId == scopedOperationId) {
                                           if ([rawSession respondsToSelector:@selector(clearAffinitizedThread)]) {
                                               [rawSession performSelector:@selector(clearAffinitizedThread)];
                                           }
                                           self.tokenCache = newTokenCache;

                                           if ([NSThread isMainThread]) {
                                               [FBSession setActiveSession:sessionProxy];
                                           } else {
                                               dispatch_async(dispatch_get_main_queue(), ^{
                                                   [FBSession setActiveSession:sessionProxy];
                                               });
                                           }
                                       }
                                   }
                                   called = YES;
                                   if ((status & FBSessionStateOpenTokenExtended) == FBSessionStateOpenTokenExtended &&
                                       _tokenExtensionCallback) {
                                       _tokenExtensionCallback([self authDataWithFacebookId:newTokenCache.facebookId
                                                                                accessToken:newTokenCache.accessToken
                                                                                 expiration:newTokenCache.expirationDate]);
                                   }
                               }];
                }
            }
        return YES;
    }
    return NO;
}

- (BFTask *)reauthorizeInBackground {
    if (!self.session.isOpen) {
        [NSException raise:NSInternalInconsistencyException
                    format:@"The user must already have a valid, open Facebook session to reauthorize."];
    }

    BFTaskCompletionSource *source = [BFTaskCompletionSource taskCompletionSource];

    NSString *originalFacebookId = self.tokenCache.facebookId;
    [self.session requestNewPublishPermissions:self.permissions
                               defaultAudience:_audience
                             completionHandler:^(FBSession *session, NSError *error) {
                                 if (error) {
                                     [source trySetError:error];
                                 } else {
                                     self.tokenCache.facebookId = originalFacebookId;
                                     NSDictionary *authData = [self authDataWithFacebookId:self.tokenCache.facebookId
                                                                               accessToken:self.tokenCache.accessToken
                                                                                expiration:self.tokenCache.expirationDate];
                                     [source trySetResult:authData];
                                 }
                             }];
    return source.task;
}

- (BOOL)handleOpenURL:(NSURL *)url {
    return [FBAppCall handleOpenURL:url
                  sourceApplication:@"com.facebook.ParseProxy"
                        withSession:self.session];
}

///--------------------------------------
#pragma mark - Accessors
///--------------------------------------

- (void)setLoginBehavior:(FBSessionLoginBehavior)loginBehavior {
    if (self.loginBehavior != loginBehavior) {
        _loginBehavior = loginBehavior;
    }
    self.useCustomLoginBehavior = YES;
}

///--------------------------------------
#pragma mark - PFFacebookSessionProvider
///--------------------------------------

- (FBSession *)sessionWithAppID:(NSString *)appId
                    permissions:(NSArray *)permissions
                urlSchemeSuffix:(NSString *)urlSchemeSuffix
             tokenCacheStrategy:(FBSessionTokenCachingStrategy *)strategy {
    return [[FBSession alloc] initWithAppID:appId
                                permissions:permissions
                            urlSchemeSuffix:urlSchemeSuffix
                         tokenCacheStrategy:strategy];
}

@end
