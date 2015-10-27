//
//  ParseController.m
//  ParseController
//
//  Created by Ken M. Haggerty on 9/6/15.
//  Copyright (c) 2015 Eureka Valley Co. All rights reserved.
//

#pragma mark - // NOTES (Private) //

#pragma mark - // IMPORTS (Private) //

#import "ParseController.h"
#import "AKDebugger.h"
#import "AKGenerics.h"
#import <Parse/Parse.h>
#import "AKSystemInfo.h"
#import "PrivateInfo.h"
#import "AKSystemInfo.h"

#pragma mark - // PROTOCOLS (Private) //

@protocol Save <NSObject>
- (BOOL)save:(NSError **)error;
@end

#pragma mark - // DEFINITIONS (Private) //

#define CLOUDCODE_FUNCTION_ACCOUNTDIDLOGIN @"accountDidLogIn"
#define CLOUDCODE_FUNCTION_ACCOUNTWILLLOGOUT @"accountWillLogOut"

#define CLOUDCODE_PARAM_IPADDRESS @"ipAddress"

#define PFINSTALLATION_KEY_PUSHNOTIFICATIONSON @"pushNotificationsOn"
#define PFINSTALLATION_KEY_CURRENTACCOUNT @"currentAccount"
#define PFINSTALLATION_KEY_IPADDRESS_CURRENT @"currentIpAddress"
#define PFINSTALLATION_KEY_IPADDRESSES_ALL @"allIpAddresses"

#define PUSH_KEY_INSTALLATIONID @"installationId"

#define QUEUEDQUERY_KEY_TYPE @"queryType"
#define QUEUEDQUERY_KEY_QUERY @"query"
#define QUEUEDQUERY_KEY_COMPLETION @"completion"

#define QUEUEDFUNCTION_KEY_FUNCTIONNAME @"functionName"
#define QUEUEDFUNCTION_KEY_PARAMETERS @"parameters"
#define QUEUEDFUNCTION_KEY_COMPLETIONBLOCK @"completionBlock"

typedef enum {
    PFQueryFetchAll,
    PFQueryFetchFirst,
    PFQueryCount
} PFQueryType;

@interface ParseController ()
@property (nonatomic, strong) NSThread *threadSave;
@property (nonatomic, strong) NSThread *threadFetch;
@property (nonatomic, strong) NSThread *threadCall;
@property (nonatomic, strong) NSMutableArray *unsavedObjects;
@property (nonatomic, strong) NSMutableArray *queuedQueries;
@property (nonatomic, strong) NSMutableArray *objectCompletionBlocks;
@property (nonatomic, strong) NSMutableArray *queuedFunctions;
@property (nonatomic, strong) PFInstallation *currentInstallation;
@property (nonatomic, strong) PFUser *currentAccount;

// GENERAL //

+ (id)sharedController;
- (void)setup;
- (void)teardown;

// OBSERVERS //

- (void)addObserversToSystemInfo;
- (void)removeObserversFromSystemInfo;

// RESPONDERS //

- (void)internetStatusDidChange:(NSNotification *)notification;
- (void)publicIpAddressDidChange:(NSNotification *)notification;

// CONVENIENCE //

+ (NSThread *)threadSave;
+ (NSThread *)threadFetch;
+ (NSThread *)threadCall;
+ (NSMutableArray *)unsavedObjects;
+ (NSMutableArray *)queuedQueries;
+ (NSMutableArray *)objectCompletionBlocks;
+ (NSMutableArray *)queuedFunctions;
+ (PFInstallation *)currentInstallation;
+ (void)setCurrentAccount:(PFUser *)currentAccount;

// VALIDATORS //

+ (BOOL)validNameForPFFile:(NSString *)name;

// SAVE //

- (void)save;

// FETCH //

- (void)fetch;
+ (void)queueQuery:(PFQuery *)query ofType:(PFQueryType)queryType withCompletion:(id)completionBlock;

// CALL //

- (void)call;

@end

@implementation ParseController

#pragma mark - // SETTERS AND GETTERS //

@synthesize threadSave = _threadSave;
@synthesize threadFetch = _threadFetch;
@synthesize threadCall = _threadCall;
@synthesize unsavedObjects = _unsavedObjects;
@synthesize queuedQueries = _queuedQueries;
@synthesize objectCompletionBlocks = _objectCompletionBlocks;
@synthesize queuedFunctions = _queuedFunctions;
@synthesize currentInstallation = _currentInstallation;
@synthesize currentAccount = _currentAccount;

- (NSThread *)threadSave
{
    [AKDebugger logMethod:METHOD_NAME logType:AKLogTypeMethodName methodType:AKMethodTypeGetter customCategories:nil message:nil];
    
    if (_threadSave) return _threadSave;
    
    _threadSave = [[NSThread alloc] initWithTarget:self selector:@selector(save) object:nil];
    [_threadSave setName:[NSString stringWithFormat:@"%@.%@.%@", [AKSystemInfo bundleIdentifier], NSStringFromClass([self class]), NSStringFromSelector(@selector(threadSave))]];
    return _threadSave;
}

- (NSThread *)threadFetch
{
    [AKDebugger logMethod:METHOD_NAME logType:AKLogTypeMethodName methodType:AKMethodTypeGetter customCategories:nil message:nil];
    
    if (_threadFetch) return _threadFetch;
    
    _threadFetch = [[NSThread alloc] initWithTarget:self selector:@selector(fetch) object:nil];
    [_threadFetch setName:[NSString stringWithFormat:@"%@.%@.%@", [AKSystemInfo bundleIdentifier], NSStringFromClass([self class]), NSStringFromSelector(@selector(threadFetch))]];
    return _threadFetch;
}

- (NSThread *)threadCall
{
    [AKDebugger logMethod:METHOD_NAME logType:AKLogTypeMethodName methodType:AKMethodTypeGetter customCategories:nil message:nil];
    
    if (_threadCall) return _threadCall;
    
    _threadCall = [[NSThread alloc] initWithTarget:self selector:@selector(call) object:nil];
    [_threadCall setName:[NSString stringWithFormat:@"%@.%@.%@", [AKSystemInfo bundleIdentifier], NSStringFromClass([self class]), NSStringFromSelector(@selector(threadCall))]];
    return _threadCall;
}

- (NSMutableArray *)unsavedObjects
{
    [AKDebugger logMethod:METHOD_NAME logType:AKLogTypeMethodName methodType:AKMethodTypeGetter customCategories:nil message:nil];
    
    if (_unsavedObjects) return _unsavedObjects;
    
    _unsavedObjects = [NSMutableArray array];
    return _unsavedObjects;
}

