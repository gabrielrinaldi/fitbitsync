//
//  FitBitClient.m
//  HealthBookImporter
//
//  Created by Gabriel Rinaldi on 6/4/14.
//  Copyright (c) 2014 Gabriel Rinaldi. All rights reserved.
//

#import <AFNetworking/AFJSONRequestOperation.h>
#import "FitBitClient.h"

@import HealthKit;

static NSString * const kAPIBaseURLString = @"https://api.fitbit.com";
static NSString * const kCredentialIdentifier = @"FITBIT_CREDENTIAL_IDENTIFIER";
static NSString * const kLastUserUpdate = @"FITBIT_LAST_USER_UPDATE";
static NSString * const kUserAvatar = @"FITBIT_USER_AVATAR";
static NSString * const kDistanceUnit = @"FITBIT_DISTANCE_UNIT";
static NSString * const kWeightUnit = @"FITBIT_WEIGHT_UNIT";
static NSString * const kTimeZone = @"FITBIT_TIME_ZONE";
static NSString * const kSavedWeightIds = @"FITBIT_SAVED_WEIGHT_IDS";
static NSString * const kSavedBodyFatIds = @"FITBIT_SAVED_BODY_FAT_IDS";
static NSString * const kSavedTrackerData = @"FITBIT_SAVED_TRACKER_DATA";

#pragma mark FitBitClient

@interface FitBitClient ()

@property (strong, nonatomic) HKHealthStore *healthStore;

@end

#pragma mark - FitBitClient

@implementation FitBitClient

#pragma mark - Getters/Setters

@synthesize healthStore;

#pragma mark - Shared client

+ (instancetype)sharedClient {
    static FitBitClient *_sharedClient = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _sharedClient = [[FitBitClient alloc] initWithBaseURL:[NSURL URLWithString:kAPIBaseURLString] key:@"9d9552050b73429ab1b7329d22c62df9" secret:@"3b836038ec68482499ac2a9ff35c48b9"];
    });

    return _sharedClient;
}

#pragma mark - Initialization

- (id)initWithBaseURL:(NSURL *)url key:(NSString *)key secret:(NSString *)secret {
    self = [super initWithBaseURL:url key:key secret:secret];
    if (self) {
        [self registerHTTPOperationClass:[AFJSONRequestOperation class]];

        if ([HKHealthStore isHealthDataAvailable]) {
            self.healthStore = [[HKHealthStore alloc] init];
        }
    }

    return self;
}

#pragma mark - HealthKit

- (NSSet *)dataTypesToWrite {
    HKQuantityType *weightType = [HKQuantityType quantityTypeForIdentifier:HKQuantityTypeIdentifierBodyMass];
    HKQuantityType *bodyFatType = [HKQuantityType quantityTypeForIdentifier:HKQuantityTypeIdentifierBodyFatPercentage];
    HKQuantityType *stepCountType = [HKQuantityType quantityTypeForIdentifier:HKQuantityTypeIdentifierStepCount];
    HKQuantityType *flightsClimbedType = [HKQuantityType quantityTypeForIdentifier:HKQuantityTypeIdentifierFlightsClimbed];
    HKQuantityType *distanceType = [HKQuantityType quantityTypeForIdentifier:HKQuantityTypeIdentifierDistance];

    return [NSSet setWithObjects:weightType, bodyFatType, stepCountType, flightsClimbedType, distanceType, nil];
}

- (void)saveQuantityIntoHealthStore:(NSNumber *)quantityNumber date:(NSDate *)date type:(NSString *)type {
    if (quantityNumber) {
        HKUnit *unit;
        if ([type isEqualToString:HKQuantityTypeIdentifierBodyMass]) {
            unit = [HKUnit poundUnit];
            if ([[[NSUserDefaults standardUserDefaults] objectForKey:kWeightUnit] isEqualToString:@"METRIC"]) {
                unit = [HKUnit unitFromString:@"kg"];
            }
        } else if ([type isEqualToString:HKQuantityTypeIdentifierBodyFatPercentage]) {
            unit = [HKUnit percentUnit];
        } else if ([type isEqualToString:HKQuantityTypeIdentifierStepCount] || [type isEqualToString:HKQuantityTypeIdentifierFlightsClimbed]) {
            unit = [HKUnit countUnit];
        } else if ([type isEqualToString:HKQuantityTypeIdentifierDistance]) {
            unit = [HKUnit mileUnit];
            if ([[[NSUserDefaults standardUserDefaults] objectForKey:kWeightUnit] isEqualToString:@"METRIC"]) {
                unit = [HKUnit unitFromString:@"km"];
            }
        } else {
            return;
        }

        HKQuantityType *quantityType = [HKQuantityType quantityTypeForIdentifier:type];
        HKQuantity *quantity = [HKQuantity quantityWithUnit:unit doubleValue:[quantityNumber doubleValue]];
        HKQuantitySample *quantitySample = [HKQuantitySample quantitySampleWithType:quantityType quantity:quantity startDate:date endDate:date];

        [self.healthStore saveObject:quantitySample withCompletion:^(BOOL success, NSError *error) {
            if (!success) {
                NSLog(@"An error occured saving the sample %@. In your app, try to handle this gracefully. The error was: %@.", quantitySample, error);
            }
        }];
    }
}

