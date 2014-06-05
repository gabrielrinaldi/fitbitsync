//
//  FitBitClient.m
//  HealthBookImporter
//
//  Created by Gabriel Rinaldi on 6/4/14.
//  Copyright (c) 2014 Gabriel Rinaldi. All rights reserved.
//

#import <AFNetworking/AFJSONRequestOperation.h>
#import "FitBitClient.h"

static NSString * const kAPIBaseURLString = @"https://api.fitbit.com";
static NSString * const kCredentialIdentifier = @"FITBIT_CREDENTIAL_IDENTIFIER";

#pragma mark FitBitClient

@implementation FitBitClient

#pragma mark - Shared client

+ (instancetype)sharedClient {
    static FitBitClient *_sharedClient = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _sharedClient = [[FitBitClient alloc] initWithBaseURL:[NSURL URLWithString:kAPIBaseURLString] key:@"9d9552050b73429ab1b7329d22c62df9" secret:@"3b836038ec68482499ac2a9ff35c48b9"];
    });

    return _sharedClient;
}

- (id)initWithBaseURL:(NSURL *)url key:(NSString *)key secret:(NSString *)secret {
    self = [super initWithBaseURL:url key:key secret:secret];
    if (self) {
        [self registerHTTPOperationClass:[AFJSONRequestOperation class]];
    }

    return self;
}

- (BOOL)requestForAuthentication {
    AFOAuth1Token *accessToken = [AFOAuth1Token retrieveCredentialWithIdentifier:kCredentialIdentifier];
    if (accessToken) {
        self.accessToken = accessToken;

        return NO;
    }

    [self authorizeUsingOAuthWithRequestTokenPath:@"/oauth/request_token" userAuthorizationPath:@"/oauth/authorize" callbackURL:[NSURL URLWithString:@"hbi://oauth"] accessTokenPath:@"/oauth/access_token" accessMethod:@"POST" scope:nil success:^(AFOAuth1Token *accessToken, id responseObject) {
        [AFOAuth1Token storeCredential:accessToken withIdentifier:kCredentialIdentifier];

        [self sync];
    } failure:^(NSError *error) {
        NSLog(@"Error: %@", error);
    }];

    return YES;
}

- (void)sync {
    [self getWeight];
}

- (void)getWeight {
    [self getPath:@"/1/user/-/profile.json" parameters:nil success:^(AFHTTPRequestOperation *operation, id responseObject) {
        NSArray *responseArray = (NSArray *)responseObject;
        [responseArray enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
            NSLog(@"Success: %@", obj);
        }];
    } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
        NSLog(@"Error: %@", error);
    }];
}

@end
