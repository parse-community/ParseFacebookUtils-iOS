/**
 * Copyright (c) 2015-present, Parse, LLC.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import <Foundation/Foundation.h>

#import <Parse/PFUserAuthenticationDelegate.h>

#import "PFFacebookTokenCachingStrategy.h"

extern NSString *const PFFacebookUserAuthenticationType;

@protocol PFFacebookSessionProvider <NSObject>

- (FBSession *)sessionWithAppID:(NSString *)appId
                    permissions:(NSArray *)permissions
                urlSchemeSuffix:(NSString *)urlSchemeSuffix
             tokenCacheStrategy:(FBSessionTokenCachingStrategy *)strategy;

@end

@class BFTask;

@interface PFFacebookAuthenticationProvider : NSObject <PFUserAuthenticationDelegate>

- (BFTask *)authenticateAsync;
- (BFTask *)reauthorizeInBackground;

// Allows an existing session to be reauthorized with new permissions
- (NSDictionary *)authDataWithFacebookId:(NSString *)facebookId
                             accessToken:(NSString *)accessToken
                              expiration:(NSDate *)expiration;
- (void)initializeSession;
- (BOOL)handleOpenURL:(NSURL *)url;

@property (nonatomic, weak) id<PFFacebookSessionProvider> sessionProvider;

// Facebook and Session objects to be passed back to users
@property (nonatomic, strong, readonly) FBSession *session;
@property (nonatomic, assign) FBSessionLoginBehavior loginBehavior;

// Facebook SDK configuration options -- these are passed directly to Facebook and we
// don't do any further processing on them.
@property (nonatomic, copy) NSString *appId;
@property (nonatomic, copy) NSArray *permissions;
@property (nonatomic, copy) NSString *urlSchemeSuffix;
@property (nonatomic, assign) FBSessionDefaultAudience audience;

// A callback that occurs whenever a token extension occurs.  For now, we won't handle
// token extensions, but we may in the future.
@property (nonatomic, copy) void (^tokenExtensionCallback)(NSDictionary *authData);

@end
