//
//  LoginViewController.m
//  bip-iOS
//
//  Created by Teresa Tai on 6/5/14.
//  Copyright (c) 2014 LLK. All rights reserved.
//

#import "LoginViewController.h"
#import "Constants.h"
#import "Reachability.h"
#import "ReachabilityManager.h"
#import "NoInternetViewController.h"
#import "RegistrationViewController.h"
#import "AppDelegate.h"
#import "CustomNavigationController.h"

@interface LoginViewController ()

{
    int loginScreenHeight;
    AppDelegate *mainDelegate;
}

- (IBAction)unwindToList:(UIStoryboardSegue *)segue;

@end

@implementation LoginViewController

- (void)viewDidLoad
{
    NSLog(@"==========IN LoginViewController===========");
    
    [super viewDidLoad];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleNetworkChange:) name:kReachabilityChangedNotification object:nil];
    
    if([ReachabilityManager isUnreachable]) {
//        NSLog(@"no network connection");
        NoInternetViewController *nivc =[self.storyboard instantiateViewControllerWithIdentifier:@"NoInternet"];
        [self presentViewController:nivc animated:YES completion:nil];
    }else{
//        NSLog(@"internet connection");
        
        // set toolbar visibility
        [self.navigationController setNavigationBarHidden:YES animated:YES];
        [self.navigationController setToolbarHidden:YES];

        // initializations
        loginScreenHeight = 548;
        _username = [[NSString alloc]init];
        
        [self.scrollView setScrollEnabled:YES];
        
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(keyboardWasShown:)
                                                     name:UIKeyboardDidShowNotification object:nil];
        
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(keyboardWillBeHidden:)
                                                     name:UIKeyboardWillHideNotification object:nil];

        mainDelegate = (AppDelegate *)[[UIApplication sharedApplication]delegate];
        mainDelegate.keychainItem = [[KeychainItemWrapper alloc]initWithIdentifier:@"Login" accessGroup:nil];
        
        if(!self.invalidateKeychain){
            [self checkLoginApproved]; // should replace this with a method to check if auth_token is still valid in the future
        }else{
            [mainDelegate.keychainItem resetKeychainItem];
        }


    }
    
}


//// Called when the UIKeyboardDidShowNotification is sent.
#pragma mark keyboardWasShown
- (void)keyboardWasShown:(NSNotification*)aNotification {
    NSLog(@"keyboardWasShown with activeField %s", self.activeField == nil ? "YES": "NO");
    NSDictionary* info = [aNotification userInfo];
    CGSize kbSize = [[info objectForKey:UIKeyboardFrameBeginUserInfoKey] CGRectValue].size;
    
    UIEdgeInsets contentInsets = UIEdgeInsetsMake(0.0, 0.0, kbSize.height, 0.0);
    self.scrollView.contentInset = contentInsets;
    self.scrollView.scrollIndicatorInsets = contentInsets;
    
    CGRect bkgndRect = self.activeField.superview.frame;
    if (!CGRectContainsPoint(bkgndRect, self.activeField.frame.origin) && self.activeField) {
        NSLog(@"scrolling");
        [self.scrollView setContentOffset:CGPointMake(0.0, self.activeField.frame.origin.y-kbSize.height) animated:YES];
    }
    
    // pretty sure I shouldn't be doing this, but can't get the scrolling to work otherwise
    bkgndRect.size.height -= (kbSize.height)/1.5;
//    NSLog(@"scrollView new size: %f x %f", bkgndRect.size.width, bkgndRect.size.height);
    [self.scrollView setContentSize:CGSizeMake(bkgndRect.size.width, bkgndRect.size.height)];
}

#pragma mark keyboardWillBeHidden

// Called when the UIKeyboardWillHideNotification is sent
- (void)keyboardWillBeHidden:(NSNotification*)aNotification
{
    NSLog(@"keyboardWillBeHidden");
    
    
}

// Check if user presses next from the username textfield -> automatically go to password
- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    if (textField == self.txtPassword) {
        // try logging in
        [textField resignFirstResponder];
        [self.btnLogin sendActionsForControlEvents:UIControlEventTouchUpInside];
    } else if (textField == self.txtUsername) {
        // automatically go to the password field
        [self.txtPassword becomeFirstResponder];
    }
    return NO;
}

- (void)viewDidUnload {
    [self setTxtUsername:nil];
    [self setTxtPassword:nil];
    [self setBtnLogin:nil];
    [self.navigationController setNavigationBarHidden:YES];
    [self.navigationController setToolbarHidden:YES];
    [super viewDidUnload];
}

-(void)viewDidAppear:(BOOL)animated{
    NSLog(@"viewDidAppear of loginViewController");
    mainDelegate = (AppDelegate *)[[UIApplication sharedApplication]delegate];
    mainDelegate.keychainItem = [[KeychainItemWrapper alloc]initWithIdentifier:@"Login" accessGroup:nil];

}

-(void)viewWillAppear:(BOOL)animated{
//    NSLog(@"viewWillAppear of LoginViewController");
   [self.navigationController setNavigationBarHidden:YES];
   [self.navigationController setToolbarHidden:YES];   
}

#pragma mark authenticateUser

-(IBAction)authenticateUser {
    NSLog(@"authenticateUser");
    [mainDelegate.keychainItem resetKeychainItem]; // remove any existing auth_token
    
    NSURL *url=[NSURL URLWithString:sessionsBaseURL];
    NSError *error = nil;
    NSDictionary * userDict = [[NSDictionary alloc] initWithObjectsAndKeys: [_txtUsername text], @"username", [_txtPassword text], @"password", nil];
    NSDictionary * holderDict = [[NSDictionary alloc] initWithObjectsAndKeys: userDict, @"user", nil];
//    NSLog(@"holderDict: %@", holderDict);
    NSData * holder = [NSJSONSerialization dataWithJSONObject:holderDict options:0 error:&error];
    
    NSMutableURLRequest *request = [[NSMutableURLRequest alloc] init];
    [request setURL:url];
    [request setHTTPMethod:@"POST"];
    [request setValue:@"application/json" forHTTPHeaderField:@"Accept"];
    [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    [request setHTTPBody:holder];
    
    NSURLResponse * response = nil;
    NSData * receivedData = nil;
    
    receivedData = [NSMutableData data];
    receivedData = [NSURLConnection sendSynchronousRequest:request returningResponse:&response error:&error];
//    NSLog(@"attempting login");
    
    // get dictionary from json data
    NSDictionary * jsonResponse = [NSJSONSerialization
                                   JSONObjectWithData: receivedData
                                   options:kNilOptions
                                   error:&error];
    
    NSLog(@"jsonResponse: %@", jsonResponse);
    
    if( [[jsonResponse objectForKey:@"data"] objectForKey:@"auth_token"] ) {
        NSLog(@"saving login");
        NSDictionary * dataResponse = [jsonResponse objectForKey:@"data"];
        [mainDelegate.keychainItem setObject:[_txtUsername text] forKey:(__bridge id)(kSecAttrAccount)]; // save username
        [mainDelegate.keychainItem setObject:[dataResponse objectForKey:@"auth_token"] forKey:(__bridge id)(kSecAttrType)]; // save authentication token
        NSLog(@"set keychain information username %@ auth-token%@", [mainDelegate.keychainItem objectForKey:(__bridge id)kSecAttrAccount], [mainDelegate.keychainItem objectForKey:(__bridge id)kSecAttrType]);
    }
    
    [self checkLoginApproved];
}

- (IBAction)checkLoginApproved{

    if (([[mainDelegate.keychainItem objectForKey:(__bridge id)kSecAttrAccount]length]) >0 && ([[mainDelegate.keychainItem objectForKey:(__bridge id)kSecAttrType] length] > 0)){
        
        //[keychainItem setObject:[_txtUsername text] forKey:(__bridge id)kSecAttrAccount];
//        NSLog(@"loginApproved");
//        NSLog(@"auth_token: %@", [mainDelegate.keychainItem objectForKey:CFBridgingRelease(kSecAttrType)]);
//        NSLog(@"username: %@", [mainDelegate.keychainItem objectForKey:CFBridgingRelease(kSecAttrAccount)]);
        
        // clear the username and password from the login
        [_txtUsername setText:@""];
        [_txtPassword setText:@""];
        
        if(self.navigationController.visibleViewController == self){
                 [self performSegueWithIdentifier:@"login_success" sender:self];
        }else{
            NSLog(@"LoginViewController is not currently visible");
            ProjectsCollectionViewController *pvc = [self.storyboard instantiateViewControllerWithIdentifier:@"ProjectsCollectionViewController"];
            [self showViewController:pvc sender:self];
        }
        
    }else if( ( [_txtUsername text].length > 0 ) && ( [_txtPassword text].length > 0) ){
        // reset keychain
        [mainDelegate.keychainItem resetKeychainItem];
        
            UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Login Failed"
                                                            message:@"Invalid username or password"
                                                           delegate:nil
                                                  cancelButtonTitle:@"OK"
                                                  otherButtonTitles:nil];
            [alert show];

    }
}

