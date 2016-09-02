//
//  EditProjectDescriptionViewController.h
//  bip-iOS
//
//  Created by Teresa Tai on 8/5/14.
//  Copyright (c) 2014 LLK. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface EditProjectDescriptionViewController : UIViewController <UITextViewDelegate>

@property (nonatomic) id projectID;
@property NSString *descriptionText;
@property NSAttributedString *attributedDescText;
@property (weak, nonatomic) IBOutlet UITextView *descriptionField;

@property (strong, nonatomic) IBOutlet UITapGestureRecognizer *textFieldGestureRecognizer;
@property (strong, nonatomic) IBOutlet UITapGestureRecognizer *backgroundTapGestureRecognizer;

@end
