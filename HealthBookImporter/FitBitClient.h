//
//  FitBitClient.h
//  HealthBookImporter
//
//  Created by Gabriel Rinaldi on 6/4/14.
//  Copyright (c) 2014 Gabriel Rinaldi. All rights reserved.
//

#import <AFOAuth1Client/AFOAuth1Client.h>

#pragma mark FitBitClient

@interface FitBitClient : AFOAuth1Client

+ (instancetype)sharedClient;
- (BOOL)requestForAuthentication;
- (void)logout;
- (void)sync;

@end
