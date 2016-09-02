//
//  EditLabelViewController.m
//  BiP
//
//  Created by ttseng on 8/24/15.
//  Copyright (c) 2015 LLK. All rights reserved.
//

#import "EditLabelViewController.h"
#import "SVProgressHUD.h"
#import "Reachability.h"
#import "ReachabilityManager.h"
#import "NoInternetViewController.h"
#import "Constants.h"
#import "AppDelegate.h"

@interface EditLabelViewController ()

@end

@implementation EditLabelViewController{
    AppDelegate *mainDelegate;
    NSString *auth_token;
    NSString *labelURLString;
    NSURL *labelURL;
    NSString *defaultLabelName;
    
    CALayer *blueBorder;
    CALayer *redBorder;
    CALayer *greenBorder;
    CALayer *greyBorder;
    
    BOOL internetAvailable;
    BOOL deletedLabel;
    
    UIApplication* app;
}

@synthesize delegate;

- (void)viewDidLoad {
    NSLog(@"==========IN editLabelViewController==========");
    [super viewDidLoad];

    [SVProgressHUD dismiss];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleNetworkChange:) name:kReachabilityChangedNotification object:nil];
    
    defaultLabelName = @"New Branch Label";
    
    // load views
    [self.navigationController setToolbarHidden:YES];
    app = [UIApplication sharedApplication];
    app.networkActivityIndicatorVisible = NO;
    
     mainDelegate = (AppDelegate *)[[UIApplication sharedApplication]delegate];
    _labelNameTextField.delegate = self; // set delegate for textfield
    
    // load step information
    [self loadLabel];
}

#pragma mark loadLabel

-(void)loadLabel{
    auth_token = [mainDelegate.keychainItem objectForKey:(__bridge id)(kSecAttrType)];//@"LZ5js43vNnQD_Yy_cswJ";
    NSString *loadLabelURLString = [NSString stringWithFormat:[projectsBaseURL stringByAppendingFormat:@"/%@/steps/%d.json", self.projectID,self.stepPosition]];
    NSURL *loadLabelURL = [NSURL URLWithString:loadLabelURLString];
    labelURLString = [NSString stringWithFormat:[projectsBaseURL stringByAppendingFormat:@"/%@/steps/%d?auth_token=%@", self.projectID,self.stepPosition, auth_token]];
    NSLog(@"labelURLString: %@", labelURLString);
    labelURL = [NSURL URLWithString:labelURLString];
    
    // fetch label info
    NSData *labelData = [NSData dataWithContentsOfURL:loadLabelURL];
    [self performSelectorOnMainThread:@selector(fetchLabelInfo:) withObject:labelData waitUntilDone:YES];
    
    [self.labelNameTextField setText:self.labelName]; // set label name
    [self.navigationItem setTitle:@""];
    if([self.labelColor isEqualToString:blueLabelHex]){
        NSLog(@"highlight blue label");
        [self highlightColor:@"blue"];
    }else if([self.labelColor isEqualToString:redLabelHex]){
        [self highlightColor:@"red"];
    }else if([self.labelColor isEqualToString:greenLabelHex]){
        [self highlightColor:@"green"];
    }else if([self.labelColor isEqualToString:greyLabelHex]){
        [self highlightColor:@"grey"];
    }

}

// fetchLabelInfo - save the label information (name, color, and id)
-(void)fetchLabelInfo:(NSData *)responseData{
    NSError *error;
    NSDictionary *json = [NSJSONSerialization JSONObjectWithData:responseData options:kNilOptions error:&error];
    NSDictionary *data = [json objectForKey:@"data"];
    NSDictionary *label = [data objectForKey:@"step"];
    
    BOOL isRemix;
    
    for(id key in label){
        NSString *keyString = [key description];
        if([keyString rangeOfString:@"remix"].location != NSNotFound){
            isRemix = [[label objectForKey:key] integerValue];
        }
    }
    self.labelName = [label objectForKey:@"name"];
    self.stepID = [label objectForKey:@"id"];
    self.labelColor =[label objectForKey:@"label_color"];
}

