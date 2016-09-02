//
//  LoginViewController.h
//  bip-iOS
//
//  Created by Teresa Tai on 6/5/14.
//  Copyright (c) 2014 LLK. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "ProjectsCollectionViewController.h"
#import "KeychainItemWrapper.h"

@interface LoginViewController : UIViewController <UITextFieldDelegate, UIAlertViewDelegate>
@property (unsafe_unretained, nonatomic) IBOutlet UITextField *txtUsername;
@property (unsafe_unretained, nonatomic) IBOutlet UITextField *txtPassword;
@property (unsafe_unretained, nonatomic) IBOutlet UIButton *btnLogin;

@property NSString *username;
@property NSString *password;
@property BOOL *internetAvailable;
@property BOOL *invalidateKeychain; // this is a temporary fix. for some reason, if the user has an invalid authentication token, the keychainItem doesn't get reset properly, so this BOOl gets passed from projectCollectionViewController. should fix in the future...

@property IBOutlet UIScrollView *scrollView;
@property IBOutlet UITextField *activeField;
@property (weak, nonatomic) IBOutlet UIButton *registerButton;
@property KeychainItemWrapper *keychainItem;

- (IBAction)loginClick:(id)sender;
- (IBAction)registerClick:(id)sender;


@end
