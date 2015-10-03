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
#import "PrivateInfo.h"
#import "AKSystemInfo.h"

#pragma mark - // DEFINITIONS (Private) //

#define PFINSTALLATION_KEY_PUSHNOTIFICATIONSON @"pushNotificationsOn"
#define PFINSTALLATION_KEY_CURRENTACCOUNT @"currentAccount"

#define PUSH_KEY_INSTALLATIONID @"installationId"

@interface ParseController ()
@property (nonatomic, strong) NSThread *threadSave;
@property (nonatomic, strong) NSMutableArray *unsavedObjects;
@property (nonatomic, strong) NSMutableArray *completionBlocks;
@property (nonatomic, strong) PFInstallation *currentInstallation;
@property (nonatomic, strong) PFUser *currentAccount;

// GENERAL //

+ (id)sharedController;
- (void)setup;
- (void)teardown;

// RESPONDERS //

- (void)internetStatusDidChange:(NSNotification *)notification;

// CONVENIENCE //

+ (NSThread *)threadSave;
+ (NSMutableArray *)unsavedObjects;
+ (NSMutableArray *)completionBlocks;
+ (PFInstallation *)currentInstallation;
+ (void)setCurrentAccount:(PFUser *)currentAccount;

// VALIDATORS //

+ (BOOL)validNameForPFFile:(NSString *)name;

// SAVE //

- (void)save;
+ (void)saveObjectEventually:(PFObject *)object withCompletion:(void (^)(PFObject *))completionBlock;
+ (void)saveFileEventually:(PFFile *)file withCompletion:(void (^)(PFFile *))completionBlock;

@end

@implementation ParseController

#pragma mark - // SETTERS AND GETTERS //

@synthesize threadSave = _threadSave;
@synthesize unsavedObjects = _unsavedObjects;
@synthesize completionBlocks = _completionBlocks;
@synthesize currentInstallation = _currentInstallation;
@synthesize currentAccount = _currentAccount;

- (NSThread *)threadSave
{
    [AKDebugger logMethod:METHOD_NAME logType:AKLogTypeMethodName methodType:AKMethodTypeGetter customCategories:nil message:nil];
    
    if (_threadSave) return _threadSave;
    
    _threadSave = [[NSThread alloc] initWithTarget:self selector:@selector(save) object:nil];
    [_threadSave setName:@"com.eurekavalley.Kaiten.ParseController.threadSave"];
    return _threadSave;
}

- (NSMutableArray *)unsavedObjects
{
    [AKDebugger logMethod:METHOD_NAME logType:AKLogTypeMethodName methodType:AKMethodTypeGetter customCategories:nil message:nil];
    
    if (_unsavedObjects) return _unsavedObjects;
    
    _unsavedObjects = [NSMutableArray array];
    return _unsavedObjects;
}

- (NSMutableArray *)completionBlocks
{
    [AKDebugger logMethod:METHOD_NAME logType:AKLogTypeMethodName methodType:AKMethodTypeGetter customCategories:nil message:nil];
    
    if (_completionBlocks) return _completionBlocks;
    
    _completionBlocks = [NSMutableArray array];
    return _completionBlocks;
}

