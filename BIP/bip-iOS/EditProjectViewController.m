
//
//  EditProjectViewController.m
//  bip-iOS
//
//  Created by Teresa Tai on 7/1/14.
//  Copyright (c) 2014 LLK. All rights reserved.
//

#import "EditProjectViewController.h"
#import "EditStepViewController.h"
#import "EditLabelViewController.h"
#import "EditProjectDescriptionViewController.h"
#import "Project.h"
#import "Constants.h"
#import "Reachability.h"
#import "ReachabilityManager.h"
#import "NoInternetViewController.h"
#import "SVProgressHUD.h"
#import "AppDelegate.h"
#import <WebKit/WebKit.h>
#import "CustomNavigationController.h"

#define bgQueue dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0) // for loading projects
#define imageQueue dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0) // for loading images


@interface EditProjectViewController ()<WKNavigationDelegate>

    @property ViewState viewState;
    @property (nonatomic, strong) WKWebView *webView;

@end

@implementation EditProjectViewController
{
    NSNumber * lastStepID;
    NSUInteger lastStepPos;
    int selectedStepPos;
    int selectedStepIndex;
    int editedStepID;
    BOOL isRemix;
    
    NSMutableDictionary *projectDict;
    NSString *projectTitle;
    NSString *projectDesc;
    NSArray *steps;
    NSMutableArray *stepNames;
    NSMutableArray *stepImages;
    NSMutableArray *stepIDs;
    
    CALayer *stepsBorder; // bottom border for stepsButton
    CALayer *labelsBorder; // bottom border for labelsButton
    
    BOOL reloadSteps;
    BOOL reloadEntireProject;
    
    BOOL editProjectActivityIndicator;
    
    NSURL *projectURL; // url for project
    NSURL *stepsURL; // url for step json
    NSURL *addStepURL; // url for adding a step
    NSString * auth_token;
    
    BOOL internetAvailable;
    UIApplication* app;
    
    UIActivityIndicatorView *spinner;
    
    AppDelegate *mainDelegate;
    
    NSData * stepsData;
    
    NSLayoutConstraint *height;
    NSLayoutConstraint *width;
}

//@synthesize fetchedResultsController = _fetchedResultsController;

- (void)viewDidLoad
{
    [super viewDidLoad];
     NSLog(@"======in EditProjectViewController========");
    [SVProgressHUD showWithStatus:@"Loading project..."];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleNetworkChange:) name:kReachabilityChangedNotification object:nil];
    
    // load views
    [self.navigationController setToolbarHidden:NO animated:NO];
    
    // initializations
    stepNames = [[NSMutableArray alloc]init];
    stepImages = [[NSMutableArray alloc]init];
    stepIDs = [[NSMutableArray alloc] init];
    self.projectInfo.dataSource = self;
    self.projectInfo.delegate = self;
    self.projectInfo.contentInset = UIEdgeInsetsMake(-37, 0, 0, 0);
    reloadSteps = NO;
    reloadEntireProject = NO;
    app = [UIApplication sharedApplication]; // for showing activity indicator
    editProjectActivityIndicator = false;
    self.viewState = stepView;
    self.projectInfo.editing = NO;
    self.textFieldGestureRecognizer.cancelsTouchesInView = NO;
    self.backgroundTapGestureRecognizer.cancelsTouchesInView = NO;
    stepsBorder = [CALayer layer];
    labelsBorder = [CALayer layer];
    
    //Get project info
     mainDelegate = (AppDelegate *)[[UIApplication sharedApplication]delegate];
     auth_token = [mainDelegate.keychainItem objectForKey:(__bridge id)(kSecAttrType)];

    NSString *stepURLString = [NSString stringWithFormat:[projectsBaseURL stringByAppendingFormat:@"/%@/steps.json?auth_token=%@", self.projectID, auth_token]];
    stepsURL = [NSURL URLWithString:stepURLString];
    NSString *addStepURLString = [NSString stringWithFormat:[projectsBaseURL stringByAppendingFormat:@"/%@/steps?auth_token=%@", self.projectID, auth_token]];
    addStepURL = [NSURL URLWithString:addStepURLString];
    NSString *projectURLString = [NSString stringWithFormat:[projectsBaseURL stringByAppendingFormat:@"/%@?auth_token=%@", self.projectID, auth_token]];
    projectURL = [NSURL URLWithString:projectURLString];
    
    dispatch_async(bgQueue, ^{
        [self.projectInfo setAllowsSelection:YES];
        [self.view addSubview: self.projectInfo];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            [self fetchProjectSteps]; // fetch project steps
            [self.projectInfo reloadData];
//            NSLog(@"finished loading steps - dismissing dialog");
            [SVProgressHUD dismiss];
        });
    });
    

    
}

