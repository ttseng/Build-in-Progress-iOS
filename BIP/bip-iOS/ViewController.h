//
//  ViewController.h
//  bip-iOS
//
//  Created by Sarah Liu on 2/25/14.
//  Copyright (c) 2014 LLK. All rights reserved.
//

#import <UIKit/UIKit.h>
@import Security;

@interface ViewController : UIViewController <UITextFieldDelegate>

- (IBAction)createProjectClick:(id)sender;
- (IBAction)addStepClick:(id)sender;

- (IBAction)deleteProjectClick:(id)sender;
- (IBAction)deleteStepClick:(id)sender;

@end