// highlightColor - apply border to currently selected label color
-(void)highlightColor:(NSString*)color{
    [redBorder removeFromSuperlayer];
    [greenBorder removeFromSuperlayer];
    [greyBorder removeFromSuperlayer];
    [blueBorder removeFromSuperlayer];
    
    if([color isEqualToString:@"blue"]){
        _selectedColor = BLUE;
        blueBorder = [CALayer layer];
        blueBorder.borderColor = [UIColor blackColor].CGColor;
        blueBorder.borderWidth = 3;
        blueBorder.frame = CGRectMake(0, 0, CGRectGetWidth(self.blueButton.frame), CGRectGetHeight(self.blueButton.frame));
        [self.blueButton.layer addSublayer:blueBorder];
        self.titleBackgroundLabel.backgroundColor = BLUE;
    }else if([color isEqualToString:@"red"]){
        _selectedColor = RED;
        redBorder = [CALayer layer];
        redBorder.borderColor = [UIColor blackColor].CGColor;
        redBorder.borderWidth = 3;
        redBorder.frame = CGRectMake(0, 0, CGRectGetWidth(self.blueButton.frame), CGRectGetHeight(self.blueButton.frame));
        [self.redButton.layer addSublayer:redBorder];
        self.titleBackgroundLabel.backgroundColor = RED;
    }else if([color isEqualToString:@"green"]){
        _selectedColor = GREEN;
        greenBorder = [CALayer layer];
        greenBorder.borderColor = [UIColor blackColor].CGColor;
        greenBorder.borderWidth = 3;
        greenBorder.frame = CGRectMake(0, 0, CGRectGetWidth(self.blueButton.frame), CGRectGetHeight(self.blueButton.frame));
        [self.greenButton.layer addSublayer:greenBorder];
        self.titleBackgroundLabel.backgroundColor = GREEN;
    }else if([color isEqualToString:@"grey"]){
        _selectedColor = GREY;
        greyBorder = [CALayer layer];
        greyBorder.borderColor = [UIColor blackColor].CGColor;
        greyBorder.borderWidth = 3;
        greyBorder.frame = CGRectMake(0, 0, CGRectGetWidth(self.blueButton.frame), CGRectGetHeight(self.blueButton.frame));
        [self.greyButton.layer addSublayer:greyBorder];
        self.titleBackgroundLabel.backgroundColor = GREY;
    }
    self.labelNameTextField.backgroundColor = _selectedColor;
}

-(IBAction)tapBlue:(id)sender{
    [self highlightColor:@"blue"];
    [self saveNewLabelColor:@"blue"];
}

-(IBAction)tapRed:(id)sender{
    [self highlightColor:@"red"];
    [self saveNewLabelColor:@"red"];
}

-(IBAction)tapGreen:(id)sender{
    [self highlightColor:@"green"];
    [self saveNewLabelColor:@"green"];
}

-(IBAction)tapGrey:(id)sender{
    [self highlightColor:@"grey"];
    [self saveNewLabelColor:@"grey"];
}

#pragma mark - Edit Label
- (IBAction)editLabelName:(id)sender {
    if([[[self.editButton imageView] image] isEqual:[UIImage imageNamed:@"checkios.png"]]){
        [self.editButton setImage:[UIImage imageNamed:@"edit.png"]forState:UIControlStateNormal];
        [self.labelNameTextField resignFirstResponder];
    } else {
        //if([[[self.editButton imageView] image] isEqual:[UIImage imageNamed:@"edit.png"]]){
        [self.editButton setImage:[UIImage imageNamed:@"checkios.png"]forState:UIControlStateNormal];
        [self.labelNameTextField becomeFirstResponder];
    }
}

-(void) textFieldDidBeginEditing: (UITextField*) textField
{
    NSLog(@"began editing text field");
    textField.borderStyle=UITextBorderStyleRoundedRect;
    [self.editButton setImage:[UIImage imageNamed:@"checkios.png"] forState:UIControlStateNormal];
    self.labelNameTextField.backgroundColor = _selectedColor;
 
    if([textField.text isEqualToString:@"New Branch Label"]){
        // let the user clear the label quickly
        [textField setSelectedTextRange:[textField textRangeFromPosition:textField.beginningOfDocument toPosition:textField.endOfDocument]];
    }
}

-(void)textFieldDidEndEditing: (UITextField*) textField
{
    textField.borderStyle=UITextBorderStyleNone;
    self.labelName = textField.text;
    [self.editButton setImage:[UIImage imageNamed:@"edit.png"] forState:UIControlStateNormal];
    if([textField.text isEqualToString:@""]){
        textField.text = defaultLabelName;
        textField.textColor = LIGHTGREY;
    }else{
        //save changes
        [self saveNewLabelName: textField.text];
    }
}

-(void)saveNewLabelName:(NSString *) name{
    NSLog(@"saveNewLabelName");
    NSLog(@"stepURL: %@", labelURLString);
    NSError *error = [[NSError alloc] init];
    NSDictionary * stepDict = [[NSDictionary alloc] initWithObjectsAndKeys: name, @"name", nil];
    NSDictionary * holderDict = [[NSDictionary alloc] initWithObjectsAndKeys: stepDict, @"step", nil];
    NSData * holder = [NSJSONSerialization dataWithJSONObject:holderDict options:0 error:&error];
    
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:labelURL];
    [request setHTTPMethod:@"PUT"];
    [request setValue:@"application/json" forHTTPHeaderField:@"Accept"];
    [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    [request setHTTPBody:holder];
    [NSURLConnection connectionWithRequest:request delegate:self];
}

