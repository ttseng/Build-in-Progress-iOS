//
//  Multimedia.m
//  BiP
//
//  Created by ttseng on 11/28/14.
//  Copyright (c) 2014 LLK. All rights reserved.
//

#import "Multimedia.h"

@implementation Multimedia


// create image multimedia
-(void)createMediaWithMediaID:(int)media_id mediaPath:(NSString *)media_path videoRotation:(int)video_rotation{
    self.mediaID = media_id;
    self.mediaPath = media_path;
    self.videoRotation = video_rotation;
    if([self.mediaPath rangeOfString:@"youtube"].location != NSNotFound){
        self.isVideo = true;
        //self.videoType = @"youtube";
        self.videoSourceType = YOUTUBE;
    }else if([self.mediaPath rangeOfString:@"vimeo"].location != NSNotFound){
        self.isVideo = true;
        //self.videoType = @"vimeo";
        self.videoSourceType = VIMEO;
    }else if([[self.mediaPath pathExtension] isEqualToString: @"mp4"] || [[media_path pathExtension]  isEqualToString: @"webm"]){
        self.isVideo = true;
        //self.videoType = @"uploaded";
        self.videoSourceType = UPLOADED;
    }else{
        self.isVideo = false;
    }
}

// setVideo - set the path of a local video
-(void)setVideo:(NSURL *) media_url{
    self.isVideo = true;
    self.mediaURL = media_url;
}

@end
