//
//  UITableView+Reloading.m
//  OfflineReddit
//
//  Created by Jake Bellamy on 21/03/17.
//  Copyright © 2017 Jake Bellamy. All rights reserved.
//

#import "UITableView+Reloading.h"

@implementation UITableView (Reloading)

- (void)endUpdatesSafe
{
    @try {
        [self endUpdates];
    } @catch (NSException *exception) {
        NSLog(@"Caught exception: %@", exception);
        [self reloadData];
    }
}

@end
