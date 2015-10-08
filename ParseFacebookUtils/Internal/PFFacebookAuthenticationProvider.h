/**
 * Copyright (c) 2015-present, Parse, LLC.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import <Foundation/Foundation.h>

#import <FBSDKLoginKit/FBSDKLoginManager.h>

#import <Parse/PFConstants.h>
#import <Parse/PFUserAuthenticationDelegate.h>

@class BFTask PF_GENERIC(__covariant BFGenericType);

NS_ASSUME_NONNULL_BEGIN

extern NSString *const PFFacebookUserAuthenticationType;

@interface PFFacebookAuthenticationProvider : NSObject <PFUserAuthenticationDelegate>

@property (nonatomic, strong, readonly) FBSDKLoginManager *loginManager;

///--------------------------------------
/// @name Init
///--------------------------------------

- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;

- (instancetype)initWithApplication:(UIApplication *)application
                      launchOptions:(nullable NSDictionary *)launchOptions NS_DESIGNATED_INITIALIZER;
+ (instancetype)providerWithApplication:(UIApplication *)application
                          launchOptions:(nullable NSDictionary *)launchOptions;;

///--------------------------------------
/// @name Authenticate
///--------------------------------------

- (BFTask *)authenticateAsyncWithReadPermissions:(nullable NSArray PF_GENERIC(NSString *) *)readPermissions
                              publishPermissions:(nullable NSArray PF_GENERIC(NSString *) *)publishPermissions;

@end

NS_ASSUME_NONNULL_END
