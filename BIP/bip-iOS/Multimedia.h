//
//  Multimedia.h
//  BiP
//
//  Created by ttseng on 11/28/14.
//  Copyright (c) 2014 LLK. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface Multimedia : NSObject{

}

@property (readwrite, getter=getID)int mediaID;
@property (readwrite, getter=getMediaPath)NSString *mediaPath;
@property (readwrite, getter=getMediaURL)NSURL *mediaURL;
@property (readwrite, getter=getView)UIImageView *view;
@property (readwrite, getter=getImage)UIImage *image;

@property int position;
@property BOOL isVideo;
@property int videoRotation;
@property NSURL *localVideoPath;

-(void)createMediaWithMediaID:(int)media_id mediaPath:(NSString *)media_path videoRotation:(int)video_rotation;
-(void)setVideo:(NSURL *)media_url;

@property enum videoSource videoSourceType;

typedef enum videoSource{
    YOUTUBE,
    VIMEO,
    UPLOADED
} videoSource;

@end
