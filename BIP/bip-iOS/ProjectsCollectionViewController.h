//
//  ProjectsCollectionViewController.h
//  bip-iOS
//
//  Created by Teresa Tai on 6/9/14.
//  Copyright (c) 2014 LLK. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "Project.h"
#import "EditProjectViewController.h"
#import "CustomNavigationController.h"

@interface ProjectsCollectionViewController : UICollectionViewController <UICollectionViewDataSource, UICollectionViewDelegate, UIActionSheetDelegate, EditProjectViewControllerDelegate, NSFetchedResultsControllerDelegate>{
    
    IBOutlet UIActivityIndicatorView *loadingCircle;
    NSTimer *timer;
}

@property (strong, nonatomic) IBOutlet ProjectsCollectionViewController *projects;
@property (strong, nonatomic) IBOutlet ProjectsCollectionViewController *projectCollection;
@property (strong, nonatomic) IBOutlet UICollectionView *collectionView;
@property (strong, nonatomic) IBOutlet UICollectionViewFlowLayout *layout;
@property (strong, nonatomic) IBOutlet UICollectionViewCell *cell;
//@property (strong, nonatomic) IBOutlet UILabel *cellLabel;
@property (nonatomic,strong) NSManagedObjectContext *managedObjectContext;
@property (nonatomic,strong) NSFetchedResultsController *fetchedResultsController;
@property NSString *username;
@property NSString *userID;
@property NSMutableArray *sectionChanges;
@property NSMutableArray *objectChanges;
@property IBOutlet UIButton *btnLogout;
@property NSMutableArray *projectContainers; // cell containers for project contents in collection
@property NSMutableArray *userProjects; // array containing all the user's project objects

@property BOOL reloadProjects;

@property CGFloat screenWidth;
@property CGFloat screenHeight;

@property id selectedProjectID;
@property id createdProjectID;

@property int cellWidth;
@property int cellHeight;

@property NSURL *userUrl;
@property NSString * auth_token;

@property UIColor *collectionGrey;

@property BOOL internetAvailable;

- (IBAction)unwindToProjectsCollection:(UIStoryboardSegue *)segue;
- (IBAction)showActionSheet:(id)sender;

@end