- (NSMutableArray *)queuedQueries
{
    [AKDebugger logMethod:METHOD_NAME logType:AKLogTypeMethodName methodType:AKMethodTypeGetter customCategories:nil message:nil];
    
    if (_queuedQueries) return _queuedQueries;
    
    _queuedQueries = [NSMutableArray array];
    return _queuedQueries;
}

- (NSMutableArray *)objectCompletionBlocks
{
    [AKDebugger logMethod:METHOD_NAME logType:AKLogTypeMethodName methodType:AKMethodTypeGetter customCategories:nil message:nil];
    
    if (_objectCompletionBlocks) return _objectCompletionBlocks;
    
    _objectCompletionBlocks = [NSMutableArray array];
    return _objectCompletionBlocks;
}

- (NSMutableArray *)queuedFunctions
{
    [AKDebugger logMethod:METHOD_NAME logType:AKLogTypeMethodName methodType:AKMethodTypeGetter customCategories:nil message:nil];
    
    if (_queuedFunctions) return _queuedFunctions;
    
    _queuedFunctions = [NSMutableArray array];
    return _queuedFunctions;
}

- (PFInstallation *)currentInstallation
{
    [AKDebugger logMethod:METHOD_NAME logType:AKLogTypeMethodName methodType:AKMethodTypeGetter customCategories:@[AKD_PARSE] message:nil];
    
    if (_currentInstallation) return _currentInstallation;
    
    _currentInstallation = [PFInstallation currentInstallation];
    NSString *ipAddress = [AKSystemInfo publicIpAddress];
    if (ipAddress)
    {
        [_currentInstallation addUniqueObject:ipAddress forKey:PFINSTALLATION_KEY_IPADDRESSES_ALL];
        [_currentInstallation setObject:ipAddress forKey:PFINSTALLATION_KEY_IPADDRESS_CURRENT];
        [ParseController saveObjectEventually:_currentInstallation withCompletion:nil];
    }
    return _currentInstallation;
}

- (void)setCurrentAccount:(PFUser *)currentAccount
{
    [AKDebugger logMethod:METHOD_NAME logType:AKLogTypeMethodName methodType:AKMethodTypeSetter customCategories:@[AKD_PARSE] message:nil];
    
    if ([AKGenerics object:currentAccount isEqualToObject:_currentAccount]) return;
    
    NSString *oldUsername, *newUsername;
    if (_currentAccount)
    {
        oldUsername = _currentAccount.username;
    }
    if (currentAccount)
    {
        newUsername = currentAccount.username;
    }
    
    _currentAccount = currentAccount;
    
    if (![AKGenerics object:currentAccount isEqualToObject:[self.currentInstallation objectForKey:PFINSTALLATION_KEY_CURRENTACCOUNT]])
    {
        if (currentAccount)
        {
            [self.currentInstallation setObject:currentAccount forKey:PFINSTALLATION_KEY_CURRENTACCOUNT];
        }
        else
        {
            [self.currentInstallation removeObjectForKey:PFINSTALLATION_KEY_CURRENTACCOUNT];
        }
        [ParseController saveObjectEventually:self.currentInstallation withCompletion:nil];
    }
    
    NSMutableDictionary *userInfo = [NSMutableDictionary dictionary];
    if (currentAccount) [userInfo setObject:currentAccount forKey:NOTIFICATION_OBJECT_KEY];
    [AKGenerics postNotificationName:NOTIFICATION_PARSECONTROLLER_CURRENTACCOUNT_DID_CHANGE object:nil userInfo:userInfo];
    if ([AKGenerics object:oldUsername isEqualToObject:newUsername]) return;
    
    userInfo = [NSMutableDictionary dictionary];
    if (newUsername) [userInfo setObject:newUsername forKey:NOTIFICATION_OBJECT_KEY];
    [AKGenerics postNotificationName:NOTIFICATION_PARSECONTROLLER_CURRENTACCOUNT_USERNAME_DID_CHANGE object:nil userInfo:userInfo];
}

- (PFUser *)currentAccount
{
    [AKDebugger logMethod:METHOD_NAME logType:AKLogTypeMethodName methodType:AKMethodTypeGetter customCategories:@[AKD_PARSE] message:nil];
    
    PFUser *currentAccount = [PFUser currentUser];
    [self setCurrentAccount:currentAccount];
    return currentAccount;
}

#pragma mark - // INITS AND LOADS //

- (id)init
{
    [AKDebugger logMethod:METHOD_NAME logType:AKLogTypeMethodName methodType:AKMethodTypeSetup customCategories:@[AKD_PARSE] message:nil];
    
    self = [super init];
    if (!self)
    {
        [AKDebugger logMethod:METHOD_NAME logType:AKLogTypeCritical methodType:AKMethodTypeSetup customCategories:@[AKD_PARSE] message:[NSString stringWithFormat:@"%@ is nil", stringFromVariable(self)]];
        return nil;
    }
    
    [self setup];
    return self;
}

- (void)awakeFromNib
{
    [AKDebugger logMethod:METHOD_NAME logType:AKLogTypeMethodName methodType:AKMethodTypeSetup customCategories:@[AKD_PARSE] message:nil];
    
    [super awakeFromNib];
    [self setup];
}

- (void)dealloc
{
    [AKDebugger logMethod:METHOD_NAME logType:AKLogTypeMethodName methodType:AKMethodTypeSetup customCategories:@[AKD_PARSE] message:nil];
    
    [self teardown];
}

#pragma mark - // PUBLIC METHODS (Setup) //

+ (void)setupWithLaunchOptions:(NSDictionary *)launchOptions
{
    [AKDebugger logMethod:METHOD_NAME logType:AKLogTypeMethodName methodType:AKMethodTypeSetup customCategories:@[AKD_PARSE] message:nil];
    
    [ParseController sharedController];
    [Parse setApplicationId:[PrivateInfo parseApplicationId] clientKey:[PrivateInfo parseClientKey]];
    [PFUser enableRevocableSessionInBackground];
    [PFAnalytics trackAppOpenedWithLaunchOptions:launchOptions];
}

+ (void)setDeviceTokenFromData:(NSData *)deviceToken
{
    [AKDebugger logMethod:METHOD_NAME logType:AKLogTypeMethodName methodType:AKMethodTypeSetup customCategories:@[AKD_PARSE] message:nil];
    
    PFInstallation *currentInstallation = [ParseController currentInstallation];
    [currentInstallation setDeviceTokenFromData:deviceToken];
    [ParseController saveObjectEventually:currentInstallation withCompletion:nil];
}

+ (void)trackAppOpenedWithLaunchOptions:(NSDictionary *)launchOptions
{
    [AKDebugger logMethod:METHOD_NAME logType:AKLogTypeMethodName methodType:AKMethodTypeSetup customCategories:@[AKD_PARSE] message:nil];
    
    [PFAnalytics trackAppOpenedWithLaunchOptions:launchOptions];
}

