//
//  EditLabelViewController.h
//  BiP
//
//  Created by ttseng on 8/24/15.
//  Copyright (c) 2015 LLK. All rights reserved.
//

#import <UIKit/UIKit.h>

@protocol sendDataProtocol <NSObject>
-(void)sendDataToEditProject:(NSString*)editInfo; // this either returns the id of the step that had been edited or "delete" to indicate that the entire project should be refreshed
@end

@interface EditLabelViewController : UIViewController <UIActionSheetDelegate, UITableViewDelegate, UIAlertViewDelegate, UITextViewDelegate>

@property(nonatomic,assign)id delegate;
@property (nonatomic) id projectID;
@property (nonatomic) id userID;
@property (nonatomic) NSString* labelName;
@property (nonatomic) id stepID;
@property (nonatomic) int stepPosition;
@property (nonatomic) NSString* labelColor;
@property (nonatomic) UIColor *selectedColor;

@property (weak, nonatomic) IBOutlet UITextField *labelNameTextField;
@property (weak, nonatomic) IBOutlet UILabel *titleBackgroundLabel;
@property (weak, nonatomic) IBOutlet UIButton *editButton;
@property (weak, nonatomic) IBOutlet UIButton *blueButton;
@property (weak, nonatomic) IBOutlet UIButton *redButton;
@property (weak, nonatomic) IBOutlet UIButton *greenButton;
@property (weak, nonatomic) IBOutlet UIButton *greyButton;


- (IBAction)showActionSheet:(id)sender;

@end
