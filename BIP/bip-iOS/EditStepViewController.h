//
//  EditStepViewController.h
//  bip-iOS
//
//  Created by Teresa Tai on 7/21/14.
//  Copyright (c) 2014 LLK. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "WSAssetPicker.h"

@protocol sendDataProtocol <NSObject>
-(void)sendDataToEditProject:(NSString*)editInfo; // this either returns the id of the step that had been edited or "delete" to indicate that the entire project should be refreshed
@end


@interface EditStepViewController : UIViewController <UIActionSheetDelegate, UITableViewDelegate, UIAlertViewDelegate, UITextViewDelegate>{
    IBOutlet UIScrollView *pageScroller;
    IBOutlet UIScrollView *imageScroller;
}

@property (strong, nonatomic) IBOutlet UIView *view;
@property (strong, nonatomic) IBOutlet UITextField *stepNameField;
@property (weak, nonatomic) IBOutlet UITextView *stepDescriptionField;
@property (weak, nonatomic) IBOutlet UIImageView *editTitleImageView;
@property (weak, nonatomic) IBOutlet UIScrollView *scrollView; // scroll view for the entire screen
@property (weak, nonatomic) IBOutlet UIScrollView *imageScrollView; // scrollview for just the images
//@property (weak, nonatomic) IBOutlet UIButton *addImagesButton;

@property(nonatomic,assign)id delegate;

@property (strong, nonatomic) ALAssetsLibrary *assetsLibrary;
@property (strong, nonatomic) IBOutlet UIButton *editButton;


@property IBOutlet UITextView *activeView;
@property UITapGestureRecognizer *tapRecognizer;
@property (weak, nonatomic) IBOutlet UIImageView *stepImages;
@property (weak, nonatomic) IBOutlet UILabel *titleBackgroundLabel;

@property (strong, nonatomic) NSMutableArray *uploadMedia; // contains Multimedia objects for media being uploaded to BIP to appear in horizontal scroller imageScroller
@property (nonatomic) id projectID;
@property (nonatomic) id userID;
@property (nonatomic) NSString* stepName;
@property (nonatomic) id stepID;
@property (nonatomic) int stepPosition;


typedef enum{
    isLabel,
    isStep,
}StepState;

- (IBAction)showActionSheet:(id)sender;
- (IBAction)unwindToList:(UIStoryboardSegue *)segue;

@end