#pragma mark - Authentication

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

- (void)logout {
    [AFOAuth1Token deleteCredentialWithIdentifier:kCredentialIdentifier];
}

#pragma mark - Synchronization

- (void)sync {
    NSSet *writeDataTypes = [self dataTypesToWrite];

    [self.healthStore requestAuthorizationToShareTypes:writeDataTypes readTypes:nil completion:^(BOOL success, NSError *error) {
        if (!success) {
            NSLog(@"You didn't allow HealthKit to access these read/write data types. In your app, try to handle this error gracefully when a user decides not to provide access. The error was: %@. If you're using a simulator, try it on a device.", error);
        } else {
            NSUserDefaults *standardUserDefaults = [NSUserDefaults standardUserDefaults];
            NSDate *lastUserUpdate = [standardUserDefaults objectForKey:kLastUserUpdate];
            if (!lastUserUpdate || [[NSDate date] timeIntervalSinceDate:lastUserUpdate] > 60 * 60 * 24) {
                [self getUser];

                return;
            }

            [self getWeight];
            [self getBodyFat];
            [self getActivity];
        }
    }];
}

- (void)getUser {
    [self getPath:@"/1/user/-/profile.json" parameters:nil success:^(AFHTTPRequestOperation *operation, id responseObject) {
        NSDictionary *user = responseObject[@"user"];

        NSUserDefaults *standardUserDefaults = [NSUserDefaults standardUserDefaults];
        [standardUserDefaults setObject:user[@"avatar150"] forKey:kUserAvatar];
        [standardUserDefaults setObject:user[@"distanceUnit"] forKey:kDistanceUnit];
        [standardUserDefaults setObject:user[@"weightUnit"] forKey:kWeightUnit];
        [standardUserDefaults setObject:user[@"timezone"] forKey:kTimeZone];
        [standardUserDefaults setObject:[NSDate date] forKey:kLastUserUpdate];

        [standardUserDefaults synchronize];

        [self sync];
    } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
        NSLog(@"Error: %@", error);
    }];
}

- (void)getWeight {
    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
    [dateFormatter setDateFormat:@"yyyy-MM-dd"];
    NSString *path = [NSString stringWithFormat:@"/1/user/-/body/log/weight/date/%@/1m.json", [dateFormatter stringFromDate:[NSDate date]]];
    [self getPath:path parameters:nil success:^(AFHTTPRequestOperation *operation, id responseObject) {
        NSUserDefaults *standardUserDefaults = [NSUserDefaults standardUserDefaults];
        NSArray *storedIds = [standardUserDefaults objectForKey:kSavedWeightIds];
        NSMutableArray *newIds = [[NSMutableArray alloc] init];

        for (NSDictionary *dict in responseObject[@"weight"]) {
            NSPredicate *predicate = [NSPredicate predicateWithFormat:@"self = %@", dict[@"logId"]];
            if ([[storedIds filteredArrayUsingPredicate:predicate] count] == 0) {
                double weight = [dict[@"weight"] doubleValue];

                NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
                [dateFormatter setDateFormat:@"yyyy-MM-dd HH:mm:ss VV"];

                NSString *date = [NSString stringWithFormat:@"%@ %@ %@", dict[@"date"], dict[@"time"], [standardUserDefaults objectForKey:kTimeZone]];

                [self saveQuantityIntoHealthStore:[NSNumber numberWithDouble:weight] date:[dateFormatter dateFromString:date] type:HKQuantityTypeIdentifierBodyMass];
            }

            [newIds addObject:dict[@"logId"]];
        }

        [standardUserDefaults setObject:newIds forKey:kSavedWeightIds];
        [standardUserDefaults synchronize];
    } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
        NSLog(@"Error: %@", error);
    }];
}

