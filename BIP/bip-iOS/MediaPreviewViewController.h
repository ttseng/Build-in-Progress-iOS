//
//  MediaPreviewViewController.h
//  BiP
//
//  Created by ttseng on 9/1/14.
//  Copyright (c) 2014 LLK. All rights reserved.
//

#import <MediaPlayer/MediaPlayer.h>
#import <UIKit/UIKit.h>
#import "YTPlayerView.h"
#import "YTVimeoExtractor.h"
#import "Multimedia.h"

@interface MediaPreviewViewController : UIViewController <UIActionSheetDelegate, YTPlayerViewDelegate>{

}

@property (weak, nonatomic) IBOutlet UIImageView *mediaView;
@property (strong,nonatomic) IBOutlet MPMoviePlayerController *player;
@property (weak, nonatomic) IBOutlet UIBarButtonItem *deleteButton;
@property (weak, nonatomic) IBOutlet UIBarButtonItem *checkButton;
@property (strong, nonatomic) NSString *selectedImageURL;
@property (nonatomic) int selectedImageID;
@property (strong,nonatomic) Multimedia *selectedMedia;
@property(nonatomic, strong) IBOutlet YTPlayerView *playerView;
@property (nonatomic, strong) void (^onDismiss)(UIViewController *sender, BOOL *didDeleteImage);
@property BOOL customCamera;
@property CGFloat screenWidth;
@property CGFloat screenHeight;

@property NSArray *multimediaList;
@property int currentMediaIndex;
@property NSMutableDictionary * playerObjectDictionary;
@property (weak, nonatomic) IBOutlet UIScrollView *multimediaScrollView;


- (IBAction)deleteMediaClick:(id)sender;

@end
