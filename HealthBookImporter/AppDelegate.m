//
//  AppDelegate.m
//  HealthBookImporter
//
//  Created by Gabriel Rinaldi on 6/4/14.
//  Copyright (c) 2014 Gabriel Rinaldi. All rights reserved.
//

#import "AppDelegate.h"

#pragma mark AppDelegate (Private)

@interface AppDelegate () @end

#pragma mark - AppDelegate

@implementation AppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    self.window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];



    self.window.backgroundColor = [UIColor whiteColor];
    [self.window makeKeyAndVisible];

    return YES;
}

@end