- (void)getBodyFat {
    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
    [dateFormatter setDateFormat:@"yyyy-MM-dd"];
    NSString *path = [NSString stringWithFormat:@"/1/user/-/body/log/fat/date/%@/1m.json", [dateFormatter stringFromDate:[NSDate date]]];
    [self getPath:path parameters:nil success:^(AFHTTPRequestOperation *operation, id responseObject) {
        NSUserDefaults *standardUserDefaults = [NSUserDefaults standardUserDefaults];
        NSArray *storedIds = [standardUserDefaults objectForKey:kSavedBodyFatIds];
        NSMutableArray *newIds = [[NSMutableArray alloc] init];

        for (NSDictionary *dict in responseObject[@"fat"]) {
            NSPredicate *predicate = [NSPredicate predicateWithFormat:@"self = %@", dict[@"logId"]];
            if ([[storedIds filteredArrayUsingPredicate:predicate] count] == 0) {
                double fat = [dict[@"fat"] doubleValue] / 100;

                NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
                [dateFormatter setDateFormat:@"yyyy-MM-dd HH:mm:ss VV"];

                NSString *date = [NSString stringWithFormat:@"%@ %@ %@", dict[@"date"], dict[@"time"], [standardUserDefaults objectForKey:kTimeZone]];

                [self saveQuantityIntoHealthStore:[NSNumber numberWithDouble:fat] date:[dateFormatter dateFromString:date] type:HKQuantityTypeIdentifierBodyFatPercentage];
            }

            [newIds addObject:dict[@"logId"]];
        }

        [standardUserDefaults setObject:newIds forKey:kSavedBodyFatIds];
        [standardUserDefaults synchronize];
    } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
        NSLog(@"Error: %@", error);
    }];
}

- (void)getActivity {
    NSUserDefaults *standardUserDefaults = [NSUserDefaults standardUserDefaults];
    NSDictionary *savedTrackerData = [standardUserDefaults objectForKey:kSavedTrackerData];

    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
    [dateFormatter setDateFormat:@"yyyy-MM-dd"];

    for (int i = 1; i <= 30; i++) {
        NSDate *date = [NSDate dateWithTimeInterval:(60 * 60 * 24 * i * -1) sinceDate:[NSDate date]];
        NSString *dateString = [dateFormatter stringFromDate:date];

        if (!savedTrackerData || [dateString isEqualToString:[dateFormatter stringFromDate:[NSDate date]]] || (savedTrackerData && !savedTrackerData[dateString])) {
            NSString *path = [NSString stringWithFormat:@"/1/user/-/activities/date/%@.json", dateString];
            [self getPath:path parameters:nil success:^(AFHTTPRequestOperation *operation, id responseObject) {
                NSString *dateString = [[[[[operation request] URL] pathComponents] lastObject] stringByReplacingOccurrencesOfString:@".json" withString:@""];
                NSUserDefaults *standardUserDefaults = [NSUserDefaults standardUserDefaults];
                NSMutableDictionary *savedTrackerData = [[NSMutableDictionary alloc] initWithDictionary:[standardUserDefaults objectForKey:kSavedTrackerData]];

                NSDate *date = [dateFormatter dateFromString:dateString];
                [self saveQuantityIntoHealthStore:[NSNumber numberWithInteger:[responseObject[@"summary"][@"steps"] integerValue]] date:date type:HKQuantityTypeIdentifierStepCount];
                [self saveQuantityIntoHealthStore:[NSNumber numberWithInteger:[responseObject[@"summary"][@"floors"] integerValue]] date:date type:HKQuantityTypeIdentifierFlightsClimbed];
                [self saveQuantityIntoHealthStore:[NSNumber numberWithDouble:[responseObject[@"summary"][@"distances"][0][@"distance"] floatValue]] date:date type:HKQuantityTypeIdentifierDistance];

                savedTrackerData[dateString] = @YES;
                [standardUserDefaults setObject:savedTrackerData forKey:kSavedTrackerData];
                [standardUserDefaults synchronize];
            } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
                NSLog(@"Error: %@", error);
            }];
        }
    }
}

@end
