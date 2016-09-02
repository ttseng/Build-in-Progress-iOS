//
//  ViewController.m
//  bip-iOS
//
//  Created by Sarah Liu on 2/22/14.
//  Copyright (c) 2014 LLK. All rights reserved.
//

#import "ViewController.h"

#define bgQueue dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0)
//NSString *username = @"scientiffic";
//NSString *urlTemplate = @"http://bip-android-test.herokuapp.com/users/";


//#define userUrl [NSURL URLWithString:@"http://bip-android-test.herokuapp.com/users/zhaveriane.json"]

@interface ViewController ()
{
    NSArray *arrayOfImages;
    NSArray *arrayOfLabels;
}

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    /*
	NSString *urlString = [urlTemplate stringByAppendingString:username];
    NSURL *userUrl = [NSURL URLWithString:urlString];
    // load project data automatically
    dispatch_async(bgQueue, ^{
        NSData * projectData = [NSData dataWithContentsOfURL:userUrl];
        [self performSelectorOnMainThread:@selector(fetchProjects:)
                               withObject:projectData waitUntilDone:YES];
    });
     */
    
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


// add step declarations
int projectID;
NSNumber * lastStepID;
NSUInteger lastStepPos;

- (IBAction)createProjectClick:(id)sender {
    // set URL
    NSString * auth_token = @"LZ5js43vNnQD_Yy_cswJ";
    NSString * url = [NSString stringWithFormat:@"http://bip-android-test.herokuapp.com/projects/new?auth_token=%@", auth_token];
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
    //NSString *jsonString = [[NSString alloc] initWithData:receivedData encoding:NSUTF8StringEncoding];
    //NSLog(@"response: %@",jsonString);
}

- (IBAction)addStepClick:(id)sender {
    NSLog(@"clicked addStepClick");
    // set up JSON
    NSError *error = [[NSError alloc] init];
    NSDictionary * stepDict = [[NSDictionary alloc] initWithObjectsAndKeys: @"New Step", @"name", lastStepID, @"parent_id", @NO, @"last", @"", @"description", nil];
    NSDictionary * holderDict = [[NSDictionary alloc] initWithObjectsAndKeys: stepDict, @"step", nil];
    NSData * holder = [NSJSONSerialization dataWithJSONObject:holderDict options:0 error:&error];
    
    // set up URL
    NSString * auth_token = @"LZ5js43vNnQD_Yy_cswJ";
    NSString * url = [NSString stringWithFormat:@"http://bip-android-test.herokuapp.com/projects/%d/steps?auth_token=%@", projectID, auth_token];
    NSURL * NEW_STEP_URL =[NSURL URLWithString:url];
    
    //NSLog(@"%d", projectID);
    
    // send JSON request
    NSMutableURLRequest * request = [NSMutableURLRequest new];
    [request setURL:NEW_STEP_URL];
    [request setHTTPMethod:@"POST"];
    
    // setup the request headers
    [request setValue:@"application/json" forHTTPHeaderField:@"Accept"];
    [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    [request setHTTPBody:holder];
    
    // receive JSON response
    NSURLResponse * response = nil;
    NSData * receivedData = nil;

    receivedData = [NSMutableData data];
    receivedData = [NSURLConnection sendSynchronousRequest:request returningResponse:&response error:&error];
    
    // prints JSON response for debugging
    //NSString *jsonString = [[NSString alloc] initWithData:receivedData encoding:NSUTF8StringEncoding];
    //NSLog(@"response: %@",jsonString);
}

- (IBAction)deleteProjectClick:(id)sender {
    // set up URL
    NSString * auth_token = @"LZ5js43vNnQD_Yy_cswJ";
    NSString * url = [NSString stringWithFormat:@"http://bip-android-test.herokuapp.com/projects/%d?auth_token=%@", projectID, auth_token];
    NSURL * DELETE_PROJECT_URL =[NSURL URLWithString:url];
    
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
}

- (IBAction)deleteStepClick:(id)sender {
    // set up URL
    NSString * auth_token = @"LZ5js43vNnQD_Yy_cswJ";
    NSString * url = [NSString stringWithFormat:@"http://bip-android-test.herokuapp.com/projects/%d/steps/%d?auth_token=%@", projectID, lastStepPos, auth_token];
    NSURL * DELETE_STEP_URL =[NSURL URLWithString:url];
    
    //NSLog(@"%d", projectID);
    //NSLog(@"%d", lastStepPos);
    
    
    // send JSON request
    NSMutableURLRequest * request = [NSMutableURLRequest new];
    [request setURL:DELETE_STEP_URL];
    [request setHTTPMethod:@"DELETE"];
    
    // receive JSON response
    NSURLResponse * response = nil;
    NSData * receivedData = nil;
    
    NSError *error = [[NSError alloc] init];
    
    receivedData = [NSMutableData data];
    receivedData = [NSURLConnection sendSynchronousRequest:request returningResponse:&response error:&error];
}

// sets projectID to the most recent project
- (void)setProjectID:(NSString *) num {
    projectID = [num intValue];
    
    NSString * url = [NSString stringWithFormat:@"http://bip-android-test.herokuapp.com/projects/%d/steps.json", projectID];
    NSURL * stepsURL = [NSURL URLWithString:url];
    
    NSData * stepsData = [NSData dataWithContentsOfURL:stepsURL];
    [self performSelectorOnMainThread:@selector(fetchProjectSteps:)
                           withObject:stepsData waitUntilDone:YES];
}

// sets lastStepID to the most recent step
- (void)setParentStep:(NSString *) num {
    lastStepID = [NSNumber numberWithInt:[num intValue]];
}

// get JSON data of projects
- (void)fetchProjects:(NSData *)responseData {
    NSError * error;
    NSDictionary * json = [NSJSONSerialization
                           JSONObjectWithData:responseData
                           options:kNilOptions
                           error:&error];
    NSDictionary * data = [json objectForKey:@"data"]; // get data in array
    NSArray * projects = [data objectForKey:@"projects"];
    NSDictionary * mostRecentProject = [projects objectAtIndex:0];
    
    NSString * num = [mostRecentProject objectForKey:@"id"];
    [self setProjectID:num];
}

// get JSON data of steps
- (void)fetchProjectSteps:(NSData *)responseData {
    NSError * error;
    NSDictionary * json = [NSJSONSerialization
                           JSONObjectWithData:responseData
                           options:kNilOptions
                           error:&error];
    
    NSDictionary * data = [json objectForKey:@"data"];
    NSArray * steps = [data objectForKey:@"steps"];
    lastStepPos = [steps count] - 1;
    NSDictionary * mostRecentStep = [steps lastObject];
    
    NSString * num = [mostRecentStep objectForKey:@"id"];
    [self setParentStep:num];
}








@end
