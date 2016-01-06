/**
 * Copyright (c) 2015-present, Parse, LLC.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import "PFFacebookUtils.h"

#import <Bolts/BFTaskCompletionSource.h>

#import "PFFacebookAuthenticationProvider.h"
#import "PFFacebookPrivateUtilities.h"

@implementation PFFacebookUtils

static PFFacebookAuthenticationProvider *provider;

///--------------------------------------
#pragma mark - Authentication Provider
///--------------------------------------

+ (void)checkInitialization {
    if (!provider) {
        [NSException raise:NSInternalInconsistencyException
                    format:@"You must call PFFacebookUtils initializeFacebook to use PFFacebookUtils."];
    }
}

+ (PFFacebookAuthenticationProvider *)_authenticationProvider {
    return provider;
}

+ (void)_setAuthenticationProvider:(PFFacebookAuthenticationProvider *)authProvider {
    provider = authProvider;
}

///--------------------------------------
#pragma mark - Initialize
///--------------------------------------

+ (void)initializeWithApplicationId:(nullable NSString *)appId {
    [NSException raise:NSInternalInconsistencyException
                format:@"You must initialize PFFacebookUtils with a call to +initializeFacebook."];
}

+ (void)initializeWithApplicationId:(nullable NSString *)appId
                    urlSchemeSuffix:(nullable NSString *)urlSchemeSuffix {
    [NSException raise:NSInternalInconsistencyException
                format:@"You must initialize PFFacebookUtils with a call to +initializeFacebookWithUrlSchemeSuffix."];
}

+ (void)initializeFacebook {
    [self initializeFacebookWithUrlShemeSuffix:nil];
}

+ (void)initializeFacebookWithUrlShemeSuffix:(nullable NSString *)urlSchemeSuffix {
    if (!provider) {
        provider = [[PFFacebookAuthenticationProvider alloc] init];
        provider.urlSchemeSuffix = urlSchemeSuffix;

        [PFUser registerAuthenticationDelegate:provider forAuthType:PFFacebookUserAuthenticationType];
    }

    if (!provider.session) {
        [provider initializeSession];
    }
}

+ (FBSession *)session {
    return provider.session;
}

///--------------------------------------
#pragma mark - Customizing Login Behavior
///--------------------------------------

+ (void)setFacebookLoginBehavior:(FBSessionLoginBehavior)behavior {
    [self checkInitialization];
    provider.loginBehavior = behavior;
}

+ (FBSessionLoginBehavior)facebookLoginBehavior {
    [self checkInitialization];
    return provider.loginBehavior;
}

///--------------------------------------
#pragma mark - Log In
///--------------------------------------

+ (BFTask<PFUser *> *)logInWithPermissionsInBackground:(nullable NSArray<NSString *> *)permissions {
    [self checkInitialization];
    provider.permissions = permissions;

    return [[[self _authenticationProvider] authenticateAsync] continueWithSuccessBlock:^id(BFTask *task) {
        return [PFUser logInWithAuthTypeInBackground:PFFacebookUserAuthenticationType authData:task.result];
    }];
}

+ (void)logInWithPermissions:(nullable NSArray<NSString *> *)permissions
                       block:(nullable PFUserResultBlock)block {
    [[self logInWithPermissionsInBackground:permissions] pffb_continueWithMainThreadUserBlock:block];
}

+ (void)logInWithPermissions:(nullable NSArray<NSString *> *)permissions
                      target:(nullable id)target
                    selector:(nullable SEL)selector {
    [self logInWithPermissions:permissions block:^(PFUser *user, NSError *error) {
        [PFFacebookPrivateUtilities safePerformSelector:selector onTarget:target withObject:user object:error];
    }];
}

+ (BFTask<PFUser *> *)logInWithFacebookIdInBackground:(NSString *)facebookId
                                          accessToken:(NSString *)accessToken
                                       expirationDate:(NSDate *)expirationDate {
    [self checkInitialization];

    NSDictionary *authData = [provider authDataWithFacebookId:facebookId
                                                  accessToken:accessToken
                                                   expiration:expirationDate];

    return [PFUser logInWithAuthTypeInBackground:PFFacebookUserAuthenticationType authData:authData];
}

+ (void)logInWithFacebookId:(NSString *)facebookId
                accessToken:(NSString *)accessToken
             expirationDate:(NSDate *)expirationDate
                      block:(nullable PFUserResultBlock)block {
    [[self logInWithFacebookIdInBackground:facebookId
                               accessToken:accessToken
                            expirationDate:expirationDate] pffb_continueWithMainThreadUserBlock:block];
}

+ (void)logInWithFacebookId:(NSString *)facebookId
                accessToken:(NSString *)accessToken
             expirationDate:(NSDate *)expirationDate
                     target:(nullable id)target
                   selector:(nullable SEL)selector {
    [self logInWithFacebookId:facebookId
                  accessToken:accessToken
               expirationDate:expirationDate
                        block:^(PFUser *user, NSError *error) {
                            [PFFacebookPrivateUtilities safePerformSelector:selector
                                                                   onTarget:target
                                                                 withObject:user
                                                                     object:error];
                        }];
}

///--------------------------------------
#pragma mark - Link
///--------------------------------------

+ (void)linkUser:(PFUser *)user permissions:(nullable NSArray<NSString *> *)permissions {
    // This is misnamed `*InBackground` method. Left as is for backward compatability.
    [self linkUserInBackground:user permissions:permissions];
}

+ (BFTask<NSNumber *> *)linkUserInBackground:(PFUser *)user
                                 permissions:(nullable NSArray<NSString *> *)permissions {
    [self checkInitialization];
    provider.permissions = permissions;

    return [[[self _authenticationProvider] authenticateAsync] continueWithSuccessBlock:^id(BFTask *task) {
        return [user linkWithAuthTypeInBackground:PFFacebookUserAuthenticationType authData:task.result];
    }];
}

+ (void)linkUser:(PFUser *)user
     permissions:(nullable NSArray<NSString *> *)permissions
           block:(nullable PFBooleanResultBlock)block {
    [[self linkUserInBackground:user permissions:permissions] pffb_continueWithMainThreadBooleanBlock:block];
}

+ (void)linkUser:(PFUser *)user
     permissions:(nullable NSArray *)permissions
          target:(nullable id)target
        selector:(nullable SEL)selector {
    [self linkUser:user permissions:permissions block:^(BOOL succeeded, NSError *error) {
        [PFFacebookPrivateUtilities safePerformSelector:selector onTarget:target withObject:@(succeeded) object:error];
    }];
}

+ (BFTask<NSNumber *> *)linkUserInBackground:(PFUser *)user
                                  facebookId:(NSString *)facebookId
                                 accessToken:(NSString *)accessToken
                              expirationDate:(NSDate *)expirationDate {
    [self checkInitialization];

    NSDictionary *authData = [provider authDataWithFacebookId:facebookId
                                                  accessToken:accessToken
                                                   expiration:expirationDate];
    return [user linkWithAuthTypeInBackground:PFFacebookUserAuthenticationType authData:authData];
}

+ (void)linkUser:(PFUser *)user
      facebookId:(NSString *)facebookId
     accessToken:(NSString *)accessToken
  expirationDate:(NSDate *)expirationDate
           block:(nullable PFBooleanResultBlock)block {
    [[self linkUserInBackground:user
                     facebookId:facebookId
                    accessToken:accessToken
                 expirationDate:expirationDate] pffb_continueWithMainThreadBooleanBlock:block];
}

+ (void)linkUser:(PFUser *)user
      facebookId:(NSString *)facebookId
     accessToken:(NSString *)accessToken
  expirationDate:(NSDate *)expirationDate
          target:(nullable id)target
        selector:(nullable SEL)selector {
    [self linkUser:user
        facebookId:facebookId
       accessToken:accessToken
    expirationDate:expirationDate
             block:^(BOOL succeeded, NSError *error) {
                 [PFFacebookPrivateUtilities safePerformSelector:selector
                                                        onTarget:target
                                                      withObject:@(succeeded)
                                                          object:error];
             }];
}

///--------------------------------------
#pragma mark - Unlink
///--------------------------------------

+ (BOOL)unlinkUser:(PFUser *)user {
    return [self unlinkUser:user error:nil];
}

+ (BOOL)unlinkUser:(PFUser *)user error:(NSError **)error {
    return [[[self unlinkUserInBackground:user] pffb_waitForResult:error] boolValue];
}

+ (BFTask<NSNumber *> *)unlinkUserInBackground:(PFUser *)user {
    [self checkInitialization];
    return [user unlinkWithAuthTypeInBackground:PFFacebookUserAuthenticationType];
}

+ (void)unlinkUserInBackground:(PFUser *)user block:(nullable PFBooleanResultBlock)block {
    [[self unlinkUserInBackground:user] pffb_continueWithMainThreadBooleanBlock:block];
}

+ (void)unlinkUserInBackground:(PFUser *)user target:(nullable id)target selector:(nullable SEL)selector {
    [self unlinkUserInBackground:user block:^(BOOL succeeded, NSError *error) {
        [PFFacebookPrivateUtilities safePerformSelector:selector onTarget:target withObject:@(succeeded) object:error];
    }];
}

///--------------------------------------
#pragma mark - Reauthorize
///--------------------------------------

+ (BFTask<NSNumber *> *)reauthorizeUserInBackground:(PFUser *)user
                             withPublishPermissions:(nullable NSArray<NSString *> *)permissions
                                           audience:(FBSessionDefaultAudience)audience {
    [self checkInitialization];
    if (![self isLinkedWithUser:user]) {
        [NSException raise:NSInternalInconsistencyException
                    format:@"The user must already be linked with Facebook in order to reauthorize."];
    }
    provider.permissions = permissions;
    provider.audience = audience;

    return [[provider reauthorizeInBackground] continueWithSuccessBlock:^id(BFTask *task) {
        return [user linkWithAuthTypeInBackground:PFFacebookUserAuthenticationType authData:task.result];
    }];
}

+ (void)reauthorizeUser:(PFUser *)user
 withPublishPermissions:(nullable NSArray<NSString *> *)permissions
               audience:(FBSessionDefaultAudience)audience
                  block:(nullable PFBooleanResultBlock)block {
    [[self reauthorizeUserInBackground:user
                withPublishPermissions:permissions
                              audience:audience] pffb_continueWithMainThreadBooleanBlock:block];
}

+ (void)reauthorizeUser:(PFUser *)user
 withPublishPermissions:(nullable NSArray<NSString *> *)permissions
               audience:(FBSessionDefaultAudience)audience
                 target:(nullable id)target
               selector:(nullable SEL)selector {
    [self reauthorizeUser:user
   withPublishPermissions:permissions
                 audience:audience
                    block:^(BOOL succeeded, NSError *error) {
                        [PFFacebookPrivateUtilities safePerformSelector:selector
                                                               onTarget:target
                                                             withObject:@(succeeded)
                                                                 object:error];
                    }];
}

///--------------------------------------
#pragma mark - Getting Linked State
///--------------------------------------

+ (BOOL)isLinkedWithUser:(PFUser *)user {
    return [user isLinkedWithAuthType:PFFacebookUserAuthenticationType];
}

///--------------------------------------
#pragma mark - Deprecated
///--------------------------------------

+ (BOOL)handleOpenURL:(nullable NSURL *)url {
    return [provider handleOpenURL:url];
}

@end
