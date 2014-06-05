//
//  AppDelegate.m
//  HealthBookImporter
//
//  Created by Gabriel Rinaldi on 6/4/14.
//  Copyright (c) 2014 Gabriel Rinaldi. All rights reserved.
//

#import "FitBitClient.h"
#import "LoginViewController.h"
#import "AppDelegate.h"

#pragma mark AppDelegate (Private)

@interface AppDelegate () @end

#pragma mark - AppDelegate

@implementation AppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    self.window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];

    LoginViewController *loginViewController = [[LoginViewController alloc] initWithNibName:@"LoginViewController" bundle:nil];
    UINavigationController *navigationController = [[UINavigationController alloc] initWithRootViewController:loginViewController];
    self.window.rootViewController = navigationController;

    self.window.backgroundColor = [UIColor whiteColor];
    [self.window makeKeyAndVisible];

    if (![[FitBitClient sharedClient] requestForAuthentication]) {
        [[FitBitClient sharedClient] sync];
    }

    return YES;
}

- (BOOL)application:(UIApplication *)application openURL:(NSURL *)url sourceApplication:(NSString *)sourceApplication annotation:(id)annotation {
    if ([[url host] isEqualToString:@"oauth"]) {
        NSNotification *notification = [NSNotification notificationWithName:kAFApplicationLaunchedWithURLNotification object:nil userInfo:[NSDictionary dictionaryWithObject:url forKey:kAFApplicationLaunchOptionsURLKey]];
        [[NSNotificationCenter defaultCenter] postNotification:notification];

        return YES;
    }

    return NO;
}

@end
