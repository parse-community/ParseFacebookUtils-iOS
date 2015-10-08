/**
 * Copyright (c) 2015-present, Parse, LLC.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import <FacebookSDK/FBSessionTokenCachingStrategy.h>

/*!
 A token caching strategy that allows us to easily access and modify
 the cached access token, facebook ID, and expiration date.
 */
@interface PFFacebookTokenCachingStrategy : FBSessionTokenCachingStrategy

@property (nonatomic, copy) NSString *accessToken;
@property (nonatomic, copy) NSString *facebookId;
@property (nonatomic, copy) NSDate *expirationDate;

@end
