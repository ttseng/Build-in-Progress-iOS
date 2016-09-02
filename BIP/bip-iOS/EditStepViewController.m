//
//  EditStepViewController.m
//  bip-iOS
//
//  Created by Teresa Tai on 7/21/14.
//  Copyright (c) 2014 LLK. All rights reserved.
//

#import "EditStepViewController.h"
#import "EditProjectDescriptionViewController.h"
#import "MediaPreviewViewController.h"
#import "Constants.h"
#import "WSAssetPicker.h" //# for adding images
#import "Reachability.h"
#import "ReachabilityManager.h"
#import "NoInternetViewController.h"
#import "NSString+HTML.h"
#import "GTMNSString+HTML.h"
#import "SVProgressHUD.h"
#import "Multimedia.h"
#import "CameraViewController.h"
#import <AWSS3/AWSS3.h>
#import "AppDelegate.h"

#define bgQueue dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0)
static const NSUInteger BufferSize = 1024*1024;

@interface EditStepViewController () <WSAssetPickerControllerDelegate>

@property StepState stepState;

@end

@implementation EditStepViewController
{
    NSString *stepURLString;
    NSURL *stepURL;
    NSString *auth_token;
    NSMutableArray *uploadMediaIsVideo; // used to determine if uploading media should have a play icon placed over it
    NSMutableArray *stepImages; // contains UIImageView objects for images in horizontal scroller imageScroller
    
    NSMutableArray *stepMedia; // maps Multimedia objects to their UIImageView Objects in the horizontal scroller imageScroller
    NSString *stepDesc;
    int imageScrollViewHeight;
    
    NSString *defaultStepDescription;
    int defaultStepDescriptionHeight;
    int defaultPageHeight;
    
    NSDictionary *imageDimensions;
    
    NSInteger numAssets; // used for keeping track of assets uploading
    NSInteger assetCount; // counter for keeping track of assets uploading
    
    CGSize kbSize; // keyboard Size
    
    BOOL internetAvailable;
    UIApplication* app;
    
    UIImage *playIcon;
    
    int selectedImagePosition;
    BOOL updatedStepImage; // used to determine if step images were saved (to see if step images need to refreshed in EditProjectViewController)
    BOOL deletedStep; // used to determine if step images need to be fully refreshed in editProjectViewController
    
    AppDelegate *mainDelegate;
}

@synthesize stepDescriptionField;

- (void)viewDidLoad
{
    NSLog(@"======IN editStepViewController=======");
    [super viewDidLoad];
    
    [SVProgressHUD dismiss];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleNetworkChange:) name:kReachabilityChangedNotification object:nil];
    
    // load views
    [self.navigationController setToolbarHidden:YES];
    self.stepDescriptionField.allowsEditingTextAttributes = YES;
    
    // initilize
    defaultPageHeight = 550;
    self.uploadMedia = [[NSMutableArray alloc] init];
    uploadMediaIsVideo = [[NSMutableArray alloc] init];

    defaultStepDescription = @"Click here to add a step description!";

    [pageScroller setScrollEnabled:YES];
    [pageScroller setContentSize:CGSizeMake(320, defaultPageHeight)];
    [imageScroller setScrollEnabled:YES];
    imageScrollViewHeight = imageScroller.frame.size.height;
    [pageScroller addSubview:imageScroller];
    defaultStepDescriptionHeight = 210;
    app = [UIApplication sharedApplication];
    app.networkActivityIndicatorVisible = NO;
    updatedStepImage = false;
    deletedStep = false;
    
    // styling
//    self.titleBackgroundLabel.backgroundColor = DARKGREY;
//    self.stepNameField.backgroundColor = DARKGREY;
    self.stepDescriptionField.backgroundColor = LIGHTGREY;
    imageDimensions = @{@"width": [NSNumber numberWithInt:167], @"height": [NSNumber numberWithInt:125]};
    playIcon = [UIImage imageNamed:@"play_icon.png"];
    
    // add keyboard notifiers to scroll scrollView to correct position when keyboard is visible / hidden
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(keyboardWasShown:)
                                                 name:UIKeyboardDidShowNotification object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(keyboardWillBeHidden:)
                                                 name:UIKeyboardWillHideNotification object:nil];
    
     mainDelegate = (AppDelegate *)[[UIApplication sharedApplication]delegate];

    
    // load step information
    [self loadStepViews];
}

#pragma mark loadStepViews

/*
 loadStepViews - runs fetchStepInfo to get step information and then adds it to appropriate views
 */

- (void)loadStepViews{
    stepMedia = [[NSMutableArray alloc] init];
    
    //Get step info
    auth_token = [mainDelegate.keychainItem objectForKey:(__bridge id)(kSecAttrType)];//@"LZ5js43vNnQD_Yy_cswJ";
    NSString *loadStepURLString = [NSString stringWithFormat:[projectsBaseURL stringByAppendingFormat:@"/%@/steps/%d.json", self.projectID,self.stepPosition]];
    NSURL *loadStepURL = [NSURL URLWithString:loadStepURLString];
    
    stepURLString = [NSString stringWithFormat:[projectsBaseURL stringByAppendingFormat:@"/%@/steps/%d?auth_token=%@", self.projectID,self.stepPosition, auth_token]];
    stepURL = [NSURL URLWithString:stepURLString];
    
    // fetch step information
    NSData * stepData = [NSData dataWithContentsOfURL:loadStepURL];
    [self performSelectorOnMainThread:@selector(fetchStepInfo:) withObject:stepData waitUntilDone:YES];
    
    // set appropriate views
    [self.stepNameField setText:self.stepName];
    [self.navigationItem setTitle: @""];
    self.stepDescriptionField.text = stepDesc;
    CGFloat fixedWidth = self.stepDescriptionField.frame.size.width;
    CGSize newSize = [self.stepDescriptionField sizeThatFits:CGSizeMake(fixedWidth, MAXFLOAT)];
    CGRect newFrame = self.stepDescriptionField.frame;
    newFrame.size = CGSizeMake(fmaxf(newSize.width,fixedWidth), newSize.height);
    
    if(newFrame.size.height > defaultStepDescriptionHeight){
        // resize stepDescriptionField
        self.stepDescriptionField.frame = newFrame;
        
        //        NSLog(@"resize Page Scroller");
        // resize pageScroller to account for stepDescriptionHeight
        [pageScroller setContentSize:CGSizeMake(320, defaultPageHeight + (newFrame.size.height - defaultStepDescriptionHeight))];
    }
    
    if ([stepMedia count] == 0) {
        [self.imageScrollView setHidden:false];
        [self.imageScrollView setBackgroundColor:LIGHTGREY];
        [self.scrollView addSubview: self.imageScrollView];
        
    }else{
        [self.imageScrollView setHidden:false];
        [self addImagesToScrollView];
        [self.imageScrollView setBackgroundColor:LIGHTGREY];
        [self.scrollView addSubview: self.imageScrollView];
    }
    
}

