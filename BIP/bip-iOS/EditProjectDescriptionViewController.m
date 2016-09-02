//
//  EditDescriptionViewController.m
//  bip-iOS
//
//  Created by Teresa Tai on 8/5/14.
//  Copyright (c) 2014 LLK. All rights reserved.
//

#import "EditProjectDescriptionViewController.h"
#import "Constants.h"
#import "Reachability.h"
#import "ReachabilityManager.h"
#import "NoInternetViewController.h"
#import "NSString+HTML.h"
#import "GTMNSString+HTML.h"
#import "AppDelegate.h"

@interface EditProjectDescriptionViewController ()

@end

@implementation EditProjectDescriptionViewController{
    NSURL *projectURL;
    NSString *auth_token;
    NSString *defaultProjectDescription;
    BOOL internetAvailable;
    AppDelegate *mainDelegate;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleNetworkChange:) name:kReachabilityChangedNotification object:nil];
    
    [self.navigationController setToolbarHidden:YES animated:NO];
    defaultProjectDescription =@"Tap here to add a description of your project!";
    
    mainDelegate = (AppDelegate *)[[UIApplication sharedApplication]delegate];
    auth_token = [mainDelegate.keychainItem objectForKey:(__bridge id)(kSecAttrType)];//@"LZ5js43vNnQD_Yy_cswJ";
    NSString *projectURLString = [NSString stringWithFormat:[projectsBaseURL stringByAppendingFormat:@"/%@?auth_token=%@", self.projectID, auth_token]];
    
    NSLog(@"projectURLString: %@", projectURLString);
    projectURL = [NSURL URLWithString:projectURLString];
    
    NSLog(@"self.descriptionText: %@", self.descriptionText);
    
    if ([self.descriptionText isEqualToString:@""]) {
        self.descriptionField.text = defaultProjectDescription;
        self.descriptionField.textColor = [UIColor lightGrayColor];
    } else {
        NSLog(@"description: %@", self.descriptionText);
        NSRange r;
        while ((r = [self.descriptionText rangeOfString:@"<[^>]+>" options:NSRegularExpressionSearch]).location != NSNotFound)
            self.descriptionText = [self.descriptionText stringByReplacingCharactersInRange:r withString:@""];
        
        // remove any character entity references
        self.descriptionText = [self.descriptionText stringByDecodingHTMLEntities];
        self.descriptionField.text = self.descriptionText;
    }
    
    // add keyboard notifiers to scroll scrollView to correct position when keyboard is visible / hidden
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(keyboardWasShown:)
                                                 name:UIKeyboardDidShowNotification object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(keyboardWillBeHidden:)
                                                 name:UIKeyboardWillHideNotification object:nil];
    
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


-(void)textViewDidBeginEditing:(UITextView *)textView{
    NSLog(@"in textViewDidBeginEditing");
    if([textView.text isEqualToString:defaultProjectDescription]){
        textView.text=@"";
        textView.textColor = [UIColor blackColor];
    }
}

-(void)textViewDidEndEditing:(UITextView *)textView{
    NSLog(@"in TextViewDidEndEditing");
    if([textView.text isEqualToString:@""]){
        textView.text= defaultProjectDescription;
        textView.textColor = [UIColor lightGrayColor];
    }
}

// Hides keyboard when background is tapped
-(IBAction)backgroundTap:(id)sender{
    NSLog(@"backgroundTap");
    //[activeField resignFirstResponder];
    [self.view endEditing:YES];
}

// detects when user clicks "done" button and saves project description
- (BOOL)textView:(UITextView *)textView shouldChangeTextInRange:(NSRange)range replacementText:(NSString *)text
{
    if([text isEqualToString:@"\n"]){
        // save the project description when the user taps "done"
        [self.view endEditing:YES];
        
        NSString *projectDescription = textView.text;
        NSLog(@"projectDescription: %@", projectDescription);
        
        [self saveNewProjectDescription: projectDescription];
    }
    
    return YES;
}

#pragma mark saveNewProjectDescription
-(void) saveNewProjectDescription:(NSString *) description{
    NSLog(@"projectURL: %@", projectURL);
    NSString *dataString = [NSString stringWithFormat:@"{\"project\": {\"description\": \"%@\" }}", description];
    NSLog(@"dataString to send to BIP: %@", dataString);
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:projectURL];
    NSData *postBodyData = [NSData dataWithBytes:[dataString UTF8String] length:[dataString length]];
    [request setHTTPMethod:@"PUT"];
    [request setValue:@"application/json" forHTTPHeaderField:@"Accept"];
    [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    [request setHTTPBody:postBodyData];    
    [NSURLConnection connectionWithRequest:request delegate:self];
    self.descriptionText = description;
}

#pragma mark keyboard

- (void)keyboardWasShown:(NSNotification*)aNotification {
    NSLog(@"keyboardWasShown");
    
    NSDictionary* info = [aNotification userInfo];
    CGSize kbSize = [[info objectForKey:UIKeyboardFrameBeginUserInfoKey] CGRectValue].size;
    
    UIEdgeInsets contentInsets = UIEdgeInsetsMake(0.0, 0.0, kbSize.height, 0.0);
    self.descriptionField.contentInset = contentInsets;
    self.descriptionField.scrollIndicatorInsets = contentInsets;
    
    CGRect aRect = self.view.frame;
    aRect.size.height -= kbSize.height;
    if (!CGRectContainsPoint(aRect, self.descriptionField.frame.origin) && [self.descriptionField.text isEqualToString:defaultProjectDescription] ) {
        NSLog(@"scrolling");
        CGPoint scrollPoint = CGPointMake(0.0, self.descriptionField.frame.origin.y-kbSize.height);
        [self.descriptionField setContentOffset:scrollPoint animated:YES];
    }
    
}

// Called when the UIKeyboardWillHideNotification is sent
- (void)keyboardWillBeHidden:(NSNotification*)aNotification
{
    UIEdgeInsets contentInsets = UIEdgeInsetsZero;
    self.descriptionField.contentInset = contentInsets;
    self.descriptionField.scrollIndicatorInsets = contentInsets;
}


- (void)viewWillDisappear:(BOOL)animated {
    NSLog(@"about to close project description view controller");
    NSLog(@"previous description: %@ ", self.descriptionText);
    NSLog(@"current description: %@ ", self.descriptionField.text);
    if(self.descriptionField.text != self.descriptionText && [self.descriptionField.text length]>0){
        NSLog(@"saving new project description" );
        // save project description
        [self saveNewProjectDescription:self.descriptionField.text];
    }
}


- (void) handleNetworkChange:(NSNotification *)notice
{
    if([ReachabilityManager isReachable]){
        internetAvailable = YES;
    }else{
        NoInternetViewController *nivc =[self.storyboard instantiateViewControllerWithIdentifier:@"NoInternet"];
        if(internetAvailable == YES){
            [self presentViewController:nivc animated:YES completion:^{
            }];
        }
        internetAvailable = NO;
    }
}



@end
