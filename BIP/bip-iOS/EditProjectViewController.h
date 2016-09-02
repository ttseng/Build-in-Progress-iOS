//
//  EditProjectViewController.h
//  bip-iOS
//
//  Created by Teresa Tai on 7/1/14.
//  Copyright (c) 2014 LLK. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "Project.h"
#import "EditStepViewController.h"

@protocol EditProjectViewControllerDelegate;

@interface EditProjectViewController : UIViewController <UIActionSheetDelegate, UITableViewDelegate, UITableViewDataSource, UIAlertViewDelegate, sendDataProtocol>{
    IBOutlet UIActivityIndicatorView *loadingCircle;
}
@property (strong, nonatomic) IBOutlet UIView *view;
@property (weak,nonatomic) IBOutlet UITableView *projectInfo;
@property (nonatomic) id projectID;
@property (nonatomic) id userID;
@property (nonatomic) id editedStepID;

@property (weak, nonatomic) IBOutlet UILabel *titleBackgroundLabel;
@property (strong, nonatomic) IBOutlet UITextField *titleField;
@property (strong, nonatomic) IBOutlet UIButton *descriptionButton;
@property IBOutlet UITextField *activeField;
@property (weak, nonatomic) IBOutlet UIBarButtonItem *backButton;
@property (weak, nonatomic) IBOutlet UIImageView *editTitleImageView;
@property (weak, nonatomic) IBOutlet UIBarButtonItem *addNewStep;
@property (strong, nonatomic) IBOutlet UIButton *editProjectTitleButton;
@property (weak, nonatomic) IBOutlet UIButton *stepsButton;
@property (weak, nonatomic) IBOutlet UIButton *labelsButton;
@property (weak, nonatomic) IBOutlet UIBarButtonItem *addButton;
@property (weak, nonatomic) IBOutlet UISegmentedControl *viewModes;
@property (weak, nonatomic) IBOutlet UIProgressView *mapLoadProgressView;

- (IBAction)showActionSheet:(id)sender;
- (IBAction)cancelEditing:(id)sender;
- (IBAction)saveEditing:(id)sender;
- (IBAction)addNewStep:(id)sender;

@property (strong, nonatomic) IBOutlet UITapGestureRecognizer *textFieldGestureRecognizer;
@property (strong, nonatomic) IBOutlet UITapGestureRecognizer *backgroundTapGestureRecognizer;

@property (nonatomic, weak) id <EditProjectViewControllerDelegate> delegate;
@property (nonatomic,strong) NSManagedObjectContext *managedObjectContext;
@property (nonatomic,strong) NSFetchedResultsController *fetchedResultsController;
@property (nonatomic, strong) Project *currentProject;


typedef enum {
    labelView,
    stepView
} ViewState;


@end

@protocol EditProjectViewControllerDelegate

- (IBAction)unwindToList:(UIStoryboardSegue *)segue;
-(void) editProjectViewControllerDidSave;
-(void) editProjectViewControllerDidCancel: (Project *) projectToDelete;
-(void) saveNewProjectTitle: (NSString *) title;

@end