- (PFInstallation *)currentInstallation
{
    [AKDebugger logMethod:METHOD_NAME logType:AKLogTypeMethodName methodType:AKMethodTypeGetter customCategories:@[AKD_PARSE] message:nil];
    
    if (_currentInstallation) return _currentInstallation;
    
    _currentInstallation = [PFInstallation currentInstallation];
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
    
    if (![AKGenerics object:currentAccount isEqualToObject:[self.currentAccount objectForKey:PFINSTALLATION_KEY_CURRENTACCOUNT]])
    {
        [self.currentInstallation setObject:currentAccount forKey:PFINSTALLATION_KEY_CURRENTACCOUNT];
        [ParseController saveObjectEventually:self.currentInstallation withCompletion:nil];
    }
    
    NSMutableDictionary *userInfo = [[NSMutableDictionary alloc] init];
    if (currentAccount) [userInfo setObject:currentAccount forKey:NOTIFICATION_OBJECT_KEY];
    [AKGenerics postNotificationName:NOTIFICATION_PARSECONTROLLER_CURRENTACCOUNT_DID_CHANGE object:nil userInfo:userInfo];
    if ([newUsername isEqualToString:oldUsername]) return;
    
    userInfo = [[NSMutableDictionary alloc] init];
    if (oldUsername) [userInfo setObject:oldUsername forKey:NOTIFICATION_OLD_KEY];
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

+ (id <AccountProtocol>)currentAccount
{
    [AKDebugger logMethod:METHOD_NAME logType:AKLogTypeMethodName methodType:AKMethodTypeGetter customCategories:@[AKD_ACCOUNTS] message:nil];
    
    return (id <AccountProtocol>)[[ParseController sharedController] currentAccount];
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
        [AKDebugger logMethod:METHOD_NAME logType:AKLogTypeError methodType:AKMethodTypeCreator customCategories:@[AKD_ACCOUNTS, AKD_PARSE] message:[NSString stringWithFormat:@"%@, %@", error, error.userInfo]];
    }
    if (!success)
    {
        [AKDebugger logMethod:METHOD_NAME logType:AKLogTypeNotice methodType:AKMethodTypeCreator customCategories:@[AKD_PARSE, AKD_ACCOUNTS] message:[NSString stringWithFormat:@"Could not create %@", stringFromVariable(account)]];
        return NO;
    }
    
    [ParseController setCurrentAccount:account];
    return YES;
}

+ (void)signOut
{
    [AKDebugger logMethod:METHOD_NAME logType:AKLogTypeMethodName methodType:AKMethodTypeAction customCategories:@[AKD_PARSE, AKD_ACCOUNTS] message:nil];
    
    [PFUser logOut];
    [ParseController setCurrentAccount:nil];
}

#pragma mark - // PUBLIC METHODS (Objects) //

+ (void)createObjectWithClass:(NSString *)className block:(void (^)(id <PFObject>))block completion:(void (^)(id <PFObject>))completionBlock
{
    [AKDebugger logMethod:METHOD_NAME logType:AKLogTypeMethodName methodType:AKMethodTypeCreator customCategories:@[AKD_PARSE] message:nil];
    
    if (!className)
    {
        [AKDebugger logMethod:METHOD_NAME logType:AKLogTypeWarning methodType:AKMethodTypeCreator customCategories:@[AKD_PARSE] message:[NSString stringWithFormat:@"%@ is nil", stringFromVariable(className)]];
        return;
    }
    
    PFObject *parseObject = [PFObject objectWithClassName:className];
    if (block) block((id <PFObject>)parseObject);
    [ParseController saveObjectEventually:parseObject withCompletion:completionBlock];
}

+ (BOOL)setObject:(id)object forKey:(NSString *)key onObject:(id <PFObject>)parseObject
{
    [AKDebugger logMethod:METHOD_NAME logType:AKLogTypeMethodName methodType:AKMethodTypeSetter customCategories:@[AKD_PARSE] message:nil];
    
    BOOL valid = YES;
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
    
    if ([AKGenerics object:object isEqualToObject:[(PFObject *)parseObject objectForKey:key]]) return YES;
    
    if (object) [(PFObject *)parseObject setObject:object forKey:key];
    else [(PFObject *)parseObject removeObjectForKey:key];
//    [ParseController saveObjectEventually:parseObject withCompletion:nil];
    return YES;
}

+ (BOOL)addObjects:(NSSet *)objects toRelationWithKey:(NSString *)key onObject:(id <PFObject>)parseObject
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
    PFRelation *relation = [(PFObject *)parseObject relationForKey:key];
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

+ (BOOL)removeObjects:(NSSet *)objects fromRelationWithKey:(NSString *)key onObject:(id <PFObject>)parseObject
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
    PFRelation *relation = [(PFObject *)parseObject relationForKey:key];
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

