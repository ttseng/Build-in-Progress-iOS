//
//  ProjectsCollectionViewController.m
//  bip-iOS
//
//  Created by Teresa Tai on 6/9/14.
//  Copyright (c) 2014 LLK. All rights reserved.
//

#import "ProjectsCollectionViewController.h"
#import "Project.h"
#import "CustomLabel.h"
#import "Constants.h"
#import "NoInternetViewController.h"
#import "ReachabilityManager.h"
#import "Reachability.h"
#import "SVProgressHUD.h"
#import "LoginViewController.h"
#import "AppDelegate.h"
#import "CustomNavigationController.h"

#define bgQueue dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0) // for loading projects
#define imageQueue dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0) // for loading images
#define IOS_NEWER_OR_EQUAL_TO_7 ( [ [ [ UIDevice currentDevice ] systemVersion ] floatValue ] >= 7.0 )

@interface ProjectsCollectionViewController ()

{
    AppDelegate *mainDelegate;
}

@end

@implementation ProjectsCollectionViewController
@synthesize fetchedResultsController = _fetchedResultsController;


- (void)viewDidLoad
{
    NSLog(@"=======IN ProjectsCollectionViewController=======");
    [super viewDidLoad];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleNetworkChange:) name:kReachabilityChangedNotification object:nil];
    
    if([ReachabilityManager isReachable]){
        mainDelegate = (AppDelegate *)[[UIApplication sharedApplication]delegate];
        mainDelegate.keychainItem = [[KeychainItemWrapper alloc]initWithIdentifier:@"Login" accessGroup:nil];
        _username = [mainDelegate.keychainItem objectForKey:(__bridge id)kSecAttrAccount];
        _auth_token = [mainDelegate.keychainItem objectForKey:(__bridge id)(kSecAttrType)];
//        NSLog(@"auth_token: %@", _auth_token);
        
        // load views
        [self.navigationController setToolbarHidden:NO animated:NO];
        [self.navigationController setNavigationBarHidden:NO animated:NO];
        self.navigationItem.hidesBackButton = YES;
        _screenWidth = [[UIScreen mainScreen] bounds].size.width;
        _screenHeight = [[UIScreen mainScreen] bounds].size.height;
        _cellWidth = _screenWidth/2 - 10; // width of collectionView cell
        _cellHeight = _screenWidth/2 - 70; // height of collectionView cell
        
        // initializations
        _userProjects = [[NSMutableArray alloc]init];
        _reloadProjects = NO;
        _collectionGrey = [UIColor colorWithRed:247/255.0 green:247/255.0 blue:247/255.0 alpha:1.0];
        self.view.backgroundColor = _collectionGrey;
        
        NSString *urlString = [userBaseURL stringByAppendingFormat:@"%@.json?auth_token=%@", _username, _auth_token];
        _userUrl = [NSURL URLWithString:urlString];
        
        self.layout=[[UICollectionViewFlowLayout alloc] init];
        self.collectionView = [[UICollectionView alloc] initWithFrame:self.view.frame collectionViewLayout :_layout];
        [self.collectionView registerClass:[UICollectionViewCell class] forCellWithReuseIdentifier:@"NewCell"];
        self.collectionView.delegate = self;
        self.collectionView.dataSource = self;
        self.collectionView.backgroundColor = [UIColor colorWithWhite:100 alpha:100];
        
        // load project data asynchronously
        dispatch_async(bgQueue, ^{
            [self loadProjects];
        });

    }else{
        NoInternetViewController *nivc =[self.storyboard instantiateViewControllerWithIdentifier:@"NoInternet"];
        [self presentViewController:nivc animated:YES completion:nil];
    }
}

#pragma mark loadProjects
/*
 * loadProjects - set spinner and run fetchProjects
 */