#pragma mark - // PUBLIC METHODS (General) //

+ (NSDate *)convertJSONDate:(NSString *)jsonDate
{
    [AKDebugger logMethod:METHOD_NAME logType:AKLogTypeMethodName methodType:AKMethodTypeUnspecified customCategories:nil message:nil];
    
    NSDateFormatter *dateFormat = [[NSDateFormatter alloc] init];
    [dateFormat setDateFormat:@"yyyy-MM-dd'T'HH:mm:ss.SSSz"];
    return [dateFormat dateFromString:jsonDate];
}

#pragma mark - // PUBLIC METHODS (Installation) //

+ (NSString *)installationId
{
    [AKDebugger logMethod:METHOD_NAME logType:AKLogTypeMethodName methodType:AKMethodTypeGetter customCategories:@[AKD_PARSE] message:nil];
    
    return [[ParseController currentInstallation] installationId];
}

+ (NSArray *)channels
{
    [AKDebugger logMethod:METHOD_NAME logType:AKLogTypeMethodName methodType:AKMethodTypeGetter customCategories:@[AKD_PARSE] message:nil];
    
    return [[ParseController currentInstallation] channels];
}

+ (void)setChannels:(NSArray *)channels
{
    [AKDebugger logMethod:METHOD_NAME logType:AKLogTypeMethodName methodType:AKMethodTypeSetter customCategories:@[AKD_PARSE] message:nil];
    
    PFInstallation *currentInstallation = [ParseController currentInstallation];
    if ([AKGenerics object:channels isEqualToObject:[currentInstallation channels]]) return;
    
    [currentInstallation setChannels:channels];
    [ParseController saveObjectEventually:currentInstallation withCompletion:nil];
}

#pragma mark - // PUBLIC METHODS (Push Notifications) //

+ (BOOL)pushNotificationsOn
{
    [AKDebugger logMethod:METHOD_NAME logType:AKLogTypeMethodName methodType:AKMethodTypeGetter customCategories:@[AKD_PUSH_NOTIFICATIONS] message:nil];
    
    PFInstallation *currentInstallation = [ParseController currentInstallation];
    if (!currentInstallation) return NO;
    
    NSNumber *onNumber = [currentInstallation objectForKey:PFINSTALLATION_KEY_PUSHNOTIFICATIONSON];
    if (!onNumber) return NO;
    
    return [onNumber boolValue];
}

+ (void)setPushNotificationsOn:(BOOL)on
{
    [AKDebugger logMethod:METHOD_NAME logType:AKLogTypeMethodName methodType:AKMethodTypeSetter customCategories:@[AKD_PARSE] message:nil];
    
    PFInstallation *currentInstallation = [ParseController currentInstallation];
    NSNumber *onNumber = [NSNumber numberWithBool:on];
    if ([AKGenerics object:onNumber isEqualToObject:[currentInstallation objectForKey:PFINSTALLATION_KEY_PUSHNOTIFICATIONSON]]) return;
    
    [currentInstallation setObject:onNumber forKey:PFINSTALLATION_KEY_PUSHNOTIFICATIONSON];
    [ParseController saveObjectEventually:currentInstallation withCompletion:nil];
    
    [AKGenerics postNotificationName:NOTIFICATION_PARSECONTROLLER_PUSHNOTIFICATIONSON_DID_CHANGE object:nil userInfo:[NSDictionary dictionaryWithObject:onNumber forKey:NOTIFICATION_OBJECT_KEY]];
}

+ (BOOL)shouldProcessPushNotificationWithData:(NSDictionary *)notificationPayload
{
    [AKDebugger logMethod:METHOD_NAME logType:AKLogTypeMethodName methodType:AKMethodTypeValidator customCategories:@[AKD_PUSH_NOTIFICATIONS] message:nil];
    
    NSString *installationId = [notificationPayload objectForKey:PUSH_KEY_INSTALLATIONID];
    if ([installationId isEqualToString:[ParseController currentInstallation].objectId]) return NO;
    
    return YES;
}

+ (void)handlePush:(NSDictionary *)notificationPayload
{
    [AKDebugger logMethod:METHOD_NAME logType:AKLogTypeMethodName methodType:AKMethodTypeUnspecified customCategories:nil message:nil];
    
    [PFPush handlePush:notificationPayload];
}

#pragma mark - // PUBLIC METHODS (Accounts) //

+ (PFUser *)currentAccount
{
    [AKDebugger logMethod:METHOD_NAME logType:AKLogTypeMethodName methodType:AKMethodTypeGetter customCategories:@[AKD_ACCOUNTS] message:nil];
    
    return [[ParseController sharedController] currentAccount];
}

+ (BOOL)signInWithUsername:(NSString *)username password:(NSString *)password
{
    [AKDebugger logMethod:METHOD_NAME logType:AKLogTypeMethodName methodType:AKMethodTypeAction customCategories:@[AKD_PARSE, AKD_ACCOUNTS] message:nil];
    
    NSError *error;
    PFUser *account = [PFUser logInWithUsername:username password:password error:&error];
    if (error)
    {
        [AKDebugger logMethod:METHOD_NAME logType:AKLogTypeError methodType:AKMethodTypeAction customCategories:@[AKD_PARSE, AKD_ACCOUNTS] message:[NSString stringWithFormat:@"%@, %@", error, error.userInfo]];
    }
    if (!account)
    {
        [AKDebugger logMethod:METHOD_NAME logType:AKLogTypeInfo methodType:AKMethodTypeAction customCategories:@[AKD_PARSE, AKD_ACCOUNTS] message:[NSString stringWithFormat:@"Could not log in"]];
        return NO;
    }
    
    [PFCloud callFunction:CLOUDCODE_FUNCTION_ACCOUNTDIDLOGIN withParameters:@{CLOUDCODE_PARAM_IPADDRESS:[AKSystemInfo publicIpAddress]} error:&error];
    if (error)
    {
        [AKDebugger logMethod:METHOD_NAME logType:AKLogTypeError methodType:AKMethodTypeAction customCategories:@[AKD_PARSE, AKD_ACCOUNTS] message:[NSString stringWithFormat:@"%@, %@", error, error.userInfo]];
    }
    [ParseController setCurrentAccount:account];
    return YES;
}

