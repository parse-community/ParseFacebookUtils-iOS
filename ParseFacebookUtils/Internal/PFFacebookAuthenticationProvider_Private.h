/**
 * Copyright (c) 2015-present, Parse, LLC.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import <FBSDKLoginKit/FBSDKLoginManager.h>

#import "PFFacebookAuthenticationProvider.h"

@class FBSDKAccessToken;

@interface PFFacebookAuthenticationProvider ()

@property (nonatomic, strong, readwrite) FBSDKLoginManager *loginManager;

+ (NSDictionary *)_userAuthenticationDataWithFacebookUserId:(NSString *)userId
                                                accessToken:(NSString *)accessToken
                                             expirationDate:(NSDate *)expirationDate;
+ (NSDictionary *)_userAuthenticationDataFromAccessToken:(FBSDKAccessToken *)token;

@end
