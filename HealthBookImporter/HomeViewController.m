//
//  HomeViewController.m
//  HealthBookImporter
//
//  Created by Gabriel Rinaldi on 6/4/14.
//  Copyright (c) 2014 Gabriel Rinaldi. All rights reserved.
//

#import "FitBitClient.h"
#import "HomeViewController.h"

#pragma mark HomeViewController (Private)

@interface HomeViewController () @end

#pragma mark - HomeViewController

@implementation HomeViewController

#pragma mark - Button actions

- (IBAction)logout {
    [[FitBitClient sharedClient] logout];

    [[FitBitClient sharedClient] requestForAuthentication];
}

#pragma mark - View lifecycle

- (void)viewDidLoad {
    [super viewDidLoad];


}

@end