/*
 fetchStepInfo - fetch the step info from corresponding json file, including name, description, and images
 */

- (void)fetchStepInfo:(NSData *)responseData {
    
    NSError * error;
    NSDictionary * json = [NSJSONSerialization
                           JSONObjectWithData:responseData
                           options:kNilOptions
                           error:&error];
    NSDictionary * data = [json objectForKey:@"data"];
    NSDictionary *step = [data objectForKey:@"step"];
    
    BOOL isRemix;
    
    for(id key in step){
        NSString *keyString = [key description];
        //NSLog(@"keystring %@", keyString);
        if([keyString rangeOfString:@"remix"].location != NSNotFound) {
            //            NSLog(@"key %@ and value %i", keyString, [[step objectForKey:key] integerValue]);
            isRemix = [[step objectForKey:key] integerValue];
        }
    }
    
//    NSLog(@"isRemix %s", isRemix ? "YES": "NO");
    
    self.stepName = [step objectForKey:@"name"];
    self.stepID = [step objectForKey:@"id"];
    NSArray *images = [step objectForKey:@"images"];
    stepDesc = [step objectForKey:@"description"];
//    NSLog(@"stepDesc: %@", stepDesc );

    if([stepDesc isKindOfClass:[NSNull class]] || [[stepDesc stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] length] == 0){
        stepDesc = defaultStepDescription;
        
    }else{
        // remove html from stepDesc
        NSRange r;
        while ((r = [stepDesc rangeOfString:@"<[^>]+>" options:NSRegularExpressionSearch]).location != NSNotFound)
            stepDesc = [stepDesc stringByReplacingCharactersInRange:r withString:@""];
        // remove character entity references
        stepDesc = [stepDesc stringByDecodingHTMLEntities];
    }
//    NSLog(@"stepDesc: %@", stepDesc);
    
    for (NSDictionary *thumbnails in images) {
        Multimedia *media = [[Multimedia alloc] init];
        BOOL isVideo = [thumbnails objectForKey: @"video"];
        NSDictionary *imagePath;
        
        if(!isRemix){
            imagePath = [thumbnails objectForKey:@"image_path"];
        }else{
            imagePath = [thumbnails objectForKey:@"remix_image_path"];

            BOOL is_image = [thumbnails objectForKey: @"remix_video_path"]== nil || [thumbnails objectForKey: @"remix_video_path"] == NULL || [[thumbnails objectForKey: @"remix_video_path"] isKindOfClass:[NSNull class]];
            
            isVideo = !is_image;
        }
        
//        NSLog(@"isVideo %d", isVideo);
        
        NSString *imageUrlString = [[imagePath objectForKey: @"preview"] objectForKey:@"url"];
        NSString *fullImageString = [imagePath objectForKey:@"url"];
        
        //        NSLog(@"%@", imageUrlString);
        int mediaID = [[thumbnails objectForKey:@"id"] integerValue];
        NSURL *imageUrl;
        if([imageUrlString class] != [NSNull class]){
            imageUrl = [NSURL URLWithString: imageUrlString];
        }

        
        if (isVideo){
            NSString *videoURLString;
            NSDictionary *vidInfo;
            
            if(!isRemix){
                vidInfo = [thumbnails objectForKey:@"video"] ;
            }else{
                vidInfo = [thumbnails objectForKey:@"remix_video_path"];
            }
            
//            NSLog(@"vidInfo %@", vidInfo);

            BOOL embeddedVideo = ([vidInfo objectForKey:@"embed_url"] && ![[vidInfo objectForKey:@"embed_url"] isKindOfClass:[NSNull class]]);
            if (embeddedVideo) {
                embeddedVideo = [[vidInfo objectForKey:@"embed_url"]length] >0;
            }
            
            //            NSLog(@"embeddedURL %@", [vidInfo objectForKey:@"embed_url"]);
            //            NSLog(@"embeddedVideo? %d", embeddedVideo);
            
            int vidRotation = 0;
            
            if(!embeddedVideo){
                if([[vidInfo objectForKey:@"rotation"] class] != [NSNull class]){
                    NSLog(@"rotation: %@", [vidInfo objectForKey:@"rotation"]);
                    vidRotation = [[vidInfo objectForKey:@"rotation"] intValue];
                }
                 NSDictionary *vidPath = [vidInfo objectForKey:@"video_path"];
                 videoURLString = [vidPath objectForKey:@"url"];
            }else{
                videoURLString = [vidInfo objectForKey:@"embed_url"];
            }
            [media createMediaWithMediaID:mediaID mediaPath:videoURLString videoRotation:vidRotation];
        } else{
            [media createMediaWithMediaID:mediaID mediaPath:imageUrlString videoRotation:0];
        }
        
        NSData *imageData = [[NSData alloc] initWithContentsOfURL:(imageUrl)];
        UIImage *image = [[UIImage alloc] initWithData:(imageData)];
        CGRect imageRect = {276,0,90,90};
        UIImageView *imageView = [[UIImageView alloc] initWithFrame:imageRect];
        imageView.image = image;

        //overlay play button
        if (isVideo){
            UIImageView *videoOverlay =[[UIImageView alloc]initWithImage:[UIImage imageNamed:@"play_icon.png"]];
            videoOverlay.contentMode = UIViewContentModeCenter;
            videoOverlay.frame = CGRectMake(37, 15, 90, 90);
            [imageView addSubview: videoOverlay];
        }
        [imageView setClipsToBounds:YES];
        [media setView:imageView];


        [media setImage:[[UIImage alloc] initWithData:[[NSData alloc] initWithContentsOfURL:[NSURL URLWithString:fullImageString]]]]; // this is the FULL image (not the preview image)
        [stepMedia addObject:media];
    }

    //NSLog(@"total number of step images %lu", (unsigned long)[stepImages count]);
}