-(void)saveNewLabelColor:(NSString *)color{
    NSString *newColor;
    if([color isEqualToString:@"blue"]){
        newColor = blueLabelHex;
    }else if([color isEqualToString:@"red"]){
        newColor = redLabelHex;
    }else if([color isEqualToString:@"green"]){
        newColor = greenLabelHex;
    }else if([color isEqualToString:@"grey"]){
        newColor = greyLabelHex;
    }
    
    NSError *error = [[NSError alloc] init];
    NSDictionary * stepDict = [[NSDictionary alloc] initWithObjectsAndKeys: newColor, @"label_color", nil];
    NSDictionary * holderDict = [[NSDictionary alloc] initWithObjectsAndKeys: stepDict, @"step", nil];
    NSData * holder = [NSJSONSerialization dataWithJSONObject:holderDict options:0 error:&error];
    
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:labelURL];
    [request setHTTPMethod:@"PUT"];
    [request setValue:@"application/json" forHTTPHeaderField:@"Accept"];
    [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    [request setHTTPBody:holder];
    [NSURLConnection connectionWithRequest:request delegate:self];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
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

#pragma mark - MENU ITEMS

- (IBAction)showActionSheet:(id)sender {
    UIActionSheet *actionSheet = [[UIActionSheet alloc] initWithTitle:nil delegate:self cancelButtonTitle:@"Cancel" destructiveButtonTitle:@"Delete Label" otherButtonTitles: @"Logout", nil];
    [actionSheet showInView:[UIApplication sharedApplication].keyWindow];
}

- (void)actionSheet:(UIActionSheet *)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex
{
    
    if (buttonIndex == actionSheet.cancelButtonIndex) return;
    if (buttonIndex == actionSheet.destructiveButtonIndex)
    {
        NSString *deleteMessage = [NSString stringWithFormat: @"Delete Label %@?", self.labelName];
        UIAlertView *alert = [[UIAlertView alloc]initWithTitle:@"Delete Label" message: deleteMessage delegate:nil cancelButtonTitle:@"Cancel" otherButtonTitles:@"Delete", nil];
        alert.delegate = self;
        [alert show];
    }
    else {
        switch (buttonIndex) {
            case 1:
            {
                NSLog(@"Logout");
                [self logoutClick];
                break;
            }
            default:
                return;
                break;
        }
    }
}

-(void)alertView: (UIAlertView*) alertView clickedButtonAtIndex:(NSInteger)buttonIndex
{
    //NSLog(@"delete button name: %@", [alertView buttonTitleAtIndex:1]);
    switch(buttonIndex)
    {
        case 0:
            NSLog(@"delete button name: %@", [alertView buttonTitleAtIndex:0]);
            break;
        case 1:
        {
            [self deleteLabel];
            deletedLabel = YES;
            [self.navigationController popViewControllerAnimated:YES];
            break;
        }
    }
}

- (IBAction)logoutClick {
    [[Constants sharedGlobalData] logout];
    [self.navigationController popToRootViewControllerAnimated:YES];
}

// send a delete request to the server
-(void)deleteLabel{
    NSString *deleteStepURLString = [NSString stringWithFormat:[labelURLString stringByAppendingFormat:@"&step_id=%@", self.stepID]];
    NSLog(@"deleteStepURLString: %@", deleteStepURLString);
    
    NSURL * DELETE_STEP_URL = [NSURL URLWithString:deleteStepURLString];
    
    // send JSON request
    NSMutableURLRequest * request = [NSMutableURLRequest new];
    NSLog(@"deleting step at URL: %@", DELETE_STEP_URL);
    [request setURL:DELETE_STEP_URL];
    [request setHTTPMethod:@"DELETE"];
    
    // receive JSON response
    NSURLResponse * response = nil;
    NSData * receivedData = nil;
    
    NSError *error = [[NSError alloc] init];
    
    receivedData = [NSMutableData data];
    receivedData = [NSURLConnection sendSynchronousRequest:request returningResponse:&response error:&error];
}

- (void)viewWillDisappear:(BOOL)animated {
    if(deletedLabel){
        [delegate sendDataToEditProject:@"deleted"];
    }else{
        [delegate sendDataToEditProject:[self.stepID description]];
    }
}

/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/

@end
