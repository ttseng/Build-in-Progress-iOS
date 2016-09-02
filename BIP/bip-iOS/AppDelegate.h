//
//  AppDelegate.h
//  bip-iOS
//
//  Created by Sarah Liu on 2/25/14.
//  Copyright (c) 2014 LLK. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "KeychainItemWrapper.h"

@class KeychainItemWrapper;

@interface AppDelegate : UIResponder <UIApplicationDelegate, UINavigationControllerDelegate>

@property (readonly,strong,nonatomic) NSManagedObjectContext *managedObjectContext;
@property (readonly,strong,nonatomic) NSManagedObjectModel *managedObjectModel;
@property (readonly,strong,nonatomic) NSPersistentStoreCoordinator *persistentStoreCoordinator;

@property (strong, nonatomic) UIWindow *window;
@property (nonatomic, retain) NSString *userName;

@property (nonatomic, strong) KeychainItemWrapper *keychainItem;

- (void)saveContext;
- (NSURL *)applicationDocumentsDirectory;

@end
