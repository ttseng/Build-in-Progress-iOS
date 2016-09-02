//
//  NoInternetViewController.h
//  BiP
//
//  Created by ttseng on 9/7/14.
//  Copyright (c) 2014 LLK. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface NoInternetViewController : UIViewController
@property (weak, nonatomic) IBOutlet UILabel *NoInternet;
@property (weak, nonatomic) IBOutlet UILabel *label1;
@property (weak, nonatomic) IBOutlet UILabel *label2;
@property (weak, nonatomic) IBOutlet UIButton *close;

- (IBAction)close:(id)sender;

@end
