//
//  Constants.m
//  BiP
//
//  Created by ttseng on 8/28/14.
//  Copyright (c) 2014 LLK. All rights reserved.
//

#import "Constants.h"
#import "AppDelegate.h"
#import "KeychainItemWrapper.h"

@implementation Constants

NSString* const userBaseURL = @""; // http://your_bip_source.com/users
NSString* const sessionsBaseURL = @""; // http://your_bip_source.com/sessions.json
NSString* const projectsBaseURL = @""; // http://your_bip_source.com/projects
NSString* const imagesBaseURL = @""; // http://your_bip_source.com/images
NSString* const videosBaseURL = @""; // http://your_bip_source.com/videos
NSString* const videoCreateBaseURL = @""; // http://your_bip_source.com/videos/create_mobile
NSString* const s3imageURL = @""; // http://your_bip_source.com/image/image_path
NSString* const s3uploadURL = @""; // http://your_aws_bucketname.s3.amazonaws.com/uploads/

NSString* const blueLabelHex = @"#00AEEF";
NSString* const redLabelHex = @"#EF4436";
NSString* const greenLabelHex = @"#78B920";
NSString* const greyLabelHex = @"#9e9e9e";

// AWS Credentials
NSString* const aws_id_pool = @""; // your aws id pool
NSString* const aws_bucket_name = @""; // your aws bucket name

NSString * auth_token;

static Constants *sharedGlobalData = nil;


+ (Constants*)sharedGlobalData {
    if(sharedGlobalData == nil){
        sharedGlobalData = [[super allocWithZone:NULL]init];
    }
    return sharedGlobalData;
}


+ (id)allocWithZone:(NSZone *)zone {
    @synchronized(self)
    {
        if (sharedGlobalData == nil)
        {
            sharedGlobalData = [super allocWithZone:zone];
            return sharedGlobalData;
        }
    }
    return nil;
}

- (id)copyWithZone:(NSZone *)zone {
    return self;
}

- (void)logout {
    
    // logout through BIP
    NSMutableURLRequest * request = [NSMutableURLRequest new];
    
    AppDelegate *mainDelegate = (AppDelegate *)[[UIApplication sharedApplication] delegate];
    NSString *auth_token = [mainDelegate.keychainItem objectForKey:(__bridge id)(kSecAttrType)];
    NSString *logoutURLString = [NSString stringWithFormat:[sessionsBaseURL stringByAppendingFormat:@"?auth_token=%@", auth_token]];
    NSLog(@"logoutURLString: %@", logoutURLString);
    
    [request setURL:[NSURL URLWithString:logoutURLString]];
    [request setHTTPMethod:@"DELETE"];
    
    // receive JSON response
    NSURLResponse * response = nil;
    NSData * receivedData = nil;
    
    NSError *error = [[NSError alloc] init];
    
    receivedData = [NSMutableData data];
    receivedData = [NSURLConnection sendSynchronousRequest:request returningResponse:&response error:&error];
    
    NSString *jsonString = [[NSString alloc] initWithData:receivedData encoding:NSUTF8StringEncoding];
    
    [mainDelegate.keychainItem resetKeychainItem];
    
}

+ (ALAssetsLibrary *)defaultAssetsLibrary {
    static dispatch_once_t pred = 0;
    static ALAssetsLibrary *library = nil;
    dispatch_once(&pred, ^{
        library = [[ALAssetsLibrary alloc] init];
    });
    return library;
}

@end