/*
 addImagesToScrollView- adds images from step to the imageScrollView
 */
- (void) addImagesToScrollView {

    // upload images
    app.networkActivityIndicatorVisible = YES;
    
    // clear all images in scrollView
    NSLog(@"clear all images in scrollView from addImagesToScrollView");

    NSArray *viewsToRemove = [self.imageScrollView subviews];
    for(UIView *v in [self.imageScrollView subviews]){
        [v removeFromSuperview];
    }
    
    NSLog(@"in addImagesToScrollView with %ld stepImages and %ld uploadImages", (unsigned long)[stepMedia count], (unsigned long)[self.uploadMedia count]);
    NSInteger uploadedImages = stepMedia.count;
    
    // set size of scroller
    int imageScrollerWidth = ([stepMedia count] + [self.uploadMedia count]) *([imageDimensions[@"width"] integerValue] + 10);
    [imageScroller setContentSize:CGSizeMake(imageScrollerWidth, 145)];
    
    // add uploaded images
    for (int i = 0; i < [stepMedia count]; i++){
        
        UIImageView *view =  [[stepMedia objectAtIndex:i] getView];
        if ([view isKindOfClass:[UIImageView class]])
        {
            float x = i * 10;
            x += 10 + (i * [imageDimensions[@"width"] integerValue]);
            //            NSLog(@"x: %i", x);
            view.frame = CGRectMake(x, 10, [imageDimensions[@"width"] integerValue], [imageDimensions[@"height"] integerValue]);
            
            // add image to scrollview
            [self.imageScrollView addSubview:view];
            
            // add a tapGestureRecognizer to the view
            UITapGestureRecognizer *singleTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(imageTapped:)];
            singleTap.numberOfTapsRequired = 1;
            singleTap.numberOfTouchesRequired = 1;
            view.tag = i; // add the position of the image to the tag
            [view addGestureRecognizer:singleTap];
            [view setUserInteractionEnabled:true];
        }
    }
    
    // add images being uploaded
    for (int i = 0; i < [self.uploadMedia count]; i++){
        NSLog(@"on %i of uploadImages",i);
        UIImageView *view = [[self.uploadMedia objectAtIndex:i] getView];
        
        if ([view isKindOfClass:[UIImageView class]])
        {
            float offset = (uploadedImages * ( [imageDimensions[@"width"] integerValue] + 10 ));
            NSLog(@"offset: %f", offset);
            float x = i * 10;
            x += offset + 10 + (i * [imageDimensions[@"width"] integerValue]);
            //            NSLog(@"x: %i", x);
            view.frame = CGRectMake(x, 10, [imageDimensions[@"width"] integerValue], [imageDimensions[@"height"] integerValue]);
            
            NSLog(@"[uploadMediaIsVideo objectAtIndex:i]: %@", [uploadMediaIsVideo objectAtIndex:i]);
            
            if([[uploadMediaIsVideo objectAtIndex:i] boolValue]){
                NSLog(@"adding play icon to uploading asset");
                UIImageView *playOverlayImageView = [[UIImageView alloc] initWithImage:playIcon];
                
                if ([[view subviews] count] == 0){
                    [view addSubview: playOverlayImageView];
                }
                
                playOverlayImageView.center = CGPointMake(view.frame.size.width/2 , view.frame.size.height/2);
            }
            
            [self.imageScrollView addSubview:view];
        }
    }
    app.networkActivityIndicatorVisible = NO;
    NSLog(@"----------------FINISHED UPDATING SCROLLVIEW-----------------");
}


#pragma mark imageTapped
/*
 imageTapped - open up MediaPreview for selectedImage
 */
-(void)imageTapped:(UIGestureRecognizer *)gestureRecognizer{
    selectedImagePosition = gestureRecognizer.view.tag;
    UIImageView *theTappedImageView = (UIImageView *)gestureRecognizer.view;
    NSLog(@"--------------IMAGE VIEW TAPPED-----------------");
    NSLog(@"selectedImagePosition: %d", selectedImagePosition);

    // open up media preview using the tag
    UIStoryboard *storyboard = [UIStoryboard storyboardWithName:@"Main" bundle:nil];
    MediaPreviewViewController *mediaPreviewVC = (MediaPreviewViewController *)[storyboard instantiateViewControllerWithIdentifier:@"MediaPreviewViewController"];
    mediaPreviewVC.selectedMedia = [stepMedia objectAtIndex:gestureRecognizer.view.tag];
    mediaPreviewVC.customCamera = NO;
    UINavigationController *navigationController = [[UINavigationController alloc] initWithRootViewController:mediaPreviewVC];

    int indexTapped = (int) gestureRecognizer.view.tag;
    mediaPreviewVC.multimediaList = stepMedia;
    mediaPreviewVC.currentMediaIndex = indexTapped;

    mediaPreviewVC.onDismiss = ^(UIViewController *sender, BOOL *didDeleteImage){
        NSLog(@"in onDismiss in EditStepViewController with didDeleteImage %s", didDeleteImage ? "YES":"NO");
        
        if(didDeleteImage){
            
            NSLog(@"refreshing step");
            [self loadStepViews]; // refresh view to account for deleted image
            
            // should write something to update stepImages both when the number of images is now zero or if the first image has been deleted
            if([stepMedia count]==0 || selectedImagePosition == 0){
                updatedStepImage = true;
                [self addImagesToScrollView];
            }
        }
        
        // re-add notification observers
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(keyboardWasShown:)
                                                     name:UIKeyboardDidShowNotification object:nil];
        
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(keyboardWillBeHidden:)
                                                     name:UIKeyboardWillHideNotification object:nil];
        
    };
    
