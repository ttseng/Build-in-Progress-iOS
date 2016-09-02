//
//  RegistrationViewController.m
//  BiP
//
//  Created by ttseng on 7/2/15.
//  Copyright (c) 2015 LLK. All rights reserved.
//

#import "RegistrationViewController.h"
#import "Reachability.h"
#import "ReachabilityManager.h"
#import "NoInternetViewController.h"
#import "LoginViewController.h"
#import "Constants.h"

@implementation RegistrationViewController{
    UITextField *activeField;
    int initialScreenHeight;
}

-(void)viewDidLoad{
    [super viewDidLoad];
    if([ReachabilityManager isUnreachable]){
        NoInternetViewController *nivc = [self.storyboard instantiateViewControllerWithIdentifier:@"NoInternet"];
        [self presentViewController:nivc animated:YES completion:nil];
    }else{
        [self registerForKeyboardNotifications];
        UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc]
                                       initWithTarget:self
                                       action:@selector(dismissKeyboard)];
        
        [self.view addGestureRecognizer:tap];
        
        self.scrollView.contentSize = CGSizeMake(320, [[UIScreen mainScreen] bounds].size.height*1.5);
        [self.scrollView setScrollEnabled:NO];

    }
}

-(IBAction)registerClick:(id)sender{
    BOOL fieldsValid = NO;
    if([[_usernameField text] isEqualToString:@""] ||
       [[_emailField text] isEqualToString:@""] ||
       [[_pwField text] isEqualToString:@""] ||
       [[_confirmPWfield text] isEqualToString:@""]){
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:nil message:@"Please complete all fields" delegate:nil cancelButtonTitle:@"Back" otherButtonTitles:nil, nil];
        [alert show];
    }else if(![[_pwField text]isEqualToString:[_confirmPWfield text] ]){
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:nil message:@"Your passwords do not match. Please check again!" delegate:nil cancelButtonTitle:@"Back" otherButtonTitles:nil, nil];
        [alert show];
    }else if([[_pwField text] length] < 8){
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:nil message:@"Your password must be at least 8 characters long." delegate:nil cancelButtonTitle:@"Back" otherButtonTitles:nil, nil];
        [alert show];
    }else{
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Almost done!" message:@"Please confirm your account via email." delegate:self cancelButtonTitle:@"OK" otherButtonTitles:nil, nil];
        [alert show];
        
        dispatch_async(dispatch_get_global_queue( DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^(void){
            // register the user
            NSString *username = [_usernameField text];
            NSString *email = [_emailField text];
            NSString *password = [_pwField text];
            
            NSString *dataString = [NSString stringWithFormat: @"{\"user\": {\"username\": \"%@\", \"email\": \"%@\", \"password\": \"%@\", \"password_confirmation\": \"%@\" }}", username,email,password,password ];
            NSLog(@"dataString: %@", dataString);
            
            NSURL *registerUserURL = [NSURL URLWithString:userBaseURL];
            NSMutableURLRequest *request = [NSMutableURLRequest new];
            [request setURL:registerUserURL];
            [request setHTTPMethod:@"POST"];
            [request setHTTPBody:[dataString dataUsingEncoding:NSUTF8StringEncoding]];
            
            // setup the request headers
            [request setValue:@"application/json" forHTTPHeaderField:@"Accept"];
            [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
            
            [NSURLConnection sendSynchronousRequest:request returningResponse:nil error:nil];
            dispatch_async(dispatch_get_main_queue(), ^(void){
                //Run UI Updates
            });
        });
       
    }
}

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex{
//    NSLog(@"going back to login view controller");
    [self dismissViewControllerAnimated:YES completion:nil];
}

-(IBAction)cancel:(id)sender{
    [self performSegueWithIdentifier:@"unwindToList" sender:self];
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    if (textField == self.usernameField) {
        [self.emailField becomeFirstResponder];
    }else if(textField == self.emailField){
        [self.pwField becomeFirstResponder];
    }else if(textField == self.pwField){
        [self.confirmPWfield becomeFirstResponder];
    }else if(textField == self.confirmPWfield){
       [textField resignFirstResponder];
       [self.registrationButton sendActionsForControlEvents:UIControlEventTouchDown];
    }
    return NO;
}

// Call this method somewhere in your view controller setup code.
- (void)registerForKeyboardNotifications
{
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(keyboardWasShown:)
                                                 name:UIKeyboardDidShowNotification object:nil];
    
}

// Called when the UIKeyboardDidShowNotification is sent.
- (void)keyboardWasShown:(NSNotification*)aNotification
{
    [self.scrollView setScrollEnabled:YES];
    NSDictionary* info = [aNotification userInfo];
    CGSize kbSize = [[info objectForKey:UIKeyboardFrameBeginUserInfoKey] CGRectValue].size;
    
    UIEdgeInsets contentInsets = UIEdgeInsetsMake(0.0, 0.0, kbSize.height, 0.0);
    self.scrollView.contentInset = contentInsets;
    self.scrollView.scrollIndicatorInsets = contentInsets;
    
    CGRect bkgndRect = activeField.superview.frame;
    if (!CGRectContainsPoint(bkgndRect, activeField.frame.origin) ) {
        [self.scrollView setContentOffset:CGPointMake(0.0, activeField.frame.origin.y-kbSize.height) animated:YES];
    }
    
    bkgndRect.size.height -= (kbSize.height)/1.5;
    [self.scrollView setContentSize:CGSizeMake(bkgndRect.size.width, bkgndRect.size.height)];
}


- (void)textFieldDidBeginEditing:(UITextField *)textField
{
    activeField = textField;
}

- (void)textFieldDidEndEditing:(UITextField *)textField
{
    activeField = nil;
}

-(void)dismissKeyboard {
    [self.scrollView setScrollEnabled:NO];
    [activeField resignFirstResponder];
}


@end