-(void)loadProjects{
//    NSLog(@"in loadProjects with userURL %@", [_userUrl absoluteString]);

    // hide collection view
    [self.collectionView setHidden:YES];

    // show loading animation
    UIView *loadingAnimation = loadingCircle;
    loadingAnimation.center = CGPointMake(_screenWidth/2, _screenHeight/2-50);
    loadingAnimation.tag = 15;
    [self.view addSubview:loadingAnimation];
    [loadingCircle startAnimating];
    
    // refresh project containers
    _projectContainers = [[NSMutableArray alloc]init]; // re-initialize projectContainers
    _userProjects = [[NSMutableArray alloc]init]; //test;
    
    NSData * projectData = [NSData dataWithContentsOfURL:_userUrl];
    if(projectData){
        dispatch_async(dispatch_get_main_queue(), ^{
            [self fetchProjects:projectData];
            
//            NSLog(@"finished with loading %lu projects", (unsigned long)_projectContainers.count);
            [loadingAnimation removeFromSuperview];
            [self.collectionView setHidden:NO];
            [self.collectionView reloadData];
            _reloadProjects = NO;
            
            if(_projectContainers.count == 0){
                UIAlertView * alert =[[UIAlertView alloc ] initWithTitle:@"Welcome to APP NAME!"
                                                                 message:@"Click Add New Project to create your first project"
                                                                delegate:self
                                                       cancelButtonTitle:@"Add New Project"
                                                       otherButtonTitles:nil];
                
                [alert show];
            }
        });
        
    }else{
        NSLog(@"invalid authentication token");
        [mainDelegate.keychainItem resetKeychainItem];
        [self dismissViewControllerAnimated:YES completion:nil];
        
        UIStoryboard *storyboard = [UIStoryboard storyboardWithName:@"Main" bundle:nil];
        LoginViewController *lvc = [storyboard instantiateViewControllerWithIdentifier:@"LoginViewController"];
        lvc.invalidateKeychain = YES;
        [self presentViewController:lvc animated:NO completion:nil];
    }
    
}

/*
 * fetchProjects - get project information from bip json
 */