+ (BOOL)createAccountWithUsername:(NSString *)username email:(NSString *)email password:(NSString *)password userInfo:(NSDictionary *)userInfo
{
    [AKDebugger logMethod:METHOD_NAME logType:AKLogTypeMethodName methodType:AKMethodTypeCreator customCategories:@[AKD_PARSE, AKD_ACCOUNTS] message:nil];
    
    PFUser *account = [PFUser user];
    [account setUsername:username];
    [account setEmail:email];
    [account setPassword:password];
    for (id key in [userInfo allKeys])
    {
        [account setObject:[userInfo objectForKey:key] forKey:key];
    }
    NSError *error;
    BOOL success = [account signUp:&error];
    if (error)
    {
        [AKDebugger logMethod:METHOD_NAME logType:AKLogTypeError methodType:AKMethodTypeCreator customCategories:@[AKD_PARSE, AKD_ACCOUNTS] message:[NSString stringWithFormat:@"%@, %@", error, error.userInfo]];
    }
    if (!success)
    {
        [AKDebugger logMethod:METHOD_NAME logType:AKLogTypeNotice methodType:AKMethodTypeCreator customCategories:@[AKD_PARSE, AKD_ACCOUNTS] message:[NSString stringWithFormat:@"Could not create %@", stringFromVariable(account)]];
        return NO;
    }
    
    [PFCloud callFunction:CLOUDCODE_FUNCTION_ACCOUNTDIDLOGIN withParameters:@{CLOUDCODE_PARAM_IPADDRESS:[AKSystemInfo publicIpAddress]} error:&error];
    if (error)
    {
        [AKDebugger logMethod:METHOD_NAME logType:AKLogTypeError methodType:AKMethodTypeAction customCategories:@[AKD_PARSE, AKD_ACCOUNTS] message:[NSString stringWithFormat:@"%@, %@", error, error.userInfo]];
    }
    [ParseController setCurrentAccount:account];
    return YES;
}

+ (void)signOut
{
    [AKDebugger logMethod:METHOD_NAME logType:AKLogTypeMethodName methodType:AKMethodTypeAction customCategories:@[AKD_PARSE, AKD_ACCOUNTS] message:nil];
    
    NSError *error;
    [PFCloud callFunction:CLOUDCODE_FUNCTION_ACCOUNTWILLLOGOUT withParameters:@{CLOUDCODE_PARAM_IPADDRESS:[AKSystemInfo publicIpAddress]} error:&error];
    if (error)
    {
        [AKDebugger logMethod:METHOD_NAME logType:AKLogTypeError methodType:AKMethodTypeAction customCategories:@[AKD_PARSE, AKD_ACCOUNTS] message:[NSString stringWithFormat:@"%@, %@", error, error.userInfo]];
    }
    [PFUser logOut];
    [ParseController setCurrentAccount:nil];
}

#pragma mark - // PUBLIC METHODS (Objects) //

+ (void)fetchObjectsEventually:(PFQuery *)query withCompletion:(void (^)(NSArray *))completionBlock
{
    [AKDebugger logMethod:METHOD_NAME logType:AKLogTypeMethodName methodType:AKMethodTypeUnspecified customCategories:@[AKD_PARSE] message:nil];
    
    [ParseController queueQuery:(PFQuery *)query ofType:PFQueryFetchAll withCompletion:completionBlock];
}

+ (void)fetchObjectEventually:(PFQuery *)query withCompletion:(void (^)(PFObject *))completionBlock
{
    [AKDebugger logMethod:METHOD_NAME logType:AKLogTypeMethodName methodType:AKMethodTypeUnspecified customCategories:@[AKD_PARSE] message:nil];
    
    [ParseController queueQuery:(PFQuery *)query ofType:PFQueryFetchFirst withCompletion:completionBlock];
}

+ (void)countObjectsEventually:(PFQuery *)query withCompletion:(void (^)(NSUInteger))completionBlock
{
    [AKDebugger logMethod:METHOD_NAME logType:AKLogTypeMethodName methodType:AKMethodTypeUnspecified customCategories:@[AKD_PARSE] message:nil];
    
    [ParseController queueQuery:(PFQuery *)query ofType:PFQueryCount withCompletion:completionBlock];
}

+ (void)saveObjectEventually:(PFObject *)object withCompletion:(void (^)(PFObject *))completionBlock
{
    [AKDebugger logMethod:METHOD_NAME logType:AKLogTypeMethodName methodType:AKMethodTypeUnspecified customCategories:@[AKD_PARSE] message:nil];
    
    [ParseController saveEventually:object withCompletion:completionBlock];
    
//    NSMutableArray *unsavedObjects = [ParseController unsavedObjects];
//    if ([unsavedObjects containsObject:object])
//    {
//        if (completionBlock)
//        {
//            [[[ParseController objectCompletionBlocks] objectAtIndex:[unsavedObjects indexOfObject:object]] addObject:completionBlock];
//        }
//    }
//    else
//    {
//        [unsavedObjects addObject:object];
//        NSMutableArray *blocks = [NSMutableArray array];
//        if (completionBlock) [blocks addObject:completionBlock];
//        [[ParseController objectCompletionBlocks] addObject:blocks];
//    }
//    if ([AKSystemInfo isReachable] && ![[ParseController threadSave] isExecuting])
//    {
//        [[ParseController threadSave] start];
//    }
}

+ (BOOL)addObjects:(NSSet *)objects toRelationWithKey:(NSString *)key onObject:(PFObject *)parseObject
{
    [AKDebugger logMethod:METHOD_NAME logType:AKLogTypeMethodName methodType:AKMethodTypeSetter customCategories:@[AKD_PARSE] message:nil];
    
    BOOL valid = YES;
    if (!objects)
    {
        [AKDebugger logMethod:METHOD_NAME logType:AKLogTypeWarning methodType:AKMethodTypeSetter customCategories:@[AKD_PARSE] message:[NSString stringWithFormat:@"%@ is nil", stringFromVariable(objects)]];
        valid = NO;
    }
    else if (!objects.count)
    {
        return YES;
    }
    if (!key)
    {
        [AKDebugger logMethod:METHOD_NAME logType:AKLogTypeWarning methodType:AKMethodTypeSetter customCategories:@[AKD_PARSE] message:[NSString stringWithFormat:@"%@ is nil", stringFromVariable(key)]];
        valid = NO;
    }
    if (!parseObject)
    {
        [AKDebugger logMethod:METHOD_NAME logType:AKLogTypeWarning methodType:AKMethodTypeSetter customCategories:@[AKD_PARSE] message:[NSString stringWithFormat:@"%@ is nil", stringFromVariable(parseObject)]];
        valid = NO;
    }
    if (!valid) return NO;
    
    NSArray *oldObjects;
    PFRelation *relation = [parseObject relationForKey:key];
    if (relation)
    {
        NSError *error;
        oldObjects = [[relation query] findObjects:&error];
        if (error)
        {
            [AKDebugger logMethod:METHOD_NAME logType:AKLogTypeError methodType:AKMethodTypeSetter customCategories:@[AKD_PARSE] message:[NSString stringWithFormat:@"%@, %@", error, error.userInfo]];
        }
    }
    if ([objects isSubsetOfSet:[NSSet setWithArray:oldObjects]]) return YES;
    
    for (PFObject *object in objects)
    {
        [relation addObject:object];
    }
//    [ParseController saveObjectEventually:parseObject withCompletion:nil];
    return YES;
}

