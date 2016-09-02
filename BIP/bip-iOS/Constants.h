//
//  Constants.h
//  BiP
//
//  Created by ttseng on 8/28/14.
//  Copyright (c) 2014 LLK. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AssetsLibrary/AssetsLibrary.h>

@interface Constants : NSObject

+(Constants*)sharedGlobalData;

#define BLUE [UIColor colorWithRed:0 green:0.682 blue:0.937 alpha:1] // blue label color
#define RED [UIColor colorWithRed:0.937 green:0.267 blue:0.212 alpha:1] // red label color
#define GREEN [UIColor colorWithRed:0.471 green:0.725 blue:0.125 alpha:1] // green label color
#define GREY [UIColor colorWithRed:0.62 green:0.62 blue:0.62 alpha:1] // grey label color
#define DARKGREY [UIColor colorWithRed:152/255.0f green:152/255.0f blue:152/255.0f alpha:1.0f] // background grey color for stepName / labelName
#define LIGHTGREY [UIColor colorWithRed:152/255.0f green:152/255.0f blue:152/255.0f alpha:0.07f] 

extern NSString* const sessionsBaseURL;
extern NSString* const userBaseURL;
extern NSString* const projectsBaseURL;
extern NSString* const imagesBaseURL;
extern NSString* const videosBaseURL;
extern NSString* const videoCreateBaseURL;
extern NSString* const s3imageURL;
extern NSString* const s3uploadURL;
extern NSString* const blueLabelHex;
extern NSString* const redLabelHex;
extern NSString* const greenLabelHex;
extern NSString* const greyLabelHex;

extern NSString* const aws_id_pool;
extern NSString* const aws_bucket_name;


-(void)logout;
+(ALAssetsLibrary *)defaultAssetsLibrary;

@end