// get JSON data of projects
- (void)fetchProjects:(NSData *)responseData {
    NSError * error;
    NSDictionary * json = [NSJSONSerialization
                           JSONObjectWithData:responseData
                           options:kNilOptions
                           error:&error]; // get dictionary from json data
    if(json){
        NSDictionary * data = [json objectForKey:@"data"]; // get data in array
        NSArray * projects = [data objectForKey:@"projects"];
        NSDictionary *userInfo = [data objectForKey:@"user"];
        NSString *userID = [userInfo objectForKey:@"id"];
        self.userID = userID;
        
        for (NSDictionary *currentProject in projects)
        {
            // add project info
            Project *userProject = [[Project alloc] init];
            
            userProject.title = [[currentProject objectForKey:@"title"] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
//          NSLog(@"userProject.title: %@", userProject.title);
            userProject.projectID = [currentProject objectForKey:@"id"];
            userProject.built = [[currentProject objectForKey:@"built"]boolValue];
            // add to userProjects array
            [_userProjects addObject: userProject];
            
            id delegate = [[UIApplication sharedApplication] delegate];
            self.managedObjectContext = [delegate managedObjectContext];
            
            // project title label
            CustomLabel *titleLabel = [[CustomLabel alloc]init]; // this is the actual label of the collectionView cell
            titleLabel.text = userProject.title;
            CGSize maxLabelSize = CGSizeMake(_cellWidth,100);
            titleLabel.backgroundColor = [[UIColor blackColor]colorWithAlphaComponent:0.5f];
            titleLabel.textColor =[UIColor whiteColor];
            [titleLabel setFont: [UIFont fontWithName: @"HelveticaNeue" size:12]];
            CGSize expectedLabelSize = [titleLabel.text sizeWithFont:titleLabel.font constrainedToSize:maxLabelSize lineBreakMode:NSLineBreakByWordWrapping];
//            NSLog(@"expectedLabelSize: %f x %f", expectedLabelSize.width, expectedLabelSize.height);
            CGRect labelFrame = (CGRectMake(0, 0, _cellWidth, 0));
            labelFrame.origin.x = 0;
            labelFrame.origin.y = _screenWidth/2 - 80 - expectedLabelSize.height;
            labelFrame.size.height = expectedLabelSize.height+10;
            titleLabel.frame = labelFrame;
            
            // add placeholder image with textlabel
            UIImageView *imagePreview = [[UIImageView alloc] initWithFrame:CGRectMake(0, 0, _cellWidth, _cellHeight)];
            imagePreview.contentMode= UIViewContentModeScaleAspectFill;
            imagePreview.clipsToBounds = YES;
            [imagePreview setImage:[UIImage imageNamed:@"blank.png"]];
            [imagePreview addSubview:titleLabel];
            [imagePreview.subviews[0] setClipsToBounds:YES];
            [_projectContainers addObject: imagePreview];
            
            // add project thumbnail images in async
            dispatch_async(imageQueue, ^{
                NSDictionary *imagePath = [currentProject objectForKey:@"image_path"];
                NSString *imageUrlString = [imagePath objectForKey: @"preview"];
                NSURL *imageUrl = [NSURL URLWithString: imageUrlString];
                NSData *imageData = [[NSData alloc] initWithContentsOfURL:(imageUrl)];
                UIImage *image = [[UIImage alloc] initWithData:(imageData)];
                userProject.projectImage = image;
                
                if(image){
                    dispatch_async(dispatch_get_main_queue(), ^{
                        //                    NSLog(@"project with image: %@", projectTitle);
                        
                        [imagePreview setImage: image];
                        if(userProject.built){
                            UIImageView *builtBanner =[[UIImageView alloc]initWithImage:[UIImage imageNamed:@"built_icon.png"]];
                            builtBanner.frame = CGRectMake(_screenWidth/2 -60, 0, 50, 50);
                            [imagePreview addSubview: builtBanner];
                        }
                    });
                }
            });
            
        }
    }
    
}

/*
 * viewWillAppear is called when the view is about to load
 * determine whether we're returning to this view from the editprojectviewcontroller
 */
-(void)viewWillAppear:(BOOL)animated{
    [super viewWillAppear:YES];
    if(_reloadProjects == YES){
        NSLog(@"reloading projects");
        [self loadProjects];
    }
}

#pragma mark refreshPage

-(IBAction)refreshPage:(id)sender {
    NSLog(@"clicked refreshPage");
    [self loadProjects];
}

-(NSInteger)numberOfSectionsInCollectionView:(UICollectionView *)collectionView {
    return 1;
}

- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section {
    return _projectContainers.count;
}

-(CGSize)text:(NSString*)text sizeWithFont:(UIFont*)font constrainedToSize:(CGSize)size{
    if(IOS_NEWER_OR_EQUAL_TO_7){
        NSDictionary *attributesDictionary = [NSDictionary dictionaryWithObjectsAndKeys:
                                              font, NSFontAttributeName,
                                              nil];
        
        CGRect frame = [text boundingRectWithSize:size
                                          options:(NSStringDrawingUsesLineFragmentOrigin | NSStringDrawingUsesFontLeading)
                                       attributes:attributesDictionary
                                          context:nil];
        
        return frame.size;
    }else{
        return [text sizeWithFont:font constrainedToSize:size];
    }
}

#pragma mark cellForItemAtIndexPath

-(UICollectionViewCell*)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath
{
    //    NSLog(@"cellForItemAtIndexPath");
    static NSString *identifier = @"NewCell";
    UICollectionViewCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier:identifier forIndexPath:indexPath];
    if(!_reloadProjects){
        Project *cellProject = [_userProjects objectAtIndex:indexPath.row];
        
        
        UIImageView *preview = (UIImageView*) [cell.contentView viewWithTag:cellProject.projectID];
        UIImageView *previewContent = [_projectContainers objectAtIndex:indexPath.row];
        //    NSLog(@"fetching image tag %d", [[projectIDs objectAtIndex:indexPath.row]intValue]);
        
        if (!preview)
        {
            previewContent.tag = cellProject.projectID;
            //        NSLog(@"creating previewContent %li", (long) previewContent.tag);
            [cell addSubview: previewContent];
        }
        
        [self.collectionView setBackgroundColor:_collectionGrey];
        cell.contentView.layer.backgroundColor  = [UIColor whiteColor].CGColor;
        
        return cell;
    }
    return cell;
}

#pragma mark reloadItemsAtIndexPath
- (void)reloadItemsAtIndexPaths:(NSArray *)indexPaths{
    NSLog(@"reloadItemsAtIndexPaths");
}

- (UIEdgeInsets)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout*)collectionViewLayout insetForSectionAtIndex:(NSInteger)section{
    return UIEdgeInsetsMake(5, 5, 5, 5);
}

- (CGSize)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout*)collectionViewLayout sizeForItemAtIndexPath:(NSIndexPath *)indexPath {
    return CGSizeMake(_cellWidth, _cellHeight);
}

- (void)collectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath {
    //NSLog(@"cell #%d was selected", indexPath.row);
    Project *selectedProject = [_userProjects objectAtIndex:indexPath.row];
    _selectedProjectID = selectedProject.projectID;
    NSLog(@"selectedProjectID: %@", _selectedProjectID);
    
    [self performSegueWithIdentifier:@"showProjectDetailSegue" sender:self];
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender{
    if([segue.identifier isEqualToString:@"addNewProject"]){
        NSLog(@"=======ADD NEW PROJECT=========");
        EditProjectViewController *epvc = (EditProjectViewController *)segue.destinationViewController;
        [self createProjectClick];
        epvc.projectID = _createdProjectID;
        epvc.userID = self.userID;
        _reloadProjects = YES;
    }
    if([segue.identifier isEqualToString:@"showProjectDetailSegue"]){
//        NSLog(@"loading project");
        EditProjectViewController *epvc = (EditProjectViewController *)segue.destinationViewController;
        NSIndexPath *indexPath = [[self.collectionView indexPathsForSelectedItems] objectAtIndex:0];
        Project *selectedProject = (Project*) [self.fetchedResultsController objectAtIndexPath:indexPath];
        epvc.currentProject = selectedProject;
        epvc.delegate = self;
        epvc.projectID = _selectedProjectID;
        epvc.userID = self.userID;
        _reloadProjects = YES;
    }
}

# pragma mark createProject

//gets called when add new project is clicked
- (IBAction)createProjectClick{
    NSLog(@"createProjectClick");
    // set URL
    NSLog(@"%@", projectsBaseURL);
    NSString *newProjectURLString = [projectsBaseURL stringByAppendingFormat: @"/new?auth_token=%@", _auth_token];
    NSString * url = [NSString stringWithFormat:newProjectURLString];
    //NSLog(@"url%@",url);
    NSURL * NEW_PROJECT_URL = [NSURL URLWithString:url];
    
    // send JSON request
    NSMutableURLRequest * request = [NSMutableURLRequest new];
    [request setURL:NEW_PROJECT_URL];
    [request setHTTPMethod:@"GET"];
    
    // setup the request headers
    [request setValue:@"application/json" forHTTPHeaderField:@"Accept"];
    [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    
    // get JSON response
    NSURLResponse * response = nil;
    NSData * receivedData = nil;
    NSError *error = [[NSError alloc] init];
    
    receivedData = [NSMutableData data];
    receivedData = [NSURLConnection sendSynchronousRequest:request returningResponse:&response error:&error];
    
    // prints JSON response for debugging
    NSString *jsonString = [[NSString alloc] initWithData:receivedData encoding:NSUTF8StringEncoding];
    NSLog(@"response: %@",jsonString);
    
    NSError *e;
    NSDictionary *dict = [NSJSONSerialization JSONObjectWithData:receivedData options:nil error:&e];
    
    _createdProjectID = [dict objectForKey:@"id"];
    
    //reloadProjects = YES;
}


- (IBAction)logoutClick {
    [[Constants sharedGlobalData] logout];
    NSLog(@"returning to root controller");
    [self.navigationController popToRootViewControllerAnimated:YES];
}

- (void)didMoveToParentViewController:(UIViewController *)parent
{
}

- (IBAction)unwindToProjectsCollection:(UIStoryboardSegue *)segue
{
    NSLog(@"returned to projects collection");
}

- (IBAction)showActionSheet:(id)sender {
    UIActionSheet *actionSheet = [[UIActionSheet alloc]
                                  initWithTitle:nil
                                  delegate:self
                                  cancelButtonTitle:@"Cancel"
                                  destructiveButtonTitle:nil
                                  otherButtonTitles:
                                  @"Logout", nil];
    [actionSheet showInView:[UIApplication sharedApplication].keyWindow];
}

- (void)actionSheet:(UIActionSheet *)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex
{
    if (buttonIndex == actionSheet.cancelButtonIndex) return;
    
    switch (buttonIndex) {
        case 0:
        {
            //NSLog(@"Logout");
            [self logoutClick];
            break;
        }
            
        default:
            break;
    }
}

-(void) controllerWillChangeContent:(NSFetchedResultsController *)controller
{
    BOOL animationsEnabled = [UIView areAnimationsEnabled];
    [UIView setAnimationsEnabled:NO];
    [self.collectionView reloadData];
    [UIView setAnimationsEnabled:animationsEnabled];
}

- (void)controller:(NSFetchedResultsController *)controller didChangeSection:(id <NSFetchedResultsSectionInfo>)sectionInfo
           atIndex:(NSUInteger)sectionIndex forChangeType:(NSFetchedResultsChangeType)type
{
    
    NSMutableDictionary *change = [NSMutableDictionary new];
    
    switch(type) {
        case NSFetchedResultsChangeInsert:
            change[@(type)] = @[@(sectionIndex)];
            break;
        case NSFetchedResultsChangeDelete:
            change[@(type)] = @[@(sectionIndex)];
            break;
    }
    
    [_sectionChanges addObject:change];
}

- (void)controller:(NSFetchedResultsController *)controller didChangeObject:(id)anObject
       atIndexPath:(NSIndexPath *)indexPath forChangeType:(NSFetchedResultsChangeType)type
      newIndexPath:(NSIndexPath *)newIndexPath
{
    
    NSMutableDictionary *change = [NSMutableDictionary new];
    switch(type)
    {
        case NSFetchedResultsChangeInsert:
            change[@(type)] = newIndexPath;
            break;
        case NSFetchedResultsChangeDelete:
            change[@(type)] = indexPath;
            break;
        case NSFetchedResultsChangeUpdate:
            change[@(type)] = indexPath;
            break;
        case NSFetchedResultsChangeMove:
            change[@(type)] = @[indexPath, newIndexPath];
            break;
    }
    [_objectChanges addObject:change];
}


- (void)controllerDidChangeContent:(NSFetchedResultsController *)controller
{
    if ([_sectionChanges count] > 0)
    {
        [self.collectionView performBatchUpdates:^{
            
            for (NSDictionary *change in _sectionChanges)
            {
                [change enumerateKeysAndObjectsUsingBlock:^(NSNumber *key, id obj, BOOL *stop) {
                    
                    NSFetchedResultsChangeType type = [key unsignedIntegerValue];
                    switch (type)
                    {
                        case NSFetchedResultsChangeInsert:
                            [self.collectionView insertSections:[NSIndexSet indexSetWithIndex:[obj unsignedIntegerValue]]];
                            break;
                        case NSFetchedResultsChangeDelete:
                            [self.collectionView deleteSections:[NSIndexSet indexSetWithIndex:[obj unsignedIntegerValue]]];
                            break;
                        case NSFetchedResultsChangeUpdate:
                            [self.collectionView reloadSections:[NSIndexSet indexSetWithIndex:[obj unsignedIntegerValue]]];
                            break;
                    }
                }];
            }
        } completion:nil];
    }
    
    if ([_objectChanges count] > 0 && [_sectionChanges count] == 0)
    {
        [self.collectionView performBatchUpdates:^{
            
            for (NSDictionary *change in _objectChanges)
            {
                [change enumerateKeysAndObjectsUsingBlock:^(NSNumber *key, id obj, BOOL *stop) {
                    
                    NSFetchedResultsChangeType type = [key unsignedIntegerValue];
                    switch (type)
                    {
                        case NSFetchedResultsChangeInsert:
                            [self.collectionView insertItemsAtIndexPaths:@[obj]];
                            break;
                        case NSFetchedResultsChangeDelete:
                            [self.collectionView deleteItemsAtIndexPaths:@[obj]];
                            break;
                        case NSFetchedResultsChangeUpdate:
                            [self.collectionView reloadItemsAtIndexPaths:@[obj]];
                            break;
                        case NSFetchedResultsChangeMove:
                            [self.collectionView moveItemAtIndexPath:obj[0] toIndexPath:obj[1]];
                            break;
                    }
                }];
            }
        } completion:nil];
    }
    
    [_sectionChanges removeAllObjects];
    [_objectChanges removeAllObjects];
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

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex
{
    NSString *title = [alertView buttonTitleAtIndex:buttonIndex];
    
    if([title isEqualToString:@"Add New Project"])
    {
        [self performSegueWithIdentifier:@"addNewProject" sender:self];
    }else if(buttonIndex == [alertView cancelButtonIndex]){
        [alertView dismissWithClickedButtonIndex:-1 animated:YES];
    }
}

- (NSUInteger)supportedInterfaceOrientations
{
    return UIInterfaceOrientationMaskPortrait;
}

@end