+ (BOOL)removeObjects:(NSSet *)objects fromRelationWithKey:(NSString *)key onObject:(PFObject *)parseObject
{
    [AKDebugger logMethod:METHOD_NAME logType:AKLogTypeMethodName methodType:AKMethodTypeSetter customCategories:@[AKD_PARSE] message:nil];
    
    BOOL valid = YES;
    if (!objects)
    {
        [AKDebugger logMethod:METHOD_NAME logType:AKLogTypeWarning methodType:AKMethodTypeSetter customCategories:@[AKD_PARSE] message:[NSString stringWithFormat:@"%@ is nil", stringFromVariable(objects)]];
        valid = NO;
    }
    else if (!objects.count)
    {
        return YES;
    }
    if (!key)
    {
        [AKDebugger logMethod:METHOD_NAME logType:AKLogTypeWarning methodType:AKMethodTypeSetter customCategories:@[AKD_PARSE] message:[NSString stringWithFormat:@"%@ is nil", stringFromVariable(key)]];
        valid = NO;
    }
    if (!parseObject)
    {
        [AKDebugger logMethod:METHOD_NAME logType:AKLogTypeWarning methodType:AKMethodTypeSetter customCategories:@[AKD_PARSE] message:[NSString stringWithFormat:@"%@ is nil", stringFromVariable(parseObject)]];
    }
    if (!valid) return NO;
    
    NSArray *oldObjects;
    PFRelation *relation = [parseObject relationForKey:key];
    if (!relation)
    {
        [AKDebugger logMethod:METHOD_NAME logType:AKLogTypeWarning methodType:AKMethodTypeSetter customCategories:@[AKD_PARSE] message:[NSString stringWithFormat:@"No %@ for %@ %@", NSStringFromClass([PFRelation class]), stringFromVariable(key), key]];
        return NO;
    }
    
    NSError *error;
    oldObjects = [[relation query] findObjects:&error];
    if (error)
    {
        [AKDebugger logMethod:METHOD_NAME logType:AKLogTypeError methodType:AKMethodTypeSetter customCategories:@[AKD_PARSE] message:[NSString stringWithFormat:@"%@, %@", error, error.userInfo]];
    }
    NSMutableSet *objectsToRemove = [NSMutableSet setWithArray:oldObjects];
    [objectsToRemove intersectSet:objects];
    if (!objectsToRemove.count) return YES;
    
    for (PFObject *object in objectsToRemove)
    {
        [relation removeObject:object];
    }
//    [ParseController saveObjectEventually:parseObject withCompletion:nil];
    return YES;
}

#pragma mark - // PUBLIC METHODS (Files) //

+ (void)saveFileEventually:(PFFile *)file withCompletion:(void (^)(PFFile *))completionBlock
{
    [AKDebugger logMethod:METHOD_NAME logType:AKLogTypeMethodName methodType:AKMethodTypeUnspecified customCategories:@[AKD_PARSE] message:nil];
    
    [ParseController saveEventually:file withCompletion:completionBlock];
    
//    NSMutableArray *unsavedObjects = [ParseController unsavedObjects];
//    if ([unsavedObjects containsObject:file])
//    {
//        if (completionBlock)
//        {
//            [[[ParseController objectCompletionBlocks] objectAtIndex:[unsavedObjects indexOfObject:file]] addObject:completionBlock];
//        }
//    }
//    else
//    {
//        [unsavedObjects addObject:file];
//        NSMutableArray *blocks = [NSMutableArray array];
//        if (completionBlock) [blocks addObject:completionBlock];
//        [[ParseController objectCompletionBlocks] addObject:blocks];
//    }
//    if ([AKSystemInfo isReachable] && ![[ParseController threadSave] isExecuting])
//    {
//        [[ParseController threadSave] start];
//    }
}

#pragma mark - // PUBLIC METHODS (Cloud Code) //

+ (void)performFunctionEventually:(NSString *)functionName withParameters:(NSDictionary *)parameters completion:(void (^)(id))completionBlock
{
    [AKDebugger logMethod:METHOD_NAME logType:AKLogTypeMethodName methodType:AKMethodTypeUnspecified customCategories:@[AKD_PARSE] message:nil];
    
    if (!functionName)
    {
        [AKDebugger logMethod:METHOD_NAME logType:AKLogTypeNotice methodType:AKMethodTypeUnspecified customCategories:@[AKD_PARSE] message:[NSString stringWithFormat:@"%@ cannot be nil", stringFromVariable(functionName)]];
        return;
    }
    
    NSMutableArray *queuedFunctions = [ParseController queuedFunctions];
    NSMutableDictionary *dictionary = [NSMutableDictionary dictionaryWithObject:functionName forKey:QUEUEDFUNCTION_KEY_FUNCTIONNAME];
    if (parameters) [dictionary setObject:parameters forKey:QUEUEDFUNCTION_KEY_PARAMETERS];
    if (completionBlock) [dictionary setObject:completionBlock forKey:QUEUEDFUNCTION_KEY_COMPLETIONBLOCK];
    [queuedFunctions addObject:dictionary];
    if ([AKSystemInfo isReachable] && ![[ParseController threadCall] isExecuting])
    {
        [[ParseController threadCall] start];
    }
}

#pragma mark - // CATEGORY METHODS //

#pragma mark - // DELEGATED METHODS //

#pragma mark - // OVERWRITTEN METHODS //

#pragma mark - // PRIVATE METHODS (General) //

+ (id)sharedController
{
    [AKDebugger logMethod:METHOD_NAME logType:AKLogTypeMethodName methodType:AKMethodTypeGetter customCategories:nil message:nil];
    
    static ParseController *_sharedController = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _sharedController = [[ParseController alloc] init];
    });
    return _sharedController;
}

- (void)setup
{
    [AKDebugger logMethod:METHOD_NAME logType:AKLogTypeMethodName methodType:AKMethodTypeSetup customCategories:@[AKD_PARSE] message:nil];
    
    [self addObserversToSystemInfo];
}

- (void)teardown
{
    [AKDebugger logMethod:METHOD_NAME logType:AKLogTypeMethodName methodType:AKMethodTypeSetup customCategories:@[AKD_PARSE] message:nil];
    
    [self removeObserversFromSystemInfo];
    
    [self.threadSave cancel];
    [self.threadFetch cancel];
}

#pragma mark - // PRIVATE METHODS (Observers) //

- (void)addObserversToSystemInfo
{
    [AKDebugger logMethod:METHOD_NAME logType:AKLogTypeMethodName methodType:AKMethodTypeSetup customCategories:nil message:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(internetStatusDidChange:) name:NOTIFICATION_INTERNETSTATUS_DID_CHANGE object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(publicIpAddressDidChange:) name:NOTIFICATION_PUBLIC_IPADDRESS_DID_CHANGE object:nil];
}

