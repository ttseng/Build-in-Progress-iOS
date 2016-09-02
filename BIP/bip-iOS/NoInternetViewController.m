//
//  NoInternetViewController.m
//  BiP
//
//  Created by ttseng on 9/7/14.
//  Copyright (c) 2014 LLK. All rights reserved.
//

#import "NoInternetViewController.h"
#import "Reachability.h"
#import "ReachabilityManager.h"

@interface NoInternetViewController (){
    BOOL internetAvailable;
}

@end

@implementation NoInternetViewController

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Custom initialization
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleNetworkChange:) name:kReachabilityChangedNotification object:nil];
    // Do any additional setup after loading the view.
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/


 - (void) handleNetworkChange:(NSNotification *)notice
{
    if([ReachabilityManager isReachable]){
        if(internetAvailable == NO){
            [self dismissViewControllerAnimated:YES completion:nil];
        }
        internetAvailable = YES;
    }
}

@end
