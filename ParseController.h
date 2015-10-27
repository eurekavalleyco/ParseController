//
//  ParseController.h
//  ParseController
//
//  Created by Ken M. Haggerty on 9/6/15.
//  Copyright (c) 2015 Eureka Valley Co. All rights reserved.
//

#pragma mark - // NOTES (Public) //

#pragma mark - // IMPORTS (Public) //

#import <Foundation/Foundation.h>
#import "MIMETypes.h"
#import <Parse/PFUser.h>
#import <Parse/PFObject.h>
#import <Parse/PFFile.h>
#import <Parse/PFQuery.h>

#pragma mark - // PROTOCOLS //

#pragma mark - // DEFINITIONS (Public) //

#define NOTIFICATION_PARSECONTROLLER_PUSHNOTIFICATIONSON_DID_CHANGE @"kNotificationParseControllerPushNotificationsOnDidChange"

#define NOTIFICATION_PARSECONTROLLER_CURRENTACCOUNT_DID_CHANGE @"kNotificationParseControllerCurrentAccountDidChange"
#define NOTIFICATION_PARSECONTROLLER_CURRENTACCOUNT_USERNAME_DID_CHANGE @"kNotificationParseControllerCurrentAccountUsernameDidChange"

@interface ParseController : NSObject

// SETUP //

+ (void)setupWithLaunchOptions:(NSDictionary *)launchOptions;
+ (void)setDeviceTokenFromData:(NSData *)deviceToken;
+ (void)trackAppOpenedWithLaunchOptions:(NSDictionary *)launchOptions;

// GENERAL //

+ (NSDate *)convertJSONDate:(NSString *)jsonDate;

// INSTALLATION //

+ (NSString *)installationId;
+ (NSArray *)channels;
+ (void)setChannels:(NSArray *)channels;

// PUSH NOTIFICATIONS //

+ (BOOL)pushNotificationsOn;
+ (void)setPushNotificationsOn:(BOOL)on;
+ (BOOL)shouldProcessPushNotificationWithData:(NSDictionary *)notificationPayload;
+ (void)handlePush:(NSDictionary *)notificationPayload;

// ACCOUNTS //

+ (PFUser *)currentAccount;
+ (BOOL)signInWithUsername:(NSString *)username password:(NSString *)password;
+ (BOOL)createAccountWithUsername:(NSString *)username email:(NSString *)email password:(NSString *)password userInfo:(NSDictionary *)userInfo;
+ (void)signOut;

// OBJECTS //

+ (void)fetchObjectsEventually:(PFQuery *)query withCompletion:(void (^)(NSArray *))completionBlock;
+ (void)fetchObjectEventually:(PFQuery *)query withCompletion:(void (^)(PFObject *))completionBlock;
+ (void)countObjectsEventually:(PFQuery *)query withCompletion:(void (^)(NSUInteger))completionBlock;
+ (void)saveObjectEventually:(PFObject *)object withCompletion:(void (^)(PFObject *))completionBlock;
+ (BOOL)addObjects:(NSSet *)objects toRelationWithKey:(NSString *)key onObject:(PFObject *)parseObject;
+ (BOOL)removeObjects:(NSSet *)objects fromRelationWithKey:(NSString *)key onObject:(PFObject *)parseObject;

// FILES //

+ (void)saveFileEventually:(PFFile *)file withCompletion:(void (^)(PFFile *))completionBlock;

// CLOUD CODE //

+ (void)performFunctionEventually:(NSString *)functionName withParameters:(NSDictionary *)parameters completion:(void (^)(id))completionBlock;

@end