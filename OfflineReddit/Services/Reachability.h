/*
 Copyright (C) 2016 Apple Inc. All Rights Reserved.
 See LICENSE.txt for this sample’s licensing information
 
 Abstract:
 Basic demonstration of how to use the SystemConfiguration Reachablity APIs.
 */

#import <Foundation/Foundation.h>
#import <SystemConfiguration/SystemConfiguration.h>
#import <netinet/in.h>

NS_ASSUME_NONNULL_BEGIN

@protocol Reachable <NSObject>

@property (nonatomic, assign, readonly) BOOL isOnline;
@property (nonatomic, assign, readonly) BOOL isOffline;

@end

typedef enum : NSInteger {
	NotReachable = 0,
	ReachableViaWiFi,
	ReachableViaWWAN
} NetworkStatus;

#pragma mark IPv6 Support
//Reachability fully support IPv6.  For full details, see ReadMe.md.


extern NSNotificationName const ReachabilityChangedNotification;


@interface Reachability : NSObject <Reachable>

@property (nonatomic, strong, class, readonly) Reachability *sharedReachability;

/*!
 * Use to check the reachability of a given host name.
 */
+ (instancetype)reachabilityWithHostName:(NSString *)hostName;

/*!
 * Use to check the reachability of a given IP address.
 */
+ (instancetype)reachabilityWithAddress:(const struct sockaddr *)hostAddress;

/*!
 * Checks whether the default route is available. Should be used by applications that do not connect to a particular host.
 */
+ (instancetype)reachabilityForInternetConnection;


#pragma mark reachabilityForLocalWiFi
//reachabilityForLocalWiFi has been removed from the sample.  See ReadMe.md for more information.
//+ (instancetype)reachabilityForLocalWiFi;

/*!
 * Start listening for reachability notifications on the current run loop.
 */
- (BOOL)startNotifier;
- (void)stopNotifier;
@property (nonatomic, assign, readonly, getter=isNotifiying) BOOL notifiying;

@property (nonatomic, assign, readonly) NetworkStatus status;
@property (nonatomic, assign, readonly) BOOL isOnline;
@property (nonatomic, assign, readonly) BOOL isOffline;

/// Used for development purposes only when debugging without a connection.
@property (nonatomic, assign, getter=isEmulatingOnline) BOOL emulatingOnline;

/*!
 * WWAN may be available, but not active until a connection has been established. WiFi may require a connection for VPN on Demand.
 */
- (BOOL)connectionRequired;

@end

NS_ASSUME_NONNULL_END