//    for (int i = 0; i < [stepMedia count]; i++) {
//        NSLog(@"stepMedia URL: %@ at index: %i", [[stepMedia objectAtIndex:i] getMediaPath], i);
//    }
    
    // NSLog(@"stepMedia URL: %@", [[stepMedia objectAtIndex:indexTapped] getMediaPath]);
    
    [self presentViewController:navigationController animated:YES completion:nil];
}

#pragma mark - Editing Step Name

- (IBAction)editStepName:(id)sender {
    if([[[self.editButton imageView] image] isEqual:[UIImage imageNamed:@"checkios.png"]]){
        [self.editButton setImage:[UIImage imageNamed:@"edit.png"]forState:UIControlStateNormal];
        [self.stepNameField resignFirstResponder];
    } else {
        //if([[[self.editButton imageView] image] isEqual:[UIImage imageNamed:@"edit.png"]]){
        [self.editButton setImage:[UIImage imageNamed:@"checkios.png"]forState:UIControlStateNormal];
        [self.stepNameField becomeFirstResponder];
    }
}


-(void) textFieldDidBeginEditing: (UITextField*) textField
{
    NSLog(@"textfield started editing");
    textField.borderStyle=UITextBorderStyleRoundedRect;
    [self.editButton setImage:[UIImage imageNamed:@"checkios.png"] forState:UIControlStateNormal];
    // if step name is default name, select all to let people more easily delete it
    if([textField.text isEqualToString:@"New Step"]){
        [textField setSelectedTextRange:[textField textRangeFromPosition:textField.beginningOfDocument toPosition:textField.endOfDocument]];
    }
}

-(void) textFieldDidEndEditing: (UITextField*) textField
{
    NSLog(@"text field stopped editing");
    textField.borderStyle=UITextBorderStyleNone;
    self.stepName = textField.text;
//    [self.editTitleImageView setImage:[UIImage imageNamed:@"edit.png"]];
    [self.editButton setImage:[UIImage imageNamed:@"edit.png"] forState:UIControlStateNormal];
    //save changes
    [self saveNewStepName: textField.text];
}

-(void)saveNewStepName:(NSString *) name{
    NSLog(@"stepURL: %@", stepURLString);
    NSError *error = [[NSError alloc] init];
    NSDictionary * stepDict = [[NSDictionary alloc] initWithObjectsAndKeys: name, @"name", nil];
    NSDictionary * holderDict = [[NSDictionary alloc] initWithObjectsAndKeys: stepDict, @"step", nil];
    NSData * holder = [NSJSONSerialization dataWithJSONObject:holderDict options:0 error:&error];
    
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:stepURL];
    [request setHTTPMethod:@"PUT"];
    [request setValue:@"application/json" forHTTPHeaderField:@"Accept"];
    [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    [request setHTTPBody:holder];
    [NSURLConnection connectionWithRequest:request delegate:self];
}

#pragma mark - Editing Step Description

- (BOOL)textView:(UITextView *)textView shouldChangeTextInRange:(NSRange)range replacementText:(NSString *)text{
    
    if([text isEqualToString:@"\n"]){
        NSLog(@"user clicked enter");
        // save description when user taps "done"
        [self.view endEditing:YES];
        NSString *stepDescription = textView.text;
        NSLog(@"stepDescription: %@", stepDescription);
        [self saveStepDescription: stepDescription];
    }
    
    return YES;
}

-(void)saveStepDescription:(NSString *) description{
    NSLog(@"attempting to save step description to %@", stepURLString);
    NSError *error = [[NSError alloc] init];
    NSDictionary * stepDict = [[NSDictionary alloc] initWithObjectsAndKeys: description, @"description", nil];
    NSDictionary * holderDict = [[NSDictionary alloc] initWithObjectsAndKeys: stepDict, @"step", nil];
    NSData * holder = [NSJSONSerialization dataWithJSONObject:holderDict options:0 error:&error];
    
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:stepURL];
    [request setHTTPMethod:@"PUT"];
    [request setValue:@"application/json" forHTTPHeaderField:@"Accept"];
    [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    [request setHTTPBody:holder];
    [NSURLConnection connectionWithRequest:request delegate:self];
}

- (IBAction)showActionSheet:(id)sender {
    UIActionSheet *actionSheet = [[UIActionSheet alloc] initWithTitle:nil delegate:self cancelButtonTitle:@"Cancel" destructiveButtonTitle:@"Delete Step" otherButtonTitles: @"Logout", nil];
    [actionSheet showInView:[UIApplication sharedApplication].keyWindow];
}

- (IBAction)logoutClick {
    [[Constants sharedGlobalData] logout];
    [self.navigationController popToRootViewControllerAnimated:YES];
}

#pragma mark deleteStepClick
- (IBAction)deleteStepClick {
    
    NSString *deleteStepURLString = [NSString stringWithFormat:[stepURLString stringByAppendingFormat:@"&step_id=%@", self.stepID]];
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
            [self deleteStepClick];
            updatedStepImage = true;
            deletedStep = true;
            [self.navigationController popViewControllerAnimated:YES];
            break;
        }
    }
}

