/**
 * Copyright (c) 2015-present, Parse, LLC.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import "PFFacebookTokenCachingStrategy.h"

@interface PFFacebookTokenCachingStrategy ()

@property (nonatomic, strong) NSMutableDictionary *tokenInfo;

@end

@implementation PFFacebookTokenCachingStrategy

@synthesize tokenInfo;

- (void)prepareTokenInfo {
    if (!self.tokenInfo) {
        // fetchTokenInformation will cache the token data in tokenInfo.
        [super fetchTokenInformation];
        if (!self.tokenInfo) {
            self.tokenInfo = [NSMutableDictionary dictionaryWithCapacity:3];
        }
    }
}

- (NSDictionary *)fetchTokenInformation {
    NSDictionary *fetched = [super fetchTokenInformation];
    self.tokenInfo = [NSMutableDictionary dictionaryWithDictionary:fetched];
    return fetched;
}

- (void)clearToken {
    [super clearToken];
    self.tokenInfo = nil;
}

- (void)cacheTokenInformation:(NSDictionary *)tokenInformation {
    if ([[NSDate distantFuture] isEqualToDate:tokenInformation[FBTokenInformationExpirationDateKey]]) {
        // iOS 6 has real trouble with parsing serialized dates that are equal to distantFuture.
        // Facebook's SDK currently has a known bug that causes access tokens that are retrieved from iOS to
        // have expirations that are in the distantFuture.
        //
        // This is a hack to turn them into "really long expirations" (i.e. 2 years) to get around that until
        // Facebook and Apple get their act together.
        NSMutableDictionary *newTokenInfo = [NSMutableDictionary dictionaryWithDictionary:tokenInformation];
        newTokenInfo[FBTokenInformationExpirationDateKey] = [NSDate dateWithTimeInterval:60 * 60 * 24 * 365 * 2 sinceDate:[NSDate date]];
        tokenInformation = newTokenInfo;
    }
    [super cacheTokenInformation:tokenInformation];
    self.tokenInfo = [NSMutableDictionary dictionaryWithDictionary:tokenInformation];
}

- (NSString *)accessToken {
    [self prepareTokenInfo];
    return [self.tokenInfo objectForKey:FBTokenInformationTokenKey];
}

- (void)setAccessToken:(NSString *)accessToken {
    [self prepareTokenInfo];
    if (!accessToken) {
        [self.tokenInfo removeObjectForKey:FBTokenInformationTokenKey];
    } else {
        [self.tokenInfo setObject:accessToken forKey:FBTokenInformationTokenKey];
    }
    [self cacheTokenInformation:self.tokenInfo];
}

- (NSDate *)expirationDate {
    [self prepareTokenInfo];
    return [self.tokenInfo objectForKey:FBTokenInformationExpirationDateKey];
}

- (void)setExpirationDate:(NSDate *)expirationDate {
    [self prepareTokenInfo];
    if (!expirationDate) {
        [self.tokenInfo removeObjectForKey:FBTokenInformationExpirationDateKey];
    } else {
        [self.tokenInfo setObject:expirationDate forKey:FBTokenInformationExpirationDateKey];
    }
    [self cacheTokenInformation:self.tokenInfo];
}

- (NSString *)facebookId {
    [self prepareTokenInfo];
    return [self.tokenInfo objectForKey:FBTokenInformationUserFBIDKey];
}

- (void)setFacebookId:(NSString *)facebookId {
    [self prepareTokenInfo];
    if (!facebookId) {
        [self.tokenInfo removeObjectForKey:FBTokenInformationUserFBIDKey];
    } else {
        [self.tokenInfo setObject:facebookId forKey:FBTokenInformationUserFBIDKey];
    }
    [self cacheTokenInformation:self.tokenInfo];
}

@end