+ (void)createFileWithName:(NSString *)name data:(NSData *)data completionBlock:(void (^)(id <PFFile>))completionBlock
{
    [AKDebugger logMethod:METHOD_NAME logType:AKLogTypeMethodName methodType:AKMethodTypeCreator customCategories:@[AKD_PARSE] message:nil];
    
    if (!data)
    {
        [AKDebugger logMethod:METHOD_NAME logType:AKLogTypeWarning methodType:AKMethodTypeCreator customCategories:@[AKD_PARSE] message:[NSString stringWithFormat:@"%@ is nil", stringFromVariable(data)]];
        return;
    }
    
    PFFile *file;
    if (!name)
    {
        file = [PFFile fileWithData:data];
    }
    else if ([ParseController validNameForPFFile:name])
    {
        file = [PFFile fileWithName:name data:data];
    }
    if (!file)
    {
        [AKDebugger logMethod:METHOD_NAME logType:AKLogTypeWarning methodType:AKMethodTypeCreator customCategories:@[AKD_PARSE] message:[NSString stringWithFormat:@"Could not create %@", stringFromVariable(file)]];
        return;
    }
    
    [ParseController saveFileEventually:file withCompletion:completionBlock];
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
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(internetStatusDidChange:) name:NOTIFICATION_INTERNETSTATUS_DID_CHANGE object:nil];
}

- (void)teardown
{
    [AKDebugger logMethod:METHOD_NAME logType:AKLogTypeMethodName methodType:AKMethodTypeSetup customCategories:@[AKD_PARSE] message:nil];
    
    [[NSNotificationCenter defaultCenter] removeObserver:self name:NOTIFICATION_INTERNETSTATUS_DID_CHANGE object:nil];
    
    [self.threadSave cancel];
}

#pragma mark - // PRIVATE METHODS (Responders) //

- (void)internetStatusDidChange:(NSNotification *)notification
{
    [AKDebugger logMethod:METHOD_NAME logType:AKLogTypeMethodName methodType:AKMethodTypeUnspecified customCategories:@[AKD_NOTIFICATION_CENTER] message:nil];
    
    if ([AKSystemInfo isReachable] && self.unsavedObjects.count && ![[ParseController threadSave] isExecuting])
    {
        [[ParseController threadSave] start];
    }
}

#pragma mark - // PRIVATE METHODS (Convenience) //

+ (NSThread *)threadSave
{
    [AKDebugger logMethod:METHOD_NAME logType:AKLogTypeMethodName methodType:AKMethodTypeGetter customCategories:nil message:nil];
    
    return [[ParseController sharedController] threadSave];
}

+ (NSMutableArray *)unsavedObjects
{
    [AKDebugger logMethod:METHOD_NAME logType:AKLogTypeMethodName methodType:AKMethodTypeGetter customCategories:nil message:nil];
    
    return [[ParseController sharedController] unsavedObjects];
}