- (void)actionSheet:(UIActionSheet *)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex
{
    
    if (buttonIndex == actionSheet.cancelButtonIndex) return;
    if (buttonIndex == actionSheet.destructiveButtonIndex)
    {
        NSString *deleteMessage = [NSString stringWithFormat: @"Delete Step %@?", self.stepName];
        UIAlertView *alert = [[UIAlertView alloc]initWithTitle:@"Delete Step" message: deleteMessage delegate:nil cancelButtonTitle:@"Cancel" otherButtonTitles:@"Delete", nil];
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

// Hides keyboard when background is tapped
-(IBAction)backgroundTap:(id)sender{
    //[activeField resignFirstResponder];
    [self.view endEditing:YES];
}

// Hides keyboard when return is tapped
-(BOOL) textFieldShouldReturn:(UITextField *)textField{
    [textField resignFirstResponder];
    return NO;
}


- (void)keyboardWasShown:(NSNotification*)aNotification {
    NSLog(@"keyboardWasShown");
    
    NSDictionary* info = [aNotification userInfo];
    kbSize = [[info objectForKey:UIKeyboardFrameBeginUserInfoKey] CGRectValue].size;
    
    float offset = 50.0; // this is used as an offset for ios 6 devices
    
    UIEdgeInsets contentInsets = UIEdgeInsetsMake(0.0, 0.0, kbSize.height+offset, 0.0);
    self.scrollView.contentInset = contentInsets;
    self.scrollView.scrollIndicatorInsets = contentInsets;
    
    CGRect aRect = self.view.frame;
    aRect.size.height -= kbSize.height;
    NSString *activeViewClass =NSStringFromClass(self.activeView.class);
    BOOL isUITextView = [activeViewClass isEqualToString:@"UITextView"];
    NSLog(@"activeView.class is UITextView? %@", isUITextView ? @"Yes" : @"No");
    
    // this doesn't always work for long descriptions...to debug some other time
    if (isUITextView) {
        NSLog(@"self.scrollView.contentOffset: %f", self.scrollView.contentOffset.y);
        NSLog(@"self.activeView.frame.origin.y: %f", self.activeView.frame.origin.y);
        //        float scrollPosition = self.activeView.frame.origin.y+self.scrollView.contentOffset.y-kbSize.height;
        float scrollPosition = abs(self.scrollView.contentOffset.y - (self.activeView.frame.origin.y-kbSize.height));
        NSLog(@"scrollPosition: %f", scrollPosition);
        CGPoint scrollPoint = CGPointMake(0.0, scrollPosition);
        [self.scrollView setContentOffset:scrollPoint animated:YES];
    }
    
}

// Called when the UIKeyboardWillHideNotification is sent
- (void)keyboardWillBeHidden:(NSNotification*)aNotification
{
    UIEdgeInsets contentInsets = UIEdgeInsetsZero;
    self.scrollView.contentInset = contentInsets;
    self.scrollView.scrollIndicatorInsets = contentInsets;
    
}

@synthesize delegate;

- (void)viewWillDisappear:(BOOL)animated {
    if(updatedStepImage){
        if(!deletedStep){
            NSLog(@"unwinding with editedStepInfo %@", [self.stepID description]);
            [delegate sendDataToEditProject:[self.stepID description]];
        }else{
            NSLog(@"unwinding with editedStepInfo deleted");
            [delegate sendDataToEditProject:@"deleted"];
        }
       
    }
    
    [[NSNotificationCenter defaultCenter] removeObserver:self];
//    NSLog(@"viewWillDisappear");
}

// "Slides" screen up when textFields are being edited
- (void)textViewDidBeginEditing:(UITextView *)textView
{
    NSLog(@"began editing textField");
    self.activeView = textView;
    if([textView.text isEqualToString:defaultStepDescription]){
        textView.text=@"";
        textView.textColor = [UIColor blackColor];
    }
}

// "Slides" screen back down when textFields are no longer being edited
- (void)textViewDidEndEditing:(UITextView *)textView
{
    self.activeView = nil;
    if([textView.text isEqualToString:@""]){
        textView.text=defaultStepDescription;
        textView.textColor = LIGHTGREY;
    }
}

#pragma unwind segues
- (IBAction)unwindToList:(UIStoryboardSegue *)segue
{
}

- (IBAction)unwindToStepViewController:(UIStoryboardSegue *)unwindSegue
{
    if ([unwindSegue.identifier  isEqual: @"upload"]){
        CameraViewController *camera = [unwindSegue sourceViewController];
        [self didAddMedia:camera.assets];
        [self.imageScrollView setNeedsDisplay];
    } else if ([unwindSegue.identifier  isEqual: @"done"]){
    }
}

#pragma upload to server
- (void)didAddMedia:(NSArray *)assets
{
    // check if editProjectView will need to be updated to account for newly uploaded image
    if([stepMedia count]==0){
        updatedStepImage = true;
    }
    
    // add thumbnails to the view while the assets are being uploaded
    for (ALAsset *asset in assets) {
        // add image to scrollView
        UIImage *image = [[UIImage alloc] initWithCGImage:asset.defaultRepresentation.fullScreenImage];
        CGRect imageRect = {276,0,90,90};
        UIImageView *imageView = [[UIImageView alloc] initWithFrame:imageRect];
        imageView.image = image;
        imageView.alpha = 0.5; // change transparency of uploaded image
        [imageView setClipsToBounds:YES];
        [imageView sizeToFit];
        imageView.contentMode = UIViewContentModeScaleAspectFill;
        
        if([[asset valueForProperty:ALAssetPropertyType] isEqual:ALAssetTypeVideo]){
            NSLog(@"adding video overlay");
            // add video overlay if necessary
            UIImageView *videoOverlay =[[UIImageView alloc]initWithImage:[UIImage imageNamed:@"play_icon.png"]];
            videoOverlay.contentMode = UIViewContentModeCenter;
            videoOverlay.frame = CGRectMake(37, 15, 90, 90);
            [imageView addSubview: videoOverlay];
        }
        
        Multimedia *media = [[Multimedia alloc]init];
        [media setView:imageView];
        [self.uploadMedia addObject:media]; //add to uploadImages
        if ([[asset valueForProperty:ALAssetPropertyType] isEqual:ALAssetTypeVideo]){
            NSLog(@"added a video");
            [uploadMediaIsVideo addObject:[NSNumber numberWithBool:YES]];
        }else{
            NSLog(@"added an image");
            [uploadMediaIsVideo addObject:[NSNumber numberWithBool:NO]];
        }
    }

    // reload contents
    NSLog(@"reloading addImagesToScrollView");
    [self addImagesToScrollView];

    // scroll to end of scrollView if there's 2 or more images
    if((stepMedia.count + self.uploadMedia.count)>=2 ){
        CGPoint leftOffset = CGPointMake(self.imageScrollView.contentSize.width - self.imageScrollView.bounds.size.width, 0);
        [self.imageScrollView setContentOffset:leftOffset animated:YES];
    }

    // upload images
    app.networkActivityIndicatorVisible = YES;

    numAssets = assets.count;
    assetCount = 0;

    for (ALAsset *asset in assets){
        // upload to BIP
        dispatch_async(bgQueue, ^{
            UIImage *image = [[UIImage alloc] initWithCGImage:asset.defaultRepresentation.fullScreenImage];
            if ([[asset valueForProperty:ALAssetPropertyType] isEqual:ALAssetTypeVideo]){
                [self uploadVideo:asset];
            } else {
                [self uploadImage:asset :image];
            }
            dispatch_async(dispatch_get_main_queue(), ^{
                NSLog(@"finishing uploading asset %i", assetCount);
                assetCount++;
                if(assetCount == numAssets){
                    NSLog(@"finished uploading all assets");
                }
            });
        });
    }
}

#pragma mark uploadVideo
// uploadVideo - uploads a video directly to s3 and then creates video object on BiP
-(void)uploadVideo:(ALAsset *)asset
{
    NSURL *url = asset.defaultRepresentation.url;
    NSString * surl = [url absoluteString];
    NSString * ext = [surl substringFromIndex:[surl rangeOfString:@"ext="].location + 4];
    NSTimeInterval ti = [[NSDate date]timeIntervalSinceReferenceDate];
    NSString * filename = [NSString stringWithFormat: @"%f.%@",ti,ext];
    NSString * tmpfile = [NSTemporaryDirectory() stringByAppendingPathComponent:filename];
    
    dispatch_async(bgQueue, ^{
        ALAssetsLibraryAssetForURLResultBlock resultblock = ^(ALAsset *myasset)
        {
            
            ALAssetRepresentation * rep = [myasset defaultRepresentation];
            
            NSUInteger size = [rep size];
            const int bufferSize = 8192;
            
            NSLog(@"Writing to %@",tmpfile);
            FILE* f = fopen([tmpfile cStringUsingEncoding:1], "wb+");
            if (f == NULL) {
                NSLog(@"Can not create tmp file.");
                return;
            }
            
            Byte * buffer = (Byte*)malloc(bufferSize);
            int read = 0, offset = 0, written = 0;
            NSError* err;
            if (size != 0) {
                do {
                    read = [rep getBytes:buffer
                              fromOffset:offset
                                  length:bufferSize
                                   error:&err];
                    written = fwrite(buffer, sizeof(char), read, f);
                    offset += read;
                } while (read != 0);
                
                
            }
            fclose(f);
            NSLog(@"finished saving video - uploading to AWS");
            
            AWSS3TransferManager *transferManager = [AWSS3TransferManager defaultS3TransferManager];
            AWSS3TransferManagerUploadRequest *uploadRequest = [AWSS3TransferManagerUploadRequest new];
            uploadRequest.bucket = [NSString stringWithFormat:@"%@/uploads", aws_bucket_name];
            NSLog(@"upload bucket: %@", uploadRequest.bucket);
            NSString *assetFilename = [[asset defaultRepresentation] filename];
            NSDate *now = [NSDate date];
            NSDateFormatter *dateFormat = [[NSDateFormatter alloc]init];
            [dateFormat setDateFormat:@"MM-dd-yyyy_HH-mm-ss-SS"];
            assetFilename = [[dateFormat stringFromDate:now] stringByAppendingString:assetFilename];
            //        NSLog(@"assetFilename: %@", assetFilename);
            
            uploadRequest.key = assetFilename;
            uploadRequest.body = [NSURL fileURLWithPath: tmpfile];
                
            [[transferManager upload:uploadRequest] continueWithExecutor:[AWSExecutor mainThreadExecutor]
                   withBlock:^id(AWSTask *task) {
                       if (task.error) {
                           if ([task.error.domain isEqualToString:AWSS3TransferManagerErrorDomain]) {
                               switch (task.error.code) {
                                   case AWSS3TransferManagerErrorCancelled:
                                   case AWSS3TransferManagerErrorPaused:
                                       break;
                                       
                                   default:
                                       NSLog(@"Error: %@", task.error);
                                       break;
                               }
                           } else {
                               // Unknown error.
                               NSLog(@"Error: %@", task.error);
                           }
                       }
                       
                       if (task.result) {
                           NSLog(@"successfully uploaded video to aws");
                           AWSS3TransferManagerUploadOutput *uploadOutput = task.result;
                           // The file uploaded successfully to aws!
                           NSString *s3VideoURL =[s3uploadURL stringByAppendingString:assetFilename];
                           NSLog(@"s3VideoURL: %@", s3VideoURL);
                           
                           // upload to the bip server
                           
                           NSString* FileParamConstant = @"video_path";
                           
                           // the boundary string : a random string, that will not repeat in post data, to separate post data fields.
                           NSString *BoundaryConstant = @"----------V2ymHFg03ehbqgZCaKO6jy";
                           
                           // Dictionary that holds post parameters: project_id, step_id, user_id, filename
                           NSMutableDictionary* _params = [[NSMutableDictionary alloc] init];
                           [_params setObject:[NSString stringWithFormat:@"%@", self.projectID] forKey:@"project_id"];
                           [_params setObject:[NSString stringWithFormat:@"%@", self.stepID] forKey:@"step_id"];
                           [_params setObject:[NSString stringWithFormat:@"%@", self.userID] forKey:@"user_id"];
                           [_params setObject:s3VideoURL forKey:@"s3_video_url"];
                           
                           NSMutableURLRequest *request = [[NSMutableURLRequest alloc] init];
                           [request setCachePolicy:NSURLRequestReloadIgnoringLocalCacheData];
                           [request setHTTPShouldHandleCookies:NO];
                           [request setHTTPMethod:@"POST"];
                           
                           // set Content-Type in HTTP header
                           NSString *contentType = [NSString stringWithFormat:@"multipart/form-data; boundary=%@", BoundaryConstant];
                           [request setValue:contentType forHTTPHeaderField: @"Content-Type"];
                           
                           // post body
                           NSMutableData *body = [NSMutableData data];
                           
                           // add params (all params are strings)
                           for (NSString *param in _params) {
                               [body appendData:[[NSString stringWithFormat:@"--%@\r\n", BoundaryConstant] dataUsingEncoding:NSUTF8StringEncoding]];
                               [body appendData:[[NSString stringWithFormat:@"Content-Disposition: form-data; name=\"%@\"\r\n\r\n", param] dataUsingEncoding:NSUTF8StringEncoding]];
                               [body appendData:[[NSString stringWithFormat:@"%@\r\n", [_params objectForKey:param]] dataUsingEncoding:NSUTF8StringEncoding]];
                           }
                           
                           [body appendData:[[NSString stringWithFormat:@"--%@--\r\n", BoundaryConstant] dataUsingEncoding:NSUTF8StringEncoding]];
                           
                           [request setHTTPBody:body];
                           NSString *postLength = [NSString stringWithFormat:@"%d", [body length]];
                           [request setValue:postLength forHTTPHeaderField:@"Content-Length"];
                           
                           NSString *uploadVideoURLString = [NSString stringWithFormat:[videoCreateBaseURL stringByAppendingFormat:@"/?auth_token=%@", auth_token]];
                           //                   NSLog(@"uploadVideoURLString: %@", uploadVideoURLString);
                           NSURL *uploadVideoURL = [NSURL URLWithString:uploadVideoURLString];
                           
                           [request setURL:uploadVideoURL];
                           
                           dispatch_async(bgQueue, ^{
                               NSURLResponse * response = nil;
                               NSData * receivedData = nil;
                               NSError *error = [[NSError alloc] init];
                               receivedData = [NSMutableData data];
                               receivedData = [NSURLConnection sendSynchronousRequest:request returningResponse:&response error:&error];
                               
                               NSString *jsonString = [[NSString alloc] initWithData:receivedData encoding:NSUTF8StringEncoding];
                               // jsonString format: [video.image.id, video.video_path_url, video.image.image_path_url(:preview)]
                               NSLog(@"upload video response: %@",jsonString);
                               // use this response to change transparency, add functionality so that image can be clicked
                               if([jsonString rangeOfString:@"Application Error"].location ==NSNotFound){
                                   dispatch_async(dispatch_get_main_queue(), ^{
                                       [self changeTransparency:jsonString:@"video"];
                                   });
                               }else{
                                   NSLog(@"error uploading video to heroku");
                               }
 
                           });
                           
                       }
                       return nil;
                   }];
        };
                           
        
        ALAssetsLibraryAccessFailureBlock failureblock  = ^(NSError *myerror)
        {
            NSLog(@"Can not get asset - %@",[myerror localizedDescription]);
            
        };
        if(url)
        {
            ALAssetsLibrary* assetslibrary = [[ALAssetsLibrary alloc] init];
            [assetslibrary assetForURL:url
                           resultBlock:resultblock
                          failureBlock:failureblock];
        }
    });
            

}

#pragma mark uploadImage
- (void)uploadImage:(ALAsset *)asset :(UIImage*)image{
    NSLog(@"uploading image");
    NSLog(@"trying to upload image to BIP");
    
    // string constant for the post parameter 'image_path'
    NSString* FileParamConstant = @"image_path";
    NSString *assetFilename = [[asset defaultRepresentation] filename];
    
    // the boundary string : a random string, that will not repeat in post data, to separate post data fields.
    NSString *BoundaryConstant = @"----------V2ymHFg03ehbqgZCaKO6jy";
    
    // Dictionary that holds post parameters: project_id, step_id, user_id, filename
    NSMutableDictionary* _params = [[NSMutableDictionary alloc] init];
    [_params setObject:[NSString stringWithFormat:@"%@", self.projectID] forKey:@"project_id"];
    [_params setObject:[NSString stringWithFormat:@"%@", self.stepID] forKey:@"step_id"];
    [_params setObject:[NSString stringWithFormat:@"%@", self.userID] forKey:@"user_id"];
    [_params setObject:assetFilename forKey:@"filename"];
    
    if (assetFilename){
        [_params setObject:assetFilename forKey:@"filename"];
    } else{
        NSDate *now = [NSDate date];
        NSDateFormatter *dateFormat = [[NSDateFormatter alloc]init];
        [dateFormat setDateFormat:@"MM-dd-yyyy_HH-mm-ss-SS"];
        assetFilename = [dateFormat stringFromDate:now];
    }

    
    NSMutableURLRequest *request = [[NSMutableURLRequest alloc] init];
    [request setCachePolicy:NSURLRequestReloadIgnoringLocalCacheData];
    [request setHTTPShouldHandleCookies:NO];
    [request setHTTPMethod:@"POST"];
    
    // set Content-Type in HTTP header
    NSLog(@"set content-type");
    NSString *contentType = [NSString stringWithFormat:@"multipart/form-data; boundary=%@", BoundaryConstant];
    [request setValue:contentType forHTTPHeaderField: @"Content-Type"];
    
    // post body
    NSMutableData *body = [NSMutableData data];
    
    // add params (all params are strings)
    for (NSString *param in _params) {
        [body appendData:[[NSString stringWithFormat:@"--%@\r\n", BoundaryConstant] dataUsingEncoding:NSUTF8StringEncoding]];
        [body appendData:[[NSString stringWithFormat:@"Content-Disposition: form-data; name=\"%@\"\r\n\r\n", param] dataUsingEncoding:NSUTF8StringEncoding]];
        [body appendData:[[NSString stringWithFormat:@"%@\r\n", [_params objectForKey:param]] dataUsingEncoding:NSUTF8StringEncoding]];
    }
    
    // add image data
    NSLog(@"add image");
    
    NSData *imageData = UIImageJPEGRepresentation(image, 1.0);
    if (imageData) {
        [body appendData:[[NSString stringWithFormat:@"--%@\r\n", BoundaryConstant] dataUsingEncoding:NSUTF8StringEncoding]];
        [body appendData:[[NSString stringWithFormat:@"Content-Disposition: form-data; name=\"%@\"; filename=\"image.jpg\"\r\n", FileParamConstant] dataUsingEncoding:NSUTF8StringEncoding]];
        [body appendData:[@"Content-Type: image/jpeg\r\n\r\n" dataUsingEncoding:NSUTF8StringEncoding]];
        [body appendData:imageData];
        [body appendData:[[NSString stringWithFormat:@"\r\n"] dataUsingEncoding:NSUTF8StringEncoding]];
    }
    
    [body appendData:[[NSString stringWithFormat:@"--%@--\r\n", BoundaryConstant] dataUsingEncoding:NSUTF8StringEncoding]];
    
    [request setHTTPBody:body];
    NSString *postLength = [NSString stringWithFormat:@"%d", [body length]];
    [request setValue:postLength forHTTPHeaderField:@"Content-Length"];
    
    NSString *uploadImageURLString = [NSString stringWithFormat:[imagesBaseURL stringByAppendingFormat:@"/?auth_token=%@", auth_token]];
    NSLog(@"uploadImageURLString: %@", uploadImageURLString);
    NSURL *uploadImageURL = [NSURL URLWithString:uploadImageURLString];
    
    [request setURL:uploadImageURL];
    
    NSURLResponse * response = nil;
    NSData * receivedData = nil;
    NSError *error = [[NSError alloc] init];
    
    receivedData = [NSMutableData data];
    receivedData = [NSURLConnection sendSynchronousRequest:request returningResponse:&response error:&error];
    
    NSString *jsonString = [[NSString alloc] initWithData:receivedData encoding:NSUTF8StringEncoding];
    NSLog(@"upload image jsonString: %@", jsonString);
    
    // use the jsonResponse to change the transparency of the uploaded image and enable user to tap on the image
    dispatch_async(dispatch_get_main_queue(), ^{
          [self changeTransparency:jsonString:@"image"];
    });
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


// changeTransparency: change the opacity of the uploaded image to opaque
// function called after image is finished uploading to BiP
// jsonString: the return response from the Build in Progress server after an image has been uploaded

- (void) changeTransparency: (NSString *)jsonString: (NSString *)type
{
    NSLog(@"--------changeTransparency---------");
    Multimedia *media = [[Multimedia alloc] init];

    
    //Parsing incoming json string
    NSArray *components = [jsonString componentsSeparatedByString:@","];
    NSString *ID_bracket = [components objectAtIndex:0];
    NSArray *IDComp = [ID_bracket componentsSeparatedByString:@"["];
    NSString *ID = [IDComp objectAtIndex:1];
    int ID_num = [ID intValue]; // the id of the newly uploaded asset
    
    if([type isEqualToString:@"image"]){
        //creating imagepath
        [NSString stringWithFormat:[imagesBaseURL stringByAppendingFormat:@"/?auth_token=%@", auth_token]];
        NSString *imagePath = [s3imageURL stringByAppendingFormat:@"/%d", ID_num];
        imagePath = [imagePath stringByAppendingFormat:@"/preview_image.jpg"];
        [media createMediaWithMediaID:ID_num mediaPath:imagePath videoRotation:0];
        
        //creating image view
        NSURL *imageURL = [NSURL URLWithString:imagePath];
        NSData *imageData = [[NSData alloc] initWithContentsOfURL:imageURL];
        UIImage *newImage = [[UIImage alloc] initWithData:imageData];
        CGRect imageRect = {276,0,90,90};
        UIImageView *imageView = [[UIImageView alloc] initWithFrame:imageRect];
        imageView.image = newImage;
        imageView.alpha = 1.0; // change transparency of uploaded image
        [media setView:imageView];
        [media setImage:newImage];
        [stepMedia addObject:media];
        [self.uploadMedia removeObjectAtIndex:0]; // remove translucent photo in uploadMedia
        NSLog(@"adding uploaded photo");
        [self addImagesToScrollView]; //refresh scrollviews
        
    }else if([type isEqualToString:@"video"]) {
        // get path of video
        NSString *videoPath = [[components objectAtIndex:1] stringByReplacingOccurrencesOfString:@"\"" withString:@""];
        NSLog(@"videoPath: %@", videoPath);
        [media createMediaWithMediaID:ID_num mediaPath:videoPath videoRotation:0];
        NSLog(@"media is video? %s", media.isVideo? "YES": "NO");
        NSLog(@"media pathExtension %@", [videoPath pathExtension]);
        
        // create image view
        NSString *vidThumbnailPath = [components objectAtIndex:2];
        NSArray *vidThumbnailArray = [vidThumbnailPath componentsSeparatedByString:@"]"];
        vidThumbnailPath = [[vidThumbnailArray objectAtIndex:0] stringByReplacingOccurrencesOfString:@"\"" withString:@""];
        NSLog(@"vidThumbnailPath: %@", vidThumbnailPath);
        NSURL *imageURL = [NSURL URLWithString:vidThumbnailPath];
        NSData *imageData = [[NSData alloc] initWithContentsOfURL:imageURL];
        UIImage *newImage = [[UIImage alloc] initWithData:imageData];
        CGRect imageRect = {276,0,90,90};
        UIImageView *imageView = [[UIImageView alloc] initWithFrame:imageRect];
        imageView.image = newImage;
        imageView.alpha = 1.0; // change transparency of uploaded image
        // add overlay to video
        UIImageView *videoOverlay =[[UIImageView alloc]initWithImage:[UIImage imageNamed:@"play_icon.png"]];
        videoOverlay.contentMode = UIViewContentModeCenter;
        videoOverlay.frame = CGRectMake(37, 15, 90, 90);
        [imageView addSubview: videoOverlay];
        [media setView:imageView];
        [media setImage:newImage];
        [stepMedia addObject:media];
        [self.uploadMedia removeObjectAtIndex:0];
        NSLog(@"adding uploaded video");
        [self addImagesToScrollView];
    }
    
   }

@end