- (void)removeObserversFromSystemInfo
{
    [AKDebugger logMethod:METHOD_NAME logType:AKLogTypeMethodName methodType:AKMethodTypeSetup customCategories:nil message:nil];
    
    [[NSNotificationCenter defaultCenter] removeObserver:self name:NOTIFICATION_INTERNETSTATUS_DID_CHANGE object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:NOTIFICATION_PUBLIC_IPADDRESS_DID_CHANGE object:nil];
}

#pragma mark - // PRIVATE METHODS (Responders) //

- (void)internetStatusDidChange:(NSNotification *)notification
{
    [AKDebugger logMethod:METHOD_NAME logType:AKLogTypeMethodName methodType:AKMethodTypeUnspecified customCategories:@[AKD_NOTIFICATION_CENTER] message:nil];
    
    if ([AKSystemInfo isReachable])
    {
        if (self.unsavedObjects.count && ![[ParseController threadSave] isExecuting])
        {
            [[ParseController threadSave] start];
        }
        if (self.queuedQueries.count && ![[ParseController threadFetch] isExecuting])
        {
            [[ParseController threadFetch] start];
        }
    }
}

- (void)publicIpAddressDidChange:(NSNotification *)notification
{
    [AKDebugger logMethod:METHOD_NAME logType:AKLogTypeMethodName methodType:AKMethodTypeUnspecified customCategories:@[AKD_NOTIFICATION_CENTER] message:nil];
    
    NSString *ipAddress = [notification.userInfo objectForKey:NOTIFICATION_OBJECT_KEY];
    if (ipAddress)
    {
        [self.currentInstallation addUniqueObject:ipAddress forKey:PFINSTALLATION_KEY_IPADDRESSES_ALL];
        [self.currentInstallation setObject:ipAddress forKey:PFINSTALLATION_KEY_IPADDRESS_CURRENT];
    }
    else
    {
        [self.currentInstallation removeObjectForKey:PFINSTALLATION_KEY_IPADDRESS_CURRENT];
    }
    [ParseController saveObjectEventually:self.currentInstallation withCompletion:nil];
}

#pragma mark - // PRIVATE METHODS (Convenience) //

+ (NSThread *)threadSave
{
    [AKDebugger logMethod:METHOD_NAME logType:AKLogTypeMethodName methodType:AKMethodTypeGetter customCategories:nil message:nil];
    
    return [[ParseController sharedController] threadSave];
}

+ (NSThread *)threadFetch
{
    [AKDebugger logMethod:METHOD_NAME logType:AKLogTypeMethodName methodType:AKMethodTypeGetter customCategories:nil message:nil];
    
    return [[ParseController sharedController] threadFetch];
}

+ (NSThread *)threadCall
{
    [AKDebugger logMethod:METHOD_NAME logType:AKLogTypeMethodName methodType:AKMethodTypeGetter customCategories:nil message:nil];
    
    return [[ParseController sharedController] threadCall];
}

+ (NSMutableArray *)unsavedObjects
{
    [AKDebugger logMethod:METHOD_NAME logType:AKLogTypeMethodName methodType:AKMethodTypeGetter customCategories:nil message:nil];
    
    return [[ParseController sharedController] unsavedObjects];
}

+ (NSMutableArray *)queuedQueries
{
    [AKDebugger logMethod:METHOD_NAME logType:AKLogTypeMethodName methodType:AKMethodTypeGetter customCategories:nil message:nil];
    
    return [[ParseController sharedController] queuedQueries];
}

+ (NSMutableArray *)objectCompletionBlocks
{
    [AKDebugger logMethod:METHOD_NAME logType:AKLogTypeMethodName methodType:AKMethodTypeGetter customCategories:nil message:nil];
    
    return [[ParseController sharedController] objectCompletionBlocks];
}

+ (NSMutableArray *)queuedFunctions
{
    [AKDebugger logMethod:METHOD_NAME logType:AKLogTypeMethodName methodType:AKMethodTypeGetter customCategories:nil message:nil];
    
    return [[ParseController sharedController] queuedFunctions];
}

+ (PFInstallation *)currentInstallation
{
    [AKDebugger logMethod:METHOD_NAME logType:AKLogTypeMethodName methodType:AKMethodTypeGetter customCategories:@[AKD_PARSE] message:nil];
    
    return [[ParseController sharedController] currentInstallation];
}

+ (void)setCurrentAccount:(PFUser *)currentAccount
{
    [AKDebugger logMethod:METHOD_NAME logType:AKLogTypeMethodName methodType:AKMethodTypeSetter customCategories:@[AKD_PARSE, AKD_ACCOUNTS] message:nil];
    
    [[ParseController sharedController] setCurrentAccount:currentAccount];
}

#pragma mark - // PRIVATE METHODS (Validators) //

+ (BOOL)validNameForPFFile:(NSString *)name
{
    [AKDebugger logMethod:METHOD_NAME logType:AKLogTypeMethodName methodType:AKMethodTypeValidator customCategories:@[AKD_PARSE] message:nil];
    
    if (!name)
    {
        [AKDebugger logMethod:METHOD_NAME logType:AKLogTypeInfo methodType:AKMethodTypeValidator customCategories:@[AKD_PARSE] message:[NSString stringWithFormat:@"%@ cannot be nil for %@", stringFromVariable(name), NSStringFromClass([PFFile class])]];
        return NO;
    }
    
    if (!name.length)
    {
        [AKDebugger logMethod:METHOD_NAME logType:AKLogTypeInfo methodType:AKMethodTypeValidator customCategories:@[AKD_PARSE] message:[NSString stringWithFormat:@"%@ cannot be empty for %@", stringFromVariable(name), NSStringFromClass([PFFile class])]];
        return NO;
    }
    
    if (![AKGenerics text:[name substringToIndex:1] onlyContainsCharactersInSet:[NSCharacterSet alphanumericCharacterSet]])
    {
        [AKDebugger logMethod:METHOD_NAME logType:AKLogTypeInfo methodType:AKMethodTypeValidator customCategories:@[AKD_PARSE] message:[NSString stringWithFormat:@"%@ for %@ must begin with an alphanumeric character", stringFromVariable(name), NSStringFromClass([PFFile class])]];
        return NO;
    }
    
    NSMutableCharacterSet *allowedCharacters = [NSMutableCharacterSet characterSetWithCharactersInString:@". _-"];
    [allowedCharacters formUnionWithCharacterSet:[NSCharacterSet alphanumericCharacterSet]];
    if (![AKGenerics text:name onlyContainsCharactersInSet:allowedCharacters])
    {
        [AKDebugger logMethod:METHOD_NAME logType:AKLogTypeInfo methodType:AKMethodTypeValidator customCategories:@[AKD_PARSE] message:[NSString stringWithFormat:@"%@ for %@ can only contain alphanumeric characters, periods, spaces, underscores, and dashes", stringFromVariable(name), NSStringFromClass([PFFile class])]];
        return NO;
    }
    
    return YES;
}

