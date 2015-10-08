/**
 * Copyright (c) 2015-present, Parse, LLC.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import "PFFacebookAuthenticationProvider.h"
#import "PFFacebookAuthenticationProvider_Private.h"

#import <Bolts/BFTask.h>
#import <Bolts/BFTaskCompletionSource.h>

#import <FBSDKCoreKit/FBSDKAccessToken.h>
#import <FBSDKCoreKit/FBSDKApplicationDelegate.h>
#import <FBSDKCoreKit/FBSDKSettings.h>

#import <FBSDKLoginKit/FBSDKLoginManagerLoginResult.h>

#import <Parse/PFConstants.h>

#import "PFFacebookPrivateUtilities.h"

NSString *const PFFacebookUserAuthenticationType = @"facebook";

@implementation PFFacebookAuthenticationProvider

///--------------------------------------
#pragma mark - Init
///--------------------------------------

- (instancetype)initWithApplication:(UIApplication *)application
                      launchOptions:(nullable NSDictionary *)launchOptions {
    self = [super init];
    if (!self) return nil;

    _loginManager = [[FBSDKLoginManager alloc] init];

    [[FBSDKApplicationDelegate sharedInstance] application:[UIApplication sharedApplication]
                             didFinishLaunchingWithOptions:launchOptions];

    return self;
}

+ (instancetype)providerWithApplication:(UIApplication *)application
                          launchOptions:(nullable NSDictionary *)launchOptions {
    return [[self alloc] initWithApplication:application launchOptions:launchOptions];
}

///--------------------------------------
#pragma mark - User Authentication Data
///--------------------------------------

+ (NSDictionary *)_userAuthenticationDataWithFacebookUserId:(NSString *)userId
                                                accessToken:(NSString *)accessToken
                                             expirationDate:(NSDate *)expirationDate {
    return @{ @"id" : userId,
              @"access_token" : accessToken,
              @"expiration_date" : [[NSDateFormatter pffb_preciseDateFormatter] stringFromDate:expirationDate] };
}

+ (NSDictionary *)_userAuthenticationDataFromAccessToken:(FBSDKAccessToken *)token {
    if (!token.userID || !token.tokenString || !token.expirationDate) {
        return nil;
    }

    return [self _userAuthenticationDataWithFacebookUserId:token.userID
                                               accessToken:token.tokenString
                                            expirationDate:token.expirationDate];
}

+ (FBSDKAccessToken *)_facebookAccessTokenFromUserAuthenticationData:(nullable NSDictionary PF_GENERIC(NSString *,NSString *) *)authData {
    NSString *accessToken = authData[@"access_token"];
    NSString *expirationDateString = authData[@"expiration_date"];
    if (!accessToken || !expirationDateString) {
        return nil;
    }

    NSDate *expirationDate = [[NSDateFormatter pffb_preciseDateFormatter] dateFromString:expirationDateString];
    FBSDKAccessToken *token = [[FBSDKAccessToken alloc] initWithTokenString:accessToken
                                                                permissions:nil
                                                        declinedPermissions:nil
                                                                      appID:[FBSDKSettings appID]
                                                                     userID:authData[@"id"]
                                                             expirationDate:expirationDate
                                                                refreshDate:nil];
    return token;
}

///--------------------------------------
#pragma mark - Authenticate
///--------------------------------------

- (BFTask *)authenticateAsyncWithReadPermissions:(nullable NSArray PF_GENERIC(NSString *) *)readPermissions
                              publishPermissions:(nullable NSArray PF_GENERIC(NSString *) *)publishPermissions {
    if (readPermissions && publishPermissions) {
        NSException *exception = [NSException exceptionWithName:NSInvalidArgumentException
                                                         reason:@"Read permissions are not permitted to be requested with publish permissions."
                                                       userInfo:nil];
        return [BFTask taskWithException:exception];
    }

    BFTaskCompletionSource *taskCompletionSource = [BFTaskCompletionSource taskCompletionSource];
    FBSDKLoginManagerRequestTokenHandler resultHandler = ^(FBSDKLoginManagerLoginResult *result, NSError *error) {
        if (result.isCancelled) {
            [taskCompletionSource cancel];
        } else if (error) {
            taskCompletionSource.error = error;
        } else {
            taskCompletionSource.result = [[self class] _userAuthenticationDataFromAccessToken:result.token];
        }
    };
    if (publishPermissions) {
        [self.loginManager logInWithPublishPermissions:publishPermissions
                                    fromViewController:[PFFacebookPrivateUtilities applicationTopViewController]
                                               handler:resultHandler];
    } else {
        [self.loginManager logInWithReadPermissions:readPermissions
                                 fromViewController:[PFFacebookPrivateUtilities applicationTopViewController]
                                            handler:resultHandler];
    }
    return taskCompletionSource.task;
}

///--------------------------------------
#pragma mark - PFUserAuthenticationDelegate
///--------------------------------------

- (BOOL)restoreAuthenticationWithAuthData:(nullable NSDictionary PF_GENERIC(NSString *,NSString *) *)authData {
    FBSDKAccessToken *token = [[self class] _facebookAccessTokenFromUserAuthenticationData:authData];
    if (!token) {
        // Only deauthenticate if authData was nil, otherwise - fail with an error
        if (!authData) {
            [self.loginManager logOut];
            return YES;
        }
        return NO;
    }

    FBSDKAccessToken *currentToken = [FBSDKAccessToken currentAccessToken];
    // Do not reset the current token if we have the same token already set.
    if (![currentToken.userID isEqualToString:token.userID] ||
        ![currentToken.tokenString isEqualToString:token.tokenString]) {
        [FBSDKAccessToken setCurrentAccessToken:token];
    }

    return YES;
}

@end
