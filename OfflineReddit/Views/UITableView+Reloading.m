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

- (void)insertRowsSafeAtIndexPaths:(NSArray<NSIndexPath *> *)indexPaths withRowAnimation:(UITableViewRowAnimation)animation
{
    [self beginUpdates];
    [self insertRowsAtIndexPaths:indexPaths withRowAnimation:animation];
    [self endUpdatesSafe];
}

- (void)deleteRowsSafeAtIndexPaths:(NSArray<NSIndexPath *> *)indexPaths withRowAnimation:(UITableViewRowAnimation)animation
{
    [self beginUpdates];
    [self deleteRowsAtIndexPaths:indexPaths withRowAnimation:animation];
    [self endUpdatesSafe];
}

- (void)reloadRowsSafeAtIndexPaths:(NSArray<NSIndexPath *> *)indexPaths withRowAnimation:(UITableViewRowAnimation)animation
{
    [self beginUpdates];
    [self reloadRowsAtIndexPaths:indexPaths withRowAnimation:animation];
    [self endUpdatesSafe];
}

@end