#pragma mark - // PRIVATE METHODS (Save) //

- (void)save
{
    [AKDebugger logMethod:METHOD_NAME logType:AKLogTypeMethodName methodType:AKMethodTypeUnspecified customCategories:@[AKD_PARSE] message:nil];
    
    NSError *error;
    BOOL saved = [PFObject saveAll:self.unsavedObjects error:&error];
    if (error)
    {
        [AKDebugger logMethod:METHOD_NAME logType:AKLogTypeError methodType:AKMethodTypeUnspecified customCategories:@[AKD_PARSE] message:[NSString stringWithFormat:@"%@, %@", error, error.userInfo]];
    }
    id <Save> object;
    PFObject *parseObject;
    PFFile *parseFile;
    NSMutableArray *blocks;
    void (^objectCompletionBlock)(PFObject *);
    void (^fileCompletionBlock)(PFFile *);
    if (saved)
    {
        for (int i = 0; i < self.unsavedObjects.count; i++)
        {
            blocks = [self.objectCompletionBlocks objectAtIndex:i];
            if (blocks.count)
            {
                object = [self.unsavedObjects objectAtIndex:i];
                for (int j = 0; j < blocks.count; j++)
                {
                    if ([object isKindOfClass:[PFObject class]])
                    {
                        parseObject = (PFObject *)object;
                        if ([parseObject isDirty])
                        {
                            [parseObject save:&error];
                            if (error)
                            {
                                [AKDebugger logMethod:METHOD_NAME logType:AKLogTypeError methodType:AKMethodTypeUnspecified customCategories:@[AKD_PARSE] message:[NSString stringWithFormat:@"%@, %@", error, error.userInfo]];
                            }
                        }
                        objectCompletionBlock = [blocks objectAtIndex:j];
                        objectCompletionBlock(parseObject);
                    }
                    else if ([object isKindOfClass:[PFFile class]])
                    {
                        parseFile = (PFFile *)object;
                        fileCompletionBlock = [blocks objectAtIndex:j];
                        fileCompletionBlock(parseFile);
                    }
                }
            }
        }
        [self.objectCompletionBlocks removeAllObjects];
        [self.unsavedObjects removeAllObjects];
    }
    else
    {
        NSUInteger i = 0;
        while (i < self.unsavedObjects.count)
        {
            object = [self.unsavedObjects objectAtIndex:i];
            saved = [object save:&error];
            if (error)
            {
                [AKDebugger logMethod:METHOD_NAME logType:AKLogTypeError methodType:AKMethodTypeUnspecified customCategories:@[AKD_PARSE] message:[NSString stringWithFormat:@"%@, %@", error, error.userInfo]];
            }
            if (saved)
            {
                blocks = [self.objectCompletionBlocks objectAtIndex:i];
                if (blocks.count)
                {
                    for (int j = 0; j < blocks.count; j++)
                    {
                        if ([object isKindOfClass:[PFObject class]])
                        {
                            parseObject = (PFObject *)object;
                            objectCompletionBlock = [blocks objectAtIndex:j];
                            objectCompletionBlock(parseObject);
                        }
                        else if ([object isKindOfClass:[PFFile class]])
                        {
                            parseFile = (PFFile *)object;
                            fileCompletionBlock = [blocks objectAtIndex:j];
                            fileCompletionBlock(parseFile);
                        }
                    }
                }
                [self.objectCompletionBlocks removeObject:blocks];
                [self.unsavedObjects removeObject:parseObject];
            }
            else
            {
                i++;
            }
        }
    }
    if (self.unsavedObjects.count)
    {
        [AKDebugger logMethod:METHOD_NAME logType:AKLogTypeNotice methodType:AKMethodTypeUnspecified customCategories:@[AKD_PARSE] message:[NSString stringWithFormat:@"Could not %@ %lu objects", NSStringFromSelector(@selector(save)), (unsigned long)self.unsavedObjects.count]];
    }
    [[ParseController threadSave] cancel];
    [self setThreadSave:nil];
}

+ (void)saveEventually:(id)object withCompletion:(void (^)(id))completionBlock
{
    [AKDebugger logMethod:METHOD_NAME logType:AKLogTypeMethodName methodType:AKMethodTypeUnspecified customCategories:@[AKD_PARSE] message:nil];
    
    NSMutableArray *unsavedObjects = [ParseController unsavedObjects];
    if ([unsavedObjects containsObject:object])
    {
        if (completionBlock)
        {
            [[[ParseController objectCompletionBlocks] objectAtIndex:[unsavedObjects indexOfObject:object]] addObject:completionBlock];
        }
    }
    else
    {
        [unsavedObjects addObject:object];
        NSMutableArray *blocks = [NSMutableArray array];
        if (completionBlock) [blocks addObject:completionBlock];
        [[ParseController objectCompletionBlocks] addObject:blocks];
    }
    if ([AKSystemInfo isReachable] && ![[ParseController threadSave] isExecuting])
    {
        [[ParseController threadSave] start];
    }
}

#pragma mark - // PRIVATE METHODS (Fetch) //