+ (NSMutableArray *)completionBlocks
{
    [AKDebugger logMethod:METHOD_NAME logType:AKLogTypeMethodName methodType:AKMethodTypeGetter customCategories:nil message:nil];
    
    return [[ParseController sharedController] completionBlocks];
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
    if (saved)
    {
        id parseObject;
        NSMutableArray *blocks;
        void (^objectCompletionBlock)(id <PFObject>);
        void (^fileCompletionBlock)(id <PFFile>);
        for (int i = 0; i < self.unsavedObjects.count; i++)
        {
            parseObject = [self.unsavedObjects objectAtIndex:i];
            blocks = [self.completionBlocks objectAtIndex:i];
            if (blocks.count)
            {
                for (int j = 0; j < blocks.count; j++)
                {
                    if ([parseObject isKindOfClass:[PFObject class]])
                    {
                        if ([(PFObject *)parseObject isDirty])
                        {
                            [parseObject save:&error];
                            if (error)
                            {
                                [AKDebugger logMethod:METHOD_NAME logType:AKLogTypeError methodType:AKMethodTypeUnspecified customCategories:@[AKD_PARSE] message:[NSString stringWithFormat:@"%@, %@", error, error.userInfo]];
                            }
                        }
                        objectCompletionBlock = [blocks objectAtIndex:j];
                        objectCompletionBlock((id <PFObject>)parseObject);
                    }
                    else if ([parseObject isKindOfClass:[PFFile class]])
                    {
                        fileCompletionBlock = [blocks objectAtIndex:j];
                        fileCompletionBlock((id <PFFile>)parseObject);
                    }
                }
            }
        }
        [self.completionBlocks removeAllObjects];
        [self.unsavedObjects removeAllObjects];
    }
    else
    {
        id parseObject;
        NSMutableArray *blocks;
        void (^objectCompletionBlock)(id <PFObject>);
        void (^fileCompletionBlock)(id <PFFile>);
        NSUInteger i = 0;
        while (i < self.unsavedObjects.count)
        {
            parseObject = [self.unsavedObjects objectAtIndex:i];
            saved = [parseObject save:&error];
            if (error)
            {
                [AKDebugger logMethod:METHOD_NAME logType:AKLogTypeError methodType:AKMethodTypeUnspecified customCategories:@[AKD_PARSE] message:[NSString stringWithFormat:@"%@, %@", error, error.userInfo]];
            }
            if (saved)
            {
                blocks = [self.completionBlocks objectAtIndex:i];
                if (blocks.count)
                {
                    for (int j = 0; j < blocks.count; j++)
                    {
                        if ([parseObject isKindOfClass:[PFObject class]])
                        {
                            if ([(PFObject *)parseObject isDirty])
                            {
                                [parseObject save:&error];
                                if (error)
                                {
                                    [AKDebugger logMethod:METHOD_NAME logType:AKLogTypeError methodType:AKMethodTypeUnspecified customCategories:@[AKD_PARSE] message:[NSString stringWithFormat:@"%@, %@", error, error.userInfo]];
                                }
                            }
                            objectCompletionBlock = [blocks objectAtIndex:j];
                            objectCompletionBlock((id <PFObject>)parseObject);
                        }
                        else if ([parseObject isKindOfClass:[PFFile class]])
                        {
                            fileCompletionBlock = [blocks objectAtIndex:j];
                            fileCompletionBlock((id <PFFile>)parseObject);
                        }
                    }
                }
                [self.completionBlocks removeObject:blocks];
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

+ (void)saveObjectEventually:(PFObject *)object withCompletion:(void (^)(PFObject *))completionBlock
{
    [AKDebugger logMethod:METHOD_NAME logType:AKLogTypeMethodName methodType:AKMethodTypeUnspecified customCategories:@[AKD_PARSE] message:nil];
    
    NSMutableArray *unsavedObjects = [ParseController unsavedObjects];
    if ([unsavedObjects containsObject:object])
    {
        if (completionBlock)
        {
            [[[ParseController completionBlocks] objectAtIndex:[unsavedObjects indexOfObject:object]] addObject:completionBlock];
        }
    }
    else
    {
        [unsavedObjects addObject:object];
        NSMutableArray *blocks = [NSMutableArray array];
        if (completionBlock) [blocks addObject:completionBlock];
        [[ParseController completionBlocks] addObject:blocks];
    }
    if ([AKSystemInfo isReachable] && ![[ParseController threadSave] isExecuting])
    {
        [[ParseController threadSave] start];
    }
}

+ (void)saveFileEventually:(PFFile *)file withCompletion:(void (^)(PFFile *))completionBlock
{
    [AKDebugger logMethod:METHOD_NAME logType:AKLogTypeMethodName methodType:AKMethodTypeUnspecified customCategories:@[AKD_PARSE] message:nil];
    
    NSMutableArray *unsavedObjects = [ParseController unsavedObjects];
    if ([unsavedObjects containsObject:file])
    {
        if (completionBlock)
        {
            [[[ParseController completionBlocks] objectAtIndex:[unsavedObjects indexOfObject:file]] addObject:completionBlock];
        }
    }
    else
    {
        [unsavedObjects addObject:file];
        NSMutableArray *blocks = [NSMutableArray array];
        if (completionBlock) [blocks addObject:completionBlock];
        [[ParseController completionBlocks] addObject:blocks];
    }
    if ([AKSystemInfo isReachable] && ![[ParseController threadSave] isExecuting])
    {
        [[ParseController threadSave] start];
    }
}

@end