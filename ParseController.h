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

#pragma mark - // PROTOCOLS //

@protocol PFObject <NSObject>
- (NSString *)objectId;
- (NSDate *)createdAt;
@end

@protocol PFFile <NSObject>
@end

@protocol AccountProtocol <PFObject>
- (NSString *)accountId;
- (NSString *)username;
@end

#pragma mark - // DEFINITIONS (Public) //

#define NOTIFICATION_PARSECONTROLLER_PUSHNOTIFICATIONSON_DID_CHANGE @"kNotificationParseControllerPushNotificationsOnDidChange"

#define NOTIFICATION_PARSECONTROLLER_CURRENTACCOUNT_DID_CHANGE @"kNotificationParseControllerCurrentAccountDidChange"
#define NOTIFICATION_PARSECONTROLLER_CURRENTACCOUNT_USERNAME_DID_CHANGE @"kNotificationParseControllerCurrentAccountUsernameDidChange"

@interface ParseController : NSObject

// SETUP //

+ (void)setupWithLaunchOptions:(NSDictionary *)launchOptions;
+ (void)trackAppOpenedWithLaunchOptions:(NSDictionary *)launchOptions;

// INSTALLATION //

+ (NSArray *)channels;
+ (void)setChannels:(NSArray *)channels;

// PUSH NOTIFICATIONS //

+ (void)setPushNotificationsOn:(BOOL)on;
+ (BOOL)pushNotificationsOn;

// ACCOUNTS //

+ (id <AccountProtocol>)currentAccount;
+ (BOOL)signInWithUsername:(NSString *)username password:(NSString *)password;
+ (BOOL)createAccountWithUsername:(NSString *)username email:(NSString *)email password:(NSString *)password userInfo:(NSDictionary *)userInfo;
+ (void)signOut;

// OBJECTS //

+ (void)createObjectWithClass:(NSString *)className block:(void (^)(id <PFObject>))block completion:(void (^)(id <PFObject>))completionBlock;
+ (BOOL)setObject:(id)object forKey:(NSString *)key onObject:(id <PFObject>)parseObject;
+ (BOOL)addObjects:(NSSet *)objects toRelationWithKey:(NSString *)key onObject:(id <PFObject>)parseObject;
+ (BOOL)removeObjects:(NSSet *)objects fromRelationWithKey:(NSString *)key onObject:(id <PFObject>)parseObject;

// FILES //

+ (void)createFileWithName:(NSString *)name data:(NSData *)data completionBlock:(void (^)(id <PFFile>))completionBlock;

@end