- (void)fetch
{
    [AKDebugger logMethod:METHOD_NAME logType:AKLogTypeMethodName methodType:AKMethodTypeUnspecified customCategories:@[AKD_PARSE] message:nil];
    
    NSDictionary *dictionary;
    PFQueryType queryType;
    PFQuery *query;
    void (^fetchAllCompletionBlock)(NSArray *);
    void (^fetchFirstCompletionBlock)(PFObject *);
    void (^countCompletionBlock)(NSUInteger);
    NSError *error;
    NSArray *foundObjects;
    PFObject *foundObject;
    NSUInteger count;
    NSUInteger i = 0;
    while (i < self.queuedQueries.count)
    {
        dictionary = [self.queuedQueries objectAtIndex:i];
        query = [dictionary objectForKey:QUEUEDQUERY_KEY_QUERY];
        if (!query)
        {
            [AKDebugger logMethod:METHOD_NAME logType:AKLogTypeWarning methodType:AKMethodTypeUnspecified customCategories:@[AKD_PARSE] message:[NSString stringWithFormat:@"%@ is nil", stringFromVariable(query)]];
            i++;
            continue;
        }
        
        queryType = (PFQueryType)[[dictionary objectForKey:QUEUEDQUERY_KEY_TYPE] integerValue];
        if (queryType == PFQueryFetchAll)
        {
            fetchAllCompletionBlock = [dictionary objectForKey:QUEUEDQUERY_KEY_COMPLETION];
            if (!fetchAllCompletionBlock)
            {
                [AKDebugger logMethod:METHOD_NAME logType:AKLogTypeWarning methodType:AKMethodTypeUnspecified customCategories:@[AKD_PARSE] message:[NSString stringWithFormat:@"%@ is nil", stringFromVariable(fetchAllCompletionBlock)]];
                i++;
                continue;
            }
            
            foundObjects = [query findObjects:&error];
            if (error)
            {
                [AKDebugger logMethod:METHOD_NAME logType:AKLogTypeError methodType:AKMethodTypeUnspecified customCategories:@[AKD_PARSE] message:[NSString stringWithFormat:@"%@, %@", error, error.userInfo]];
            }
            if (!foundObjects)
            {
                [AKDebugger logMethod:METHOD_NAME logType:AKLogTypeWarning methodType:AKMethodTypeUnspecified customCategories:@[AKD_PARSE] message:@"Could not fetch objects"];
            }
            fetchAllCompletionBlock(foundObjects);
        }
        else if (queryType == PFQueryFetchFirst)
        {
            fetchFirstCompletionBlock = [dictionary objectForKey:QUEUEDQUERY_KEY_COMPLETION];
            if (!fetchFirstCompletionBlock)
            {
                [AKDebugger logMethod:METHOD_NAME logType:AKLogTypeWarning methodType:AKMethodTypeUnspecified customCategories:@[AKD_PARSE] message:[NSString stringWithFormat:@"%@ is nil", stringFromVariable(fetchFirstCompletionBlock)]];
                i++;
                continue;
            }
            
            foundObject = [query getFirstObject:&error];
            if (error)
            {
                [AKDebugger logMethod:METHOD_NAME logType:AKLogTypeError methodType:AKMethodTypeUnspecified customCategories:@[AKD_PARSE] message:[NSString stringWithFormat:@"%@, %@", error, error.userInfo]];
            }
            fetchFirstCompletionBlock(foundObject);
        }
        else if (queryType == PFQueryCount)
        {
            countCompletionBlock = [dictionary objectForKey:QUEUEDQUERY_KEY_COMPLETION];
            if (!countCompletionBlock)
            {
                [AKDebugger logMethod:METHOD_NAME logType:AKLogTypeWarning methodType:AKMethodTypeUnspecified customCategories:@[AKD_PARSE] message:[NSString stringWithFormat:@"%@ is nil", stringFromVariable(countCompletionBlock)]];
                i++;
                continue;
            }
            
            count = [query countObjects:&error];
            if (error)
            {
                [AKDebugger logMethod:METHOD_NAME logType:AKLogTypeError methodType:AKMethodTypeUnspecified customCategories:@[AKD_PARSE] message:[NSString stringWithFormat:@"%@, %@", error, error.userInfo]];
            }
            countCompletionBlock(count);
        }
        else
        {
            [AKDebugger logMethod:METHOD_NAME logType:AKLogTypeWarning methodType:AKMethodTypeUnspecified customCategories:@[AKD_PARSE] message:[NSString stringWithFormat:@"Unknown %@", stringFromVariable(queryType)]];
            i++;
            continue;
        }
        
        [self.queuedQueries removeObject:dictionary];
    }
    if (self.queuedQueries.count)
    {
        [AKDebugger logMethod:METHOD_NAME logType:AKLogTypeNotice methodType:AKMethodTypeUnspecified customCategories:@[AKD_PARSE] message:[NSString stringWithFormat:@"Could not %@ %lu queries", NSStringFromSelector(@selector(fetch)), (unsigned long)self.queuedQueries.count]];
    }
    [[ParseController threadFetch] cancel];
    [self setThreadFetch:nil];
}

+ (void)queueQuery:(PFQuery *)query ofType:(PFQueryType)queryType withCompletion:(id)completionBlock
{
    [AKDebugger logMethod:METHOD_NAME logType:AKLogTypeMethodName methodType:AKMethodTypeUnspecified customCategories:@[AKD_PARSE] message:nil];
    
    NSNumber *queryNumber = [NSNumber numberWithInteger:queryType];
    NSDictionary *dictionary = [NSDictionary dictionaryWithObjects:@[queryNumber, query, completionBlock] forKeys:@[QUEUEDQUERY_KEY_TYPE, QUEUEDQUERY_KEY_QUERY, QUEUEDQUERY_KEY_COMPLETION]];
    [[ParseController queuedQueries] addObject:dictionary];
    if ([AKSystemInfo isReachable] && ![[ParseController threadFetch] isExecuting])
    {
        [[ParseController threadFetch] start];
    }
}

#pragma mark - // PRIVATE METHODS (Call) //

- (void)call
{
    [AKDebugger logMethod:METHOD_NAME logType:AKLogTypeMethodName methodType:AKMethodTypeUnspecified customCategories:@[AKD_PARSE] message:nil];
    
    NSDictionary *dictionary;
    NSString *functionName;
    NSDictionary *parameters;
    void (^completionblock)(id);
    NSError *error;
    NSUInteger i = 0;
    while (i < self.queuedFunctions.count)
    {
        dictionary = [self.queuedFunctions objectAtIndex:i];
        functionName = [dictionary objectForKey:QUEUEDFUNCTION_KEY_FUNCTIONNAME];
        if (!functionName)
        {
            [AKDebugger logMethod:METHOD_NAME logType:AKLogTypeWarning methodType:AKMethodTypeUnspecified customCategories:@[AKD_PARSE] message:[NSString stringWithFormat:@"%@ is nil", stringFromVariable(functionName)]];
            i++;
            continue;
        }
        
        parameters = [dictionary objectForKey:QUEUEDFUNCTION_KEY_PARAMETERS];
        completionblock = [dictionary objectForKey:QUEUEDFUNCTION_KEY_COMPLETIONBLOCK];
        
        id response = [PFCloud callFunction:functionName withParameters:parameters error:&error];
        if (error)
        {
            [AKDebugger logMethod:METHOD_NAME logType:AKLogTypeError methodType:AKMethodTypeUnspecified customCategories:@[AKD_PARSE] message:[NSString stringWithFormat:@"%@, %@", error, error.userInfo]];
        }
        if (completionblock) completionblock(response);
        [self.queuedFunctions removeObject:dictionary];
    }
    if (self.queuedFunctions.count)
    {
        [AKDebugger logMethod:METHOD_NAME logType:AKLogTypeNotice methodType:AKMethodTypeUnspecified customCategories:@[AKD_PARSE] message:[NSString stringWithFormat:@"Could not %@ %lu functions", NSStringFromSelector(@selector(call)), (unsigned long)self.queuedFunctions.count]];
    }
    [[ParseController threadCall] cancel];
    [self setThreadCall:nil];
}

@end