-(void)viewWillAppear:(BOOL)animated{
//    NSLog(@"reloadSteps %d", reloadSteps);
    
    [super viewWillAppear:YES];
    
    [[UIBarButtonItem appearance] setBackButtonTitlePositionAdjustment:UIOffsetMake(0, -60)
                                                         forBarMetrics:UIBarMetricsDefault];
    if(reloadSteps == YES){
        [SVProgressHUD showWithStatus:@"Loading project..."];
        NSData * stepsData = [NSData dataWithContentsOfURL:stepsURL];
        [self fetchProjectSteps];
        [self.projectInfo reloadData];
        [self.navigationController setToolbarHidden:NO animated:YES];
        [SVProgressHUD dismiss];
       
    }
}

# pragma mark fetchProjectSteps

// get JSON data of steps
- (void)fetchProjectSteps{
    
    stepsData = [NSData dataWithContentsOfURL:stepsURL];
    
    NSLog(@"in fetchProjectSteps with editedStepID %d", editedStepID);
    
    // reinitialize table elements
    stepNames = [[NSMutableArray alloc]init];

    if(!reloadSteps || reloadEntireProject){
        stepImages = [[NSMutableArray alloc]init];
    }

    NSError * error;
    NSDictionary * json = [NSJSONSerialization
                           JSONObjectWithData:stepsData
                           options:kNilOptions
                           error:&error];
    
    NSDictionary * data = [json objectForKey:@"data"];
    NSDictionary *project = [data objectForKey:@"project"];
    steps = [data objectForKey:@"steps"];
    
    if([steps count] > 0){
        _viewModes.hidden = NO;
    }else{
        _viewModes.hidden = YES;
    }
    
    NSMutableArray * stepsMutable = [[NSMutableArray alloc] init];
    NSMutableArray * labelsMutable = [[NSMutableArray alloc] init];
    
    for (NSDictionary * object in [data objectForKey:@"steps"]) {
        if ([[object objectForKey:@"label"] isKindOfClass:[NSNull class]]) {
            [stepsMutable addObject:object];
        } else {
            [labelsMutable addObject:object];
        }
    }
    
    if (self.viewState == stepView) {
        steps = stepsMutable;
        // add border to steps button
        [self setCategory:@"steps"];
    } else {
        steps = labelsMutable;
        // add border to labels button
        [self setCategory:@"labels"];
    }
    
    NSDictionary * mostRecentStep = [steps lastObject];
    
    // because the remix key contains double quotes, need to determine whether project is remix using method below
    for(id key in project){
        NSString *keyString = [key description];
        if([keyString rangeOfString:@"remix"].location != NSNotFound) {
            isRemix = [[project objectForKey:key] integerValue];
        }
    }
    
    NSString * num = [mostRecentStep objectForKey:@"id"];
    [self setParentStep:num];
    
    projectTitle = [project objectForKey:@"title"];

    NSString *className = NSStringFromClass([[project objectForKey:@"description"] class]);

    if ([className isEqualToString:@"NSNull"])
    {
        projectDesc = @"";
    } else {
        projectDesc = [project  objectForKey:@"description"];
    }
    
    [self.titleField setText:projectTitle];
    self.titleField.text = projectTitle;
    
    __block int *loadingImages = 0;
    __block int *finishedImages = 0;
    int stepIndex = 0;
    
    //get each step
    for (NSDictionary *currentStep in steps)
    {
        NSString *stepName = [currentStep objectForKey:@"name"];
//        NSLog(@"stepName: %@", stepName);
        NSString *stepID = [currentStep objectForKey:@"id"];
        NSUInteger stepPosition = [[currentStep objectForKey:@"position"] integerValue];
        [stepIDs addObject: stepID];
        [stepNames addObject:stepName];
        
        // CONDITIONS: 1) !reloadedSteps - loading for the project for the first time, 2) reloadEntireProject - force reload of the entire project when a step has been deleted, 3) (reloadSteps && editedStepID == [stepID intValue]) - a new step has been added and we should refresh the image for that step, 4) ([stepImages count] >= selectedStepIndex && ![[stepImages objectAtIndex:selectedStepIndex] isKindOfClass:[UIImageView class]] && selectedStepIndex == stepIndex ) - a new step was added and the user pressed back before it finished uploading - when you return back, it should refresh (only works if user selects new step after image was uploaded and then returns back to view)
        
        if(!reloadSteps || reloadEntireProject || (reloadSteps && editedStepID == [stepID intValue]) || ([stepImages count] >= selectedStepIndex && ![[stepImages objectAtIndex:selectedStepIndex] isKindOfClass:[UIImageView class]] && selectedStepIndex == stepIndex ) ){

            NSArray *images = [[NSArray alloc] init];
            
            // Test if images
            if (![[currentStep objectForKey:@"label"] isKindOfClass:[NSNull class]]) {
            } else {
                images = [currentStep objectForKey:@"images"];
            }
            
            //working with the images
            if([images count]>0 || ![[currentStep objectForKey:@"label"] isKindOfClass:[NSNull class]]){
                if(app.isNetworkActivityIndicatorVisible == NO){
                    app.networkActivityIndicatorVisible = YES;
                    editProjectActivityIndicator = true;
                }
                
                // add placeholder image
                CGRect imageRect = {276,0,40,40};
                UIImageView *imageView = [[UIImageView alloc] initWithFrame:imageRect];
                [imageView setClipsToBounds:YES];
                CALayer *l = [imageView layer];
                [l setCornerRadius:5.0];
                
                if(!reloadSteps || reloadEntireProject){
                    [stepImages addObject:@""];
                }else{
                    [stepImages replaceObjectAtIndex:stepIndex withObject:imageView];
                }
                
                // load images in background
                dispatch_async(imageQueue, ^{
                    loadingImages = loadingImages + 1;
                    NSDictionary *imageInfo = [images firstObject];
                    NSDictionary *imagePath;

                    if(!isRemix){
                        imagePath = [imageInfo objectForKey:@"image_path"];
                    }else{
                        imagePath = [imageInfo objectForKey:@"remix_image_path"];
                    }
                    
                    NSString *imageUrlString = [[imagePath objectForKey: @"square_thumb"] objectForKey:@"url"];
                    UIImage *image;
                    if([imageUrlString class] != [NSNull class]){
                        NSURL *imageUrl = [NSURL URLWithString: imageUrlString];
                        NSData *imageData = [[NSData alloc] initWithContentsOfURL:(imageUrl)];
                        image = [[UIImage alloc] initWithData:(imageData)];
                    }
                    
                    if(image){
//                        NSLog(@"%@", imageUrlString);
                        dispatch_async(dispatch_get_main_queue(), ^{
//                            NSLog(@"adding thumbnail image for step %@ with stepIndex %i", stepName, stepIndex);
                            finishedImages = finishedImages + 1;
                            [imageView setImage:image]; //
                            
                            [stepImages replaceObjectAtIndex:stepIndex withObject:imageView];
                            if(!reloadSteps || reloadEntireProject){
//                                NSLog(@"reloading tableview row");
                               [self.projectInfo reloadRowsAtIndexPaths:[NSArray arrayWithObjects:[NSIndexPath indexPathForRow:stepIndex inSection:0], nil] withRowAnimation:UITableViewRowAnimationNone];
                            }

                            if(finishedImages == loadingImages || (reloadSteps && editedStepID == [stepID intValue])){
//                                NSLog(@"FINISHED LOADING IMAGES");
                                if(editProjectActivityIndicator){
                                    app.networkActivityIndicatorVisible = NO;
                                    editProjectActivityIndicator = false;
                                }

                                reloadSteps = NO;
                                reloadEntireProject = NO;
                            }
                        });
                    } else if (![[currentStep objectForKey:@"label_color"] isKindOfClass:[NSNull class]]){

                        //TODO imageview not changing color?
                        NSString * colorString = [currentStep objectForKey:@"label_color"];
                        UIColor * labelColor = [self colorWithHexString:colorString];
                        NSLog(@"label_color: %@", colorString);
                        NSLog(@"labelColor description: %@", [labelColor description]);

                        dispatch_async(dispatch_get_main_queue(), ^{
                            NSLog(@"adding label color step %@ with stepIndex %i", stepName, stepIndex);
                            finishedImages = finishedImages + 1;
                            [imageView setBackgroundColor:labelColor];
                            [stepImages replaceObjectAtIndex:stepIndex withObject:imageView];
                            [self.projectInfo reloadRowsAtIndexPaths:[NSArray arrayWithObjects:[NSIndexPath indexPathForRow:stepIndex inSection:0], nil] withRowAnimation:UITableViewRowAnimationNone];
                            if(finishedImages == loadingImages || (reloadSteps && editedStepID == [stepID intValue])){
                                if(editProjectActivityIndicator){
                                    app.networkActivityIndicatorVisible = NO;
                                    editProjectActivityIndicator = false;
                                }
                            }
                        });
                       
                    }
                });
                
            }else{
                if(!reloadSteps || reloadEntireProject){
                    [stepImages addObject:@""];
//                    NSLog(@"no images for step %@", stepName);
                }else{
                    [stepImages replaceObjectAtIndex:stepIndex withObject:@""];
//                    NSLog(@"removing image for step %@", stepName);
                }
            }
        }
        stepIndex = stepIndex+1;
    }
    id delegate = [[UIApplication sharedApplication] delegate];
    self.managedObjectContext = [delegate managedObjectContext];
}

-(UIColor*)colorWithHexString:(NSString*)hex
{
    NSString *cString = [[hex stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] uppercaseString];
    
    if ([cString characterAtIndex:0] == '#') {
        cString = [cString substringFromIndex:1];
    }
    
    // String should be 6 or 8 characters
    if ([cString length] < 6) return [UIColor grayColor];
    
    // strip 0X if it appears
    if ([cString hasPrefix:@"0X"]) cString = [cString substringFromIndex:2];
    
    if ([cString length] != 6) return  [UIColor grayColor];
    
    // Separate into r, g, b substrings
    NSRange range;
    range.location = 0;
    range.length = 2;
    NSString *rString = [cString substringWithRange:range];
    
    range.location = 2;
    NSString *gString = [cString substringWithRange:range];
    
    range.location = 4;
    NSString *bString = [cString substringWithRange:range];
    
    // Scan values
    unsigned int r, g, b;
    [[NSScanner scannerWithString:rString] scanHexInt:&r];
    [[NSScanner scannerWithString:gString] scanHexInt:&g];
    [[NSScanner scannerWithString:bString] scanHexInt:&b];
    
    return [UIColor colorWithRed:((float) r / 255.0f)
                           green:((float) g / 255.0f)
                            blue:((float) b / 255.0f)
                           alpha:1.0f];
}

// setCategory
// type = "steps" or "labels"
// selects the appropriate button (step or label) for tableview - adds bottom border to button
// changes "add new ____" button text

-(void)setCategory:(NSString*)type{
    if([type isEqualToString:@"steps"]){
        stepsBorder.borderColor = [BLUE CGColor];
        stepsBorder.borderWidth = 2;
        stepsBorder.frame = CGRectMake(-2, -2, CGRectGetWidth(self.stepsButton.frame)+10, CGRectGetHeight(self.stepsButton.frame)+2);
        [self.stepsButton.layer addSublayer:stepsBorder];
        [self.stepsButton setTitleColor:BLUE forState:UIControlStateNormal];
        [self.stepsButton setBackgroundColor:[UIColor whiteColor]];

        // set labels button grey
        [labelsBorder removeFromSuperlayer];
        [self.labelsButton setBackgroundColor:LIGHTGREY];
        [self.labelsButton setTitleColor:[UIColor grayColor] forState:UIControlStateNormal];
        
        // set button text
        [self.addButton setTitle:@"Add New Step"];
        
    }else if([type isEqualToString:@"labels"]){
        labelsBorder.borderColor = [BLUE CGColor];
        labelsBorder.borderWidth = 2;
        labelsBorder.frame = CGRectMake(-2, -2, CGRectGetWidth(self.stepsButton.frame)+10, CGRectGetHeight(self.stepsButton.frame)+2);
        [self.labelsButton.layer addSublayer:labelsBorder];
        [self.labelsButton setTitleColor:BLUE forState:UIControlStateNormal];
        [self.labelsButton setBackgroundColor:[UIColor whiteColor]];
        
        // set steps button grey
        [stepsBorder removeFromSuperlayer];
        [self.stepsButton setBackgroundColor:LIGHTGREY];
        [self.stepsButton setTitleColor:[UIColor grayColor] forState:UIControlStateNormal];
        
        // set button text
        [self.addButton setTitle:@"Add New Label"];
    }
}


#pragma mark Switch Views

- (IBAction)viewSteps:(id)sender {
    if (self.viewState == labelView) {
        NSLog(@"VIEW STEPS");
        self.viewState = stepView;
        [self fetchProjectSteps];
        [self.projectInfo reloadData];
    }
}

- (IBAction)viewLabels:(id)sender {

    if (self.viewState == stepView) {
        NSLog(@"VIEW LABELS");
        self.viewState = labelView;
        [self fetchProjectSteps];
        [self.projectInfo reloadData];
    }

}

#pragma mark addNewStep

// addNewStep
// adds a new step or a new label to the project depending on which is selected
-(IBAction)addNewStep:(UIBarButtonItem *)sender{
     NSDictionary *stepDict;
    BOOL addingStep = NO;
    
    NSLog(@"addButton title: %@", [self.addButton title]);
    
    if([[self.addButton title] isEqualToString:@"Add New Step"]){
        // create new step
        NSLog(@"creating a new step");
        [SVProgressHUD showWithStatus:@"Adding Step..."];
        stepDict = [[NSDictionary alloc] initWithObjectsAndKeys: @"New Step", @"name", lastStepID, @"parent_id", @NO, @"last", @"", @"description", nil];
        addingStep = YES;
    }else if([[self.addButton title] isEqualToString:@"Add New Label"]){
        NSLog(@"creating a new label");
        // create new label
       [SVProgressHUD showWithStatus:@"Adding Label..."];
        stepDict = [[NSDictionary alloc] initWithObjectsAndKeys: @"New Branch Label", @"name", lastStepID, @"parent_id", @NO, @"last", @"", @"description", @YES, @"label", blueLabelHex, @"label_color", nil];
    }

    NSLog(@"stepDict %@", stepDict);
    
    NSDictionary * holderDict = [[NSDictionary alloc] initWithObjectsAndKeys: stepDict, @"step", nil];
    NSError *error = [[NSError alloc] init];
    NSData * holder = [NSJSONSerialization dataWithJSONObject:holderDict options:0 error:&error];
    
    // send JSON request
    NSMutableURLRequest * request = [NSMutableURLRequest new];
    [request setURL:addStepURL];
    [request setHTTPMethod:@"POST"];
    
    // setup the request headers
    [request setValue:@"application/json" forHTTPHeaderField:@"Accept"];
    [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    [request setHTTPBody:holder];
    
    app.networkActivityIndicatorVisible = YES;
    
    NSOperationQueue *queue = [[NSOperationQueue alloc] init];
    
    [NSURLConnection sendAsynchronousRequest:request queue:queue completionHandler:^(NSURLResponse *response, NSData *data, NSError *error){
        if ([data length] > 0 && error == nil){
            NSDictionary *jsonResponse = [NSJSONSerialization
                                          JSONObjectWithData: data
                                          options:kNilOptions
                                          error:&error];
            
//            NSLog(@"jsonResponse: %@", jsonResponse);
            
            // get the position of the new step
            lastStepPos = [[jsonResponse objectForKey:@"position"] integerValue];

            // close loading animation
            [SVProgressHUD dismiss];
            
            dispatch_async(dispatch_get_main_queue(), ^{
                if(addingStep){
                    EditStepViewController *esvc = [self.storyboard instantiateViewControllerWithIdentifier:@"editStepViewController"];
                    esvc.projectID = self.projectID;
                    esvc.userID = self.userID;
                    esvc.stepPosition = lastStepPos;
                    esvc.delegate = self;
                    reloadSteps = true;
                    [self.navigationController pushViewController:esvc animated:NO];
                }else{
                    // adding label
                    EditLabelViewController *elvc = [self.storyboard instantiateViewControllerWithIdentifier:@"editLabelViewController"];
                    elvc.projectID = self.projectID;
                    elvc.userID = self.userID;
                    elvc.stepPosition = lastStepPos;
                    elvc.delegate = self;
                    reloadSteps = true;
                    [self.navigationController pushViewController:elvc animated:NO];
                }
            });
            
        }
    }];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

// sets lastStepID to the most recent step
- (void)setParentStep:(NSString *) num {
    lastStepID = [NSNumber numberWithInt:[num intValue]];
}

- (IBAction)cancelEditing:(id)sender {
    //dismiss and remove changes
}

- (IBAction)saveEditing:(id)sender {
    //dismiss and save changes
    
}

-(IBAction)unwindToList:(UIStoryboardSegue *)segue
{
    NSLog(@"return to projectCollectionViewController");
}

- (IBAction)showActionSheet:(id)sender {
    UIActionSheet *actionSheet = [[UIActionSheet alloc] initWithTitle:nil delegate:self cancelButtonTitle:@"Cancel" destructiveButtonTitle:@"Delete Project" otherButtonTitles: @"Logout", nil];
    [actionSheet showInView:[UIApplication sharedApplication].keyWindow];
}

- (IBAction)logoutClick {
    [[Constants sharedGlobalData] logout];
    [self.navigationController popToRootViewControllerAnimated:YES];
}

- (void)editProject {
    NSLog(@"editProject");
    NSDictionary *newDict = projectDict;
    [newDict setValue:projectTitle forKey:@"title"];
}

#pragma mark deleteProject

- (IBAction)deleteProjectClick {
    NSURL * DELETE_PROJECT_URL = projectURL;
    
    // send JSON request
    NSMutableURLRequest * request = [NSMutableURLRequest new];
    [request setURL:DELETE_PROJECT_URL];
    [request setHTTPMethod:@"DELETE"];
    
    // receive JSON response
    NSURLResponse * response = nil;
    NSData * receivedData = nil;
    
    NSError *error = [[NSError alloc] init];
    
    receivedData = [NSMutableData data];
    receivedData = [NSURLConnection sendSynchronousRequest:request returningResponse:&response error:&error];
    
    NSString *jsonString = [[NSString alloc] initWithData:receivedData encoding:NSUTF8StringEncoding];
    NSLog(@"response: %@",jsonString);
    
    
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
            [self deleteProjectClick];
            [self.navigationController popViewControllerAnimated:YES];
            NSLog(@"delete button name: %@", [alertView buttonTitleAtIndex:1]);
            break;
        }
    }
}

- (void)actionSheet:(UIActionSheet *)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex
{
    
    if (buttonIndex == actionSheet.cancelButtonIndex) return;
    if (buttonIndex == actionSheet.destructiveButtonIndex)
    {
        NSString *deleteMessage = [NSString stringWithFormat: @"Delete Project %@?", projectTitle];
        UIAlertView *alert = [[UIAlertView alloc]initWithTitle:@"Delete Project" message: deleteMessage delegate:nil cancelButtonTitle:@"Cancel" otherButtonTitles:@"Delete", nil];
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

 #pragma mark - Navigation
 
 // In a storyboard-based application, you will often want to do a little preparation before navigation
 - (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
 {
     if([segue.identifier isEqualToString:@"showDescriptionSegue"]){
         NSLog(@"show project description");
         EditProjectDescriptionViewController *edvc = (EditProjectDescriptionViewController*) segue.destinationViewController;
         edvc.descriptionText = projectDesc;
         edvc.projectID = self.projectID;
         reloadSteps = true;
     }else if([segue.identifier isEqualToString:@"showStepDetailSegue"]){
         EditStepViewController *esvc = (EditStepViewController *)segue.destinationViewController;
         esvc.projectID = self.projectID;
         esvc.userID = self.userID;
         esvc.delegate = self;
         esvc.stepPosition = selectedStepPos;
         reloadSteps = true;
     }else if([segue.identifier isEqualToString:@"showLabelDetailSegue"]){
         EditLabelViewController *elvc = (EditLabelViewController *)segue.destinationViewController;
         elvc.projectID = self.projectID;
         elvc.userID = self.userID;
         elvc.delegate = self;
         elvc.stepPosition = selectedStepPos;
         reloadSteps = true;
     }
 }

-(void)sendDataToEditProject:(NSString*)editedStepInfo
{
    NSLog(@"******** in sendDataToEditProject with editedStepInfo %@ **********", editedStepInfo);
    if(editedStepInfo && ![editedStepInfo isEqualToString:@"deleted"]){
        NSLog(@"updating single step");
        editedStepID = [editedStepInfo integerValue];
        selectedStepPos = nil;
    }else if([editedStepInfo isEqualToString:@"deleted"]){
        NSLog(@"deleting step / label - reload entire project");
        reloadEntireProject = true;
        editedStepID = nil;
        selectedStepPos = nil;
    }else{
        editedStepID = nil;
    }
    reloadEntireProject = true;

    
}

-(IBAction)showProjectDescription{
    [self performSegueWithIdentifier:@"showDescriptionSegue" sender:self];
}


- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    // go to selected step
    // NSLog(@"indexPath.row-1: %li", indexPath.row);
    NSDictionary *selectedStepInfo = [steps objectAtIndex:indexPath.row];
    selectedStepPos = [[selectedStepInfo objectForKey:@"position"] integerValue];
    selectedStepIndex = indexPath.row;

    app.networkActivityIndicatorVisible = YES;
    
     if([[selectedStepInfo objectForKey:@"label"] isKindOfClass:[NSNull class]]){
         // show step
        [self performSegueWithIdentifier:@"showStepDetailSegue" sender:self];
     }else{
         // show label
         [self performSegueWithIdentifier:@"showLabelDetailSegue" sender:self];
     }
    


    [tableView deselectRowAtIndexPath:indexPath animated:YES];
}

- (void)tableView:(UITableView *)tableView didDeselectRowAtIndexPath:(NSIndexPath *)indexPath
{
    
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;//[[self.fetchedResultsController sections]count];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return [steps count];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *CellIdentifier = @"Cell";
    
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    
    if (cell == nil) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"StepCell"];
    }
    // for some reason, sometimes this method gets called for cells with indexRows outside of the number of steps -> check that
    // there is a step corresponding to this row before it's created
    if(indexPath.row < stepNames.count){
        cell.userInteractionEnabled = YES;
        cell.textLabel.font = [UIFont systemFontOfSize:16.0];
        cell.textLabel.text = [stepNames objectAtIndex:indexPath.row];
        
        if( ([stepImages count] > indexPath.row) &&  ![[stepImages objectAtIndex:indexPath.row] isEqual: @""]) {
            cell.accessoryView = [stepImages objectAtIndex:indexPath.row];
        }
     
    }
    return cell;
}

-(void)insertRowsAtIndexPaths: (NSArray*)indexPaths withRowAnimation:(UITableViewRowAnimation)animation
{
    
}

#pragma mark editProjectName

- (IBAction)editProjectName:(id)sender {
    if([[[self.editProjectTitleButton imageView] image] isEqual:[UIImage imageNamed:@"checkios.png"]]){
        [self.editProjectTitleButton setImage:[UIImage imageNamed:@"edit.png"]forState:UIControlStateNormal];
        [self.titleField resignFirstResponder];
    } else {
        //if([[[self.editProjectTitleButton imageView] image] isEqual:[UIImage imageNamed:@"edit.png"]])
        [self.editProjectTitleButton setImage:[UIImage imageNamed:@"checkios.png"]forState:UIControlStateNormal];
        [self.titleField becomeFirstResponder];
    }
}


-(void) textFieldDidBeginEditing: (UITextField*) textField
{
    NSLog(@"began editing project title");
    textField.borderStyle=UITextBorderStyleRoundedRect;
    [self.editProjectTitleButton setImage:[UIImage imageNamed:@"checkios.png"] forState:UIControlStateNormal];
    // if the title contains unknown, select the whole title to make it easier for people to rename their project
    if([textField.text rangeOfString:@"Untitled"].location != NSNotFound){
        [textField setSelectedTextRange:[textField textRangeFromPosition:textField.beginningOfDocument toPosition:textField.endOfDocument]];
    }
}

-(void) textFieldDidEndEditing: (UITextField*) textField
{
    NSLog(@"textFieldDidEndEditing");
    textField.borderStyle=UITextBorderStyleNone;
    projectTitle = textField.text;
    [self.editProjectTitleButton setImage:[UIImage imageNamed:@"edit.png"] forState:UIControlStateNormal];
    // save new project title to build in progress
    [self saveNewProjectTitle:projectTitle];
  }

/* saveNewProjectTitle
 * sends new project title to BIP
 */

-(void)saveNewProjectTitle:(NSString *) title{
    NSLog(@"projectURL: %@", projectURL);
    NSString *dataString = [NSString stringWithFormat: @"{\"project\": {\"title\" : \"%@\" }}",title ];
    NSLog(@"dataString to send to BIP: %@", dataString);
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:projectURL];
    NSData *postBodyData = [NSData dataWithBytes:[dataString UTF8String] length:[dataString length]];
    [request setHTTPMethod:@"PUT"];
    [request setValue:@"application/json" forHTTPHeaderField:@"Accept"];
    [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    [request setHTTPBody:postBodyData];
    [NSURLConnection connectionWithRequest:request delegate:self];
}

// Hides keyboard when background is tapped
-(IBAction)backgroundTap:(id)sender{
    [self.view endEditing:YES];
}

// Hides keyboard when return is tapped
-(BOOL) textFieldShouldReturn:(UITextField *)textField{
    [textField resignFirstResponder];
    return NO;
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

#pragma mark viewModeClicked

-(IBAction)viewModeClicked:(id)sender{
    int clickedSegment = [sender selectedSegmentIndex];
    if(clickedSegment == 0){
        // clicked list mode

        // force into portrait orientation
        [(CustomNavigationController*)[self navigationController] setLandscapeOK:NO];
        [[UIDevice currentDevice] setValue: [NSNumber numberWithInteger: UIInterfaceOrientationPortrait] forKey:@"orientation"];
        
        self.webView.hidden = YES;
        spinner.hidden = YES;
        
        // cancel loading webView if it's loading here
        [self.webView removeObserver:self forKeyPath:@"estimatedProgress"];
        [self.webView setUIDelegate:nil];
        [self.webView setNavigationDelegate:nil];
        self.mapLoadProgressView.hidden = YES;
        
        [self.navigationController setToolbarHidden:NO animated:NO];
    }else{
        // clicked map mode
        
        spinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
        spinner.center = CGPointMake([[UIScreen mainScreen] bounds].size.width/2, [[UIScreen mainScreen] bounds].size.height/2-50);
        [spinner startAnimating];
        
        // hide add step button
        [self.navigationController setToolbarHidden:YES animated:NO];
        self.webView = [[WKWebView alloc]initWithFrame:CGRectZero];
        self.webView.navigationDelegate = self;
        
        self.mapLoadProgressView.hidden = NO;
        [self.mapLoadProgressView.layer setZPosition:2];
        [self.webView.layer setZPosition:1];
        [spinner.layer setZPosition:3];
        [self.view addSubview:self.webView];
        [self.view addSubview:spinner];

        self.webView.translatesAutoresizingMaskIntoConstraints = NO;
        
        height = [NSLayoutConstraint constraintWithItem:self.webView attribute:NSLayoutAttributeHeight relatedBy:NSLayoutRelationEqual toItem:self.view attribute:NSLayoutAttributeHeight multiplier:1 constant:0];
        
        width = [NSLayoutConstraint constraintWithItem:self.webView attribute:NSLayoutAttributeWidth relatedBy:NSLayoutRelationEqual toItem:self.view attribute:NSLayoutAttributeWidth multiplier:1 constant:0];
        
        [self.view addConstraint:height];
        [self.view addConstraint:width];
        
        [self.webView addObserver:self forKeyPath:@"estimatedProgress" options:NSKeyValueObservingOptionNew context:nil];
    
        NSString *processMapString =[NSString stringWithFormat:@"%@/steps/mobile?auth_token=%@", [projectsBaseURL stringByAppendingFormat:@"/%@", self.projectID], auth_token];
        NSLog(@"processMapString: %@", processMapString);
        NSURL *processMapURL = [NSURL URLWithString: processMapString];
        
        NSURLRequest *request = [NSURLRequest requestWithURL:processMapURL];
        [self.webView loadRequest:request];

    }
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    if ([keyPath isEqualToString:@"estimatedProgress"]) {
        self.mapLoadProgressView.hidden = self.webView.estimatedProgress == 1;
        [self.mapLoadProgressView setProgress:self.webView.estimatedProgress animated:YES];
    }
}

- (void)webView:(WKWebView *)webView didFinishNavigation:(WKNavigation *)navigation
{
    NSLog(@"website url: %@", [self.webView.URL absoluteString]);
    NSURLComponents *params = [NSURLComponents componentsWithURL:self.webView.URL resolvingAgainstBaseURL:NO];
    NSArray *queryItems = params.queryItems;
    NSLog(@"queryItems: %@", queryItems);
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"name=%@", @"tree_width"];
    NSURLQueryItem *queryItem = [[queryItems filteredArrayUsingPredicate:predicate]
                                 firstObject];
    int tree_width = [queryItem.value intValue];
    NSLog(@"tree_width: %i", tree_width);
    
    if(tree_width > 10){
        // rotate for wide projects
        NSLog(@"rotating process map");
        
        [(CustomNavigationController*)[self navigationController] setLandscapeOK:YES];
        
        [[UIDevice currentDevice] setValue: [NSNumber numberWithInteger: UIInterfaceOrientationLandscapeRight] forKey:@"orientation"];
    }

    [spinner stopAnimating];
    [self.mapLoadProgressView setProgress:0.0 animated:NO];
}

-(void)dealloc{
    @try{
       [self.webView removeObserver:self forKeyPath:@"estimatedProgress"];
    }@catch(id anException){
        //do nothing, obviously it wasn't attached because an exception was thrown
    }

    [self.webView setUIDelegate:nil];
    [self.webView setNavigationDelegate:nil];
}

-(void) viewWillDisappear:(BOOL)animated{
    NSLog(@"viewWillDisappear");
    [(CustomNavigationController*)[self navigationController] setLandscapeOK:NO];
}

@end