- (void) prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
//    NSLog(@"in prepareForSegue");
    if([segue.identifier isEqualToString:@"login_success"]){
//        NSLog(@"login success segue");
        ProjectsCollectionViewController *pcvc = (ProjectsCollectionViewController *) segue.destinationViewController;
    }else if([segue.identifier isEqualToString:@"registration"]){
//        NSLog(@"registration");
        RegistrationViewController *rvc = (RegistrationViewController *) segue.destinationViewController;
    }
}

#pragma mark loginClik

- (IBAction)loginClick:(id)sender {
    NSLog(@"loginClick");
    @try {
        if([[_txtUsername text] isEqualToString:@""] || [[_txtPassword text] isEqualToString:@""] ) {
            
            UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Login Failed"
                                                            message:@"Please complete all fields"
                                                           delegate:nil
                                                  cancelButtonTitle:@"OK"
                                                  otherButtonTitles:nil];
            [alert show];
            
        }
        else {
            [self authenticateUser];
        }
    }
    
    @catch (NSException * e) {
        NSLog(@"Exception: %@", e);
            UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Login Failed"
                                                            message:@"Invalid username or password!"
                                                           delegate:nil
                                                  cancelButtonTitle:@"OK"
                                                  otherButtonTitles:nil];
            [alert show];
    }
}

////// "Slides" screen up when textFields are being edited
- (void)textFieldDidBeginEditing:(UITextField *)textField
{
//    NSLog(@"textFieldDidBeginEditing");
    self.activeField = textField;
}

// "Slides" screen back down when textFields are no longer being edited
- (void)textFieldDidEndEditing:(UITextField *)textField
{
//    NSLog(@"textFieldDidEndEditing - removing active field");
    self.activeField = nil;
}

// Hides keyboard when background is tapped
-(IBAction)backgroundTap:(id)sender{
//    NSLog(@"backgroundTap");
    //[activeField resignFirstResponder];
    [self.view endEditing:YES];
}


- (IBAction)unwindToList:(UIStoryboardSegue *)segue
{
//    NSLog(@"unWindTolist");
    self.activeField = nil;
    [self.scrollView setContentOffset:CGPointMake(0.0, 0.0) animated:YES];
}

- (void) handleNetworkChange:(NSNotification *)notice
{
    if([ReachabilityManager isReachable]){
        _internetAvailable = YES;
    }else{
        NoInternetViewController *nivc =[self.storyboard instantiateViewControllerWithIdentifier:@"NoInternet"];
        if(_internetAvailable == YES){
            [self presentViewController:nivc animated:YES completion:^{
            }];
        }
        _internetAvailable = NO;
    }
}


@end
