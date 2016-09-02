//
//  RegistrationViewController.h
//  BiP
//
//  Created by ttseng on 7/2/15.
//  Copyright (c) 2015 LLK. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface RegistrationViewController : UIViewController <UIAlertViewDelegate>
@property (weak, nonatomic) IBOutlet UITextField *usernameField;
@property (weak, nonatomic) IBOutlet UITextField *emailField;
@property (weak, nonatomic) IBOutlet UITextField *pwField;
@property (weak, nonatomic) IBOutlet UITextField *confirmPWfield;
@property (weak, nonatomic) IBOutlet UIButton *registrationButton;
@property (weak, nonatomic) IBOutlet UIScrollView *scrollView;

- (IBAction)registerClick:(id)sender;

@end
