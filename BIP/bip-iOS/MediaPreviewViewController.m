//
//  MediaPreviewViewController.m
//  BiP
//
//  Created by ttseng on 9/1/14.
//  Copyright (c) 2014 LLK. All rights reserved.
//

#import <MediaPlayer/MediaPlayer.h>
#import <AVFoundation/AVFoundation.h>
#import "MediaPreviewViewController.h"
#import "Constants.h"
#import "Reachability.h"
#import "ReachabilityManager.h"
#import "NoInternetViewController.h"
#import "YTVimeoExtractor.h"
#import "AppDelegate.h"

@interface MediaPreviewViewController ()

@property CGFloat scrollViewWidth;
@property CGFloat scrollViewHeight;
@property CGRect standardFrame;

@end

@implementation MediaPreviewViewController
{
    int imageID;
    NSString *deleteImageURLString;
    NSString * auth_token;
    BOOL internetAvailable;
    UIActivityIndicatorView *spinner;
    AppDelegate *mainDelegate;
}

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil withParentView:(UIViewController *)parentViewController
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Custom initialization
    }
    return self;
}



#pragma mark Scroll View Methods

-(void)scrollViewDidEndDecelerating: (UIScrollView *)scrollView
{
    //Get current index
    int intIndex = (int) self.multimediaScrollView.contentOffset.x / self.multimediaScrollView.bounds.size.width;
    self.currentMediaIndex = intIndex;
    NSLog(@"scrolled to index %i", intIndex);
    
    //Check if object at index is a video (would exist in playerObjectDictionary)
    if ([self.playerObjectDictionary objectForKey:[NSString stringWithFormat:@"%i", intIndex]]) {
        
        //Extracts player from dictionary, plays if ready
        AVPlayer * tempPlayer = [self.playerObjectDictionary objectForKey:[NSString stringWithFormat:@"%i", intIndex]];
        if (tempPlayer.status == AVPlayerStatusReadyToPlay) {
            [tempPlayer play];
        }
    }
    
    //Updates selectedMedia for deleting
    self.selectedMedia = [self.multimediaList objectAtIndex:intIndex];
    deleteImageURLString = [NSString stringWithFormat:[imagesBaseURL stringByAppendingFormat:@"/%i?auth_token=%@", [self.selectedMedia getID], auth_token]];
//    NSLog(@"deleteImageURLString: %@", deleteImageURLString);
}

-(void)scrollViewWillBeginDragging: (UIScrollView *)scrollView
{
    //Extracts player from dictionary
    AVPlayer * tempPlayer = [self.playerObjectDictionary objectForKey:[NSString stringWithFormat:@"%i", self.currentMediaIndex]];
    
    //Pauses and resets player to beginning
    [tempPlayer pause];
    [tempPlayer seekToTime:kCMTimeZero];
}

-(void)viewWillAppear:(BOOL)animated{

}


#pragma mark Multimedia Loading Methods

-(void)loadMultimedia
{
//    NSLog(@"loadMultimedia");

    //loading queue
    dispatch_queue_t mediaQueue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
    
    //initializing scroll view
    self.scrollViewWidth = self.multimediaScrollView.bounds.size.width;
    self.scrollViewHeight = self.multimediaScrollView.bounds.size.height;
    CGPoint initialOffset = CGPointMake(self.scrollViewWidth * self.currentMediaIndex, 0);
    
    [self.multimediaScrollView setContentSize:CGSizeMake(self.scrollViewWidth*[self.multimediaList count], self.scrollViewHeight)];
    [self.multimediaScrollView setPagingEnabled: YES];
    [self.multimediaScrollView setFrame: CGRectMake(0, 0, self.scrollViewWidth, self.scrollViewHeight)];
    //[self.multimediaScrollView setScrollEnabled:YES];
    [self.multimediaScrollView setDelegate: self];
    [self.multimediaScrollView setContentOffset:initialOffset]; //depends on which one is clicked on initially

    //initializing dictionary containing references to video players
    self.playerObjectDictionary = [[NSMutableDictionary alloc] init];

    //Loading in order by distance from initial spot
    int multimediaLastIndex = (int) [self.multimediaList count] - 1;
    int initialMediaIndex = self.currentMediaIndex; //must be executed before any scrolling is allowed
    int displacementFromInitialIndex = 0;

   [self.view addSubview:self.multimediaScrollView];
    
    while (
           (initialMediaIndex - displacementFromInitialIndex) >= 0 ||
           (initialMediaIndex + displacementFromInitialIndex) <= multimediaLastIndex
           ) {
        
        //right
        int right = initialMediaIndex + displacementFromInitialIndex;
        if (right <= multimediaLastIndex) {
//             NSLog(@"loadSingleMediaWithIndex right %i", right);
                [self loadSingleMediaWithIndex:right];
            
        }
        
        //left
        int left = initialMediaIndex - displacementFromInitialIndex-1;
        if (0 <= left) {
//                NSLog(@"loadSingleMediaWithIndex left %i", left);
            [self loadSingleMediaWithIndex:left];
        }
        
        displacementFromInitialIndex++;
    }
    
    [self scrollViewDidEndDecelerating: self.multimediaScrollView];
 
}


- (void) loadSingleMediaWithIndex:(int)index
{
//    NSLog(@"loadSingleMediaWithIndex for index %i", index);
    
    Multimedia * media = [self.multimediaList objectAtIndex:index];
    float x = index * self.scrollViewWidth;
    
    //create a UIView in which either an image (UIImageView) or video (AVPlayerLayer)
    //will be added as a subview/sublayer
    UIView * contentView = [[UIView alloc] initWithFrame:CGRectMake(x, 0, self.scrollViewWidth, self.scrollViewHeight)];
    contentView.contentMode = UIViewContentModeScaleAspectFit;
    
    if (![media isVideo]){ //Image
        
        UIImage *image = [media getImage];
        UIImageView *imageView = [[UIImageView alloc] initWithImage:image];
        
        imageView.contentMode = UIViewContentModeScaleAspectFit;
        
        imageView.frame = CGRectMake(0, 0, self.scrollViewWidth, self.scrollViewHeight);
        dispatch_async(dispatch_get_main_queue(), ^{
//            NSLog(@"adding image");
            [contentView addSubview:imageView];
            [self.multimediaScrollView addSubview:contentView];
        });
        
    } else { //Video
        NSURL * videoURL;
        
        if ([media getMediaURL]) {
            videoURL = [media getMediaURL];
        } else {
            NSString * videoPath = [media getMediaPath];
            NSLog(@"videoPath: %@", videoPath);
            videoURL = [NSURL URLWithString:videoPath];
        }
        
        NSLog(@"videoRotation: %i", [self.selectedMedia videoRotation]);
        
        //Using AV Foundation
        AVAsset * videoAsset = [[AVURLAsset alloc] initWithURL:videoURL options:nil];
        AVPlayerItem * videoPlayerItem = [[AVPlayerItem alloc] initWithAsset:videoAsset];
        AVPlayer * videoPlayer = [[AVPlayer alloc] initWithPlayerItem:videoPlayerItem];
        AVPlayerLayer *videoLayer = [AVPlayerLayer playerLayerWithPlayer: videoPlayer];
        
        //Saving reference to each player object
        [self.playerObjectDictionary setValue:videoPlayer forKey: [NSString stringWithFormat:@"%d", index]];
        
        //On main thread, update UI
        dispatch_async(dispatch_get_main_queue(), ^{
            
            videoPlayer.actionAtItemEnd = AVPlayerActionAtItemEndNone;
            videoLayer.frame = CGRectMake(0, 0, self.scrollViewWidth, self.scrollViewHeight);
            
            //Rotated video
            if (media.videoRotation == 90) {
                contentView.transform = CGAffineTransformMakeRotation(M_PI_2*3);
                contentView.contentMode = UIViewContentModeScaleAspectFill;
            }
            
            [contentView.layer addSublayer:videoLayer];
            [self.multimediaScrollView addSubview:contentView];
            
            if(self.currentMediaIndex == index){
                // automatically play the user selected video
                [videoPlayer play];
            }
        });
        
        /*
         if([self.selectedMedia videoRotation] != 90){
         // play non-rotated video
         self.player = [[MPMoviePlayerController alloc] initWithContentURL:selectedMediaURL];
         [self presentMoviePlayerViewControllerAnimated:self.player];
         [self.player.view setFrame:CGRectMake(0, 0, 320, self.view.frame.size.height - 44)];
         [self.view addSubview:self.player.view];
         [self.player play];
         [self.view bringSubviewToFront:spinner];
         }else{
         // play rotated video
         [self.player.view setFrame:CGRectMake(0, 0, self.view.frame.size.height, self.view.frame.size.width)];
         NSLog(@"self.view.frame.size %f x %f", self.view.frame.size.width, self.view.frame.size.height);
         //            [self.player.view setBounds:CGRectMake(0,0,400.0, 320.0)];
         self.player.controlStyle = MPMovieControlStyleEmbedded;
         self.player.view.transform = CGAffineTransformMakeRotation(M_PI_2*3);
         self.player.view.center = self.view.center;
         [self.view addSubview:self.player.view];
         [self.player play];
         [self.view bringSubviewToFront:spinner];
         */
        
    }
    
}

- (void)loadYoutubeVideoFromMultimedia:(Multimedia*)media  InView:(UIView *)contentView
{
    YTPlayerView * youtubePlayerView = [[YTPlayerView alloc] initWithFrame:
                                 CGRectMake(0, 0, self.scrollViewWidth, self.scrollViewHeight)];
    
    
    NSURL * youtubeURL = [media getMediaURL];
    NSString * youtubePath = [media getMediaPath];
    
    //get youtube video ID
    NSMutableString *videoUrlCopy = [NSMutableString stringWithString:youtubePath];
    NSLog(@"youtube URL: %@",videoUrlCopy);
    
    NSString *vID =  [videoUrlCopy lastPathComponent];
    NSLog(@"youtube video ID: %@", vID);
    /*
    //NSDictionary *playerVars = @{
                                 @"playsinline" : @1
                                 };
    */

    youtubePlayerView.delegate = self;
    [contentView addSubview:youtubePlayerView];
    [youtubePlayerView loadWithVideoId: vID];
    //[youtubePlayerView loadWithVideoId:vID playerVars:playerVars];
    [youtubePlayerView playVideo];
    
}

- (void)loadVimeoVideoFromMultimedia: (Multimedia *)media InView:(UIView *)contentView
{
    /*
    //NSLog(@"is vimeo video");
    NSString * vimeoPath = [media getMediaPath];
    
    // format vimeo url for YTVimeoExtractor
    NSMutableString *videoUrlCopy = [NSMutableString stringWithString:vimeoPath];
    NSLog(@"vimeo URL: %@",videoUrlCopy);
    
    NSString *vID =  [videoUrlCopy lastPathComponent];
    NSLog(@"vimeo video id: %@", vID);
    
    NSString *vimeoURL = [NSString stringWithFormat:@"http://vimeo.com/%@", vID];
    NSLog(@"vimeoURL: %@", vimeoURL);
    
    [YTVimeoExtractor fetchVideoURLFromURL:vimeoURL
                                   quality:YTVimeoVideoQualityMedium
                         completionHandler:^(NSURL *videoURL, NSError *error, YTVimeoVideoQuality quality) {
                             if (error) {
                                 // handle error
                                 NSLog(@"Video URL: %@", [videoURL absoluteString]);
                             } else {
                                 // run player
                                 self.player = [[MPMoviePlayerController alloc] initWithContentURL:videoURL];
                                 
                                 [self presentMoviePlayerViewControllerAnimated:self.player];
                                 [self.player setControlStyle:MPMovieControlStyleEmbedded];
                                 [self.player.view setFrame:CGRectMake(0, 0, self.view.frame.size.width, self.view.frame.size.height-44)];
                                 //                 [spinner stopAnimating];
                                 [self.player play];
                                 
                                 [self.view addSubview:self.player.view];
                             }
                         }];
     */
}

- (void)loadUploadedVideoFromMultimedia
{
    
}

- (void)loadLocalVideoFromMultimedia
{
    
}


- (void)loadSingleView
{
//    NSLog(@"loadSingleView");
    [super viewDidLoad];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleNetworkChange:) name:kReachabilityChangedNotification object:nil];
    
    [self.navigationController setNavigationBarHidden:NO animated:YES];
    [self.navigationController setToolbarHidden:NO animated:NO];
    
//    NSLog(@"received selectedMediaURL: %@", [self.selectedMedia getMediaPath]);
    NSURL *selectedMediaURL;
    
    if(!self.customCamera){
        
        NSString *fullImageURL = [[self.selectedMedia getMediaPath] stringByReplacingOccurrencesOfString:@"preview_" withString:@""];
//        NSLog(@"fullImageURL: %@", fullImageURL);
        selectedMediaURL = [NSURL URLWithString:fullImageURL];
        
        // YOUTUBE VIDEO
        
        if ([self.selectedMedia isVideo] && self.selectedMedia.videoSourceType == YOUTUBE) {
            [spinner stopAnimating];
            self.playerView = [[YTPlayerView alloc] initWithFrame:CGRectMake(0, 0, _screenWidth, _screenHeight)];
            self.playerView.delegate = self;
            [self.view addSubview:self.playerView];
            
            [self.view bringSubviewToFront:spinner];
            
            //get youtube video ID
            NSMutableString *videoUrlCopy = [NSMutableString stringWithString:[selectedMediaURL absoluteString]];
//            NSLog(@"youtube URL: %@",videoUrlCopy);
            
            NSString *vID =  [videoUrlCopy lastPathComponent];
//            NSLog(@"youtube video ID: %@", vID);
            NSDictionary *playerVars = @{
                                         @"playsinline" : @1
                                         };
            [self.playerView loadWithVideoId:vID playerVars:playerVars];
            [self.playerView playVideo]; //autoplay doesn't work
            
        }
        
        // VIMEO VIDEO
        
        else if([self.selectedMedia isVideo] && self.selectedMedia.videoSourceType == VIMEO){
//            NSLog(@"is vimeo video");
            
            // format vimeo url for YTVimeoExtractor
            NSMutableString *videoUrlCopy = [NSMutableString stringWithString:[selectedMediaURL absoluteString]];
//            NSLog(@"vimeo URL: %@",videoUrlCopy);
            
            NSString *vID =  [videoUrlCopy lastPathComponent];
//            NSLog(@"vimeo video id: %@", vID);
            
            NSString *vimeoURL = [NSString stringWithFormat:@"http://vimeo.com/%@", vID];
//            NSLog(@"vimeoURL: %@", vimeoURL);
            
            [YTVimeoExtractor fetchVideoURLFromURL:vimeoURL
                                           quality:YTVimeoVideoQualityMedium
                                 completionHandler:^(NSURL *videoURL, NSError *error, YTVimeoVideoQuality quality) {
                                     if (error) {
                                         // handle error
                                         NSLog(@"Video URL: %@", [videoURL absoluteString]);
                                     } else {
                                         // run player
                                         self.player = [[MPMoviePlayerController alloc] initWithContentURL:videoURL];
                                         
                                         [self presentMoviePlayerViewControllerAnimated:self.player];
                                         [self.player setControlStyle:MPMovieControlStyleEmbedded];
                                         [self.player.view setFrame:CGRectMake(0, 0, self.view.frame.size.width, self.view.frame.size.height-44)];
                                         //                 [spinner stopAnimating];
                                         [self.player play];
                                         
                                         [self.view addSubview:self.player.view];
                                     }
                                 }];
            
        }
        
        // UPLOADED VIDEO
        
        else if([self.selectedMedia isVideo] && self.selectedMedia.videoSourceType == UPLOADED ){
            
            self.player = [[MPMoviePlayerController alloc] initWithContentURL:selectedMediaURL];
            [[NSNotificationCenter defaultCenter] addObserver:self
                                                     selector:@selector(MPMoviePlayerPlaybackStateDidChange:)
                                                         name:MPMoviePlayerPlaybackStateDidChangeNotification
                                                       object:nil];
            if([self.selectedMedia videoRotation] != 90){
                // play non-rotated video
                self.player = [[MPMoviePlayerController alloc] initWithContentURL:selectedMediaURL];
                [self presentMoviePlayerViewControllerAnimated:self.player];
                [self.player.view setFrame:CGRectMake(0, 0, 320, self.view.frame.size.height - 44)];
                [self.view addSubview:self.player.view];
                [self.player play];
                [self.view bringSubviewToFront:spinner];
            }else{
                // play rotated video
                [self.player.view setFrame:CGRectMake(0, 0, self.view.frame.size.height, self.view.frame.size.width)];
                NSLog(@"self.view.frame.size %f x %f", self.view.frame.size.width, self.view.frame.size.height);
                //            [self.player.view setBounds:CGRectMake(0,0,400.0, 320.0)];
                self.player.controlStyle = MPMovieControlStyleEmbedded;
                self.player.view.transform = CGAffineTransformMakeRotation(M_PI_2*3);
                self.player.view.center = self.view.center;
                [self.view addSubview:self.player.view];
                [self.player play];
                [self.view bringSubviewToFront:spinner];
            }
            
        }else{
            
            // IMAGE
//            NSLog(@"adding image");
            // load image in view
            NSData *imageData = [[NSData alloc] initWithContentsOfURL:(selectedMediaURL)];
            UIImage *image = [[UIImage alloc] initWithData:imageData];
//            NSLog(@"screen dimensions: %f x %f", _screenWidth, _screenHeight);
//            NSLog(@"frame size: %f x %f", self.mediaView.frame.size.width, self.mediaView.frame.size.height);
//            NSLog(@"image dimensions: %f x %f", image.size.width, image.size.height);

            [spinner stopAnimating];
            self.mediaView.contentMode = UIViewContentModeScaleAspectFit;
            self.mediaView.clipsToBounds = YES;
            [self.mediaView setImage:image];
        }
        
        imageID = [self.selectedMedia getID];
        NSLog(@"selectedImageID %i", imageID);
        
        
        deleteImageURLString = [NSString stringWithFormat:[imagesBaseURL stringByAppendingFormat:@"/%i?auth_token=%@", imageID, auth_token]];
        
    }else if([self.selectedMedia isVideo]) {
        
        NSLog(@"trying to load local video");
        // load local video
        self.player = [[MPMoviePlayerController alloc] initWithContentURL:[self.selectedMedia getMediaURL]];
        
        //NSLog(@"string of URL %@", [self.selectedMedia getMediaPath]);
        
        NSLog(@"URL: %@", [self.selectedMedia getMediaURL]);
        
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(MPMoviePlayerPlaybackStateDidChange:)
                                                     name:MPMoviePlayerPlaybackStateDidChangeNotification
                                                   object:nil];
        
        self.player = [[MPMoviePlayerController alloc] initWithContentURL:[self.selectedMedia getMediaURL]];
        [self presentMoviePlayerViewControllerAnimated:self.player];
        [self.player.view setFrame:CGRectMake(0, 0, 320, self.view.frame.size.height - 44)];
        [self.view addSubview:self.player.view];
        [self.player play];
        [spinner stopAnimating];
        
        
    }else{
//        NSLog(@"LOADING FROM CUSTOM CAMERA");
        // from customCamera - selected an image
        self.mediaView.contentMode = UIViewContentModeScaleAspectFit;
        self.mediaView.clipsToBounds = YES;
//        NSLog(@"screen dimensions: %f x %f", _screenWidth, _screenHeight);
//        NSLog(@"frame size: %f x %f", self.mediaView.frame.size.width, self.mediaView.frame.size.height);
//         NSLog(@"image dimensions: %f x %f", self.selectedMedia.getView.image.size.width, self.selectedMedia.getView.image.size.height);
        [self.mediaView setImage:self.selectedMedia.getView.image];

        [spinner stopAnimating];
    }
    
}


- (void)viewDidLoad
{
    mainDelegate = (AppDelegate *)[[UIApplication sharedApplication]delegate];
    auth_token = [mainDelegate.keychainItem objectForKey:(__bridge id)(kSecAttrType)];

//    NSLog(@"in mediaPreviewViewController with self.selectedMedia isVideo %s", [self.selectedMedia isVideo] ? "yes": "no");
    [super viewDidLoad];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleNetworkChange:) name:kReachabilityChangedNotification object:nil];
    
    [self.navigationController setNavigationBarHidden:NO animated:YES];
    [self.navigationController setToolbarHidden:NO animated:NO];
    
    CGRect screenRect = [[UIScreen mainScreen] bounds];
    _screenWidth = screenRect.size.width;
    _screenHeight = screenRect.size.height;
    //setup
    self.standardFrame = CGRectMake(0, 0, self.scrollViewWidth, self.scrollViewHeight);
    
    //Condition to load swipe view or single view
    Boolean containsYoutubeVimeo = NO;
    
    for (Multimedia * media in self.multimediaList) {
        if (media.isVideo &&
            (media.videoSourceType == VIMEO || media.videoSourceType == YOUTUBE))
        {
            containsYoutubeVimeo = YES;
//            NSLog(@"%u", media.videoSourceType);
        }
    }
    
    if (containsYoutubeVimeo || self.customCamera) {
        [self loadSingleView];
    } else {
        [self loadMultimedia];
    }

}

- (void)playerViewDidBecomeReady:(YTPlayerView *)playerView{
//    NSLog(@"youtube player is ready");
    [[NSNotificationCenter defaultCenter] postNotificationName:@"Playback started" object:self];
    [self.playerView playVideo];
}

- (void)playerView:(YTPlayerView *)playerView didChangeToState:(YTPlayerState)state {
    switch (state) {
        case kYTPlayerStatePlaying:
            NSLog(@"Started playback");
            break;
        case kYTPlayerStatePaused:
            NSLog(@"Paused playback");
            break;
        default:
            break;
    }
}

- (void)MPMoviePlayerPlaybackStateDidChange:(NSNotification *)notification
{
    if (self.player.playbackState == MPMoviePlaybackStatePlaying)
    { //playing
       [spinner stopAnimating];
    }
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark deleteMedia
-(IBAction)deleteMediaClick:(id)sender{
    UIActionSheet *actionSheet;
    if(!self.customCamera){
        actionSheet = [[UIActionSheet alloc] initWithTitle:nil delegate:self cancelButtonTitle:@"Cancel" destructiveButtonTitle:@"Delete" otherButtonTitles: nil];
    }else{
        [self dismissViewControllerAnimated:YES completion:^(){
            self.onDismiss(self, YES); // let StepViewController know an image was deleted
        }];
    }
    
    [actionSheet showInView:self.view];
}

// detect which button is clicked in actionsheet (delete image / cancel)
- (void)actionSheet:(UIActionSheet *)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex
{
    
    if (buttonIndex == actionSheet.cancelButtonIndex) return;
    if (buttonIndex == actionSheet.destructiveButtonIndex)
    {
            NSString *deleteMessage;
            if([self.selectedMedia isVideo] == false){
                deleteMessage = [NSString stringWithFormat: @"Are you sure you want to delete this image?"];
            }else{
                deleteMessage = [NSString stringWithFormat: @"Are you sure you want to delete this video?"];
            }
            UIAlertView *alert;
                if([self.selectedMedia isVideo]){
                    alert = [[UIAlertView alloc]initWithTitle:@"Delete Video" message: deleteMessage delegate:nil cancelButtonTitle:@"Cancel" otherButtonTitles:@"Delete", nil];
                }else{
                    alert = [[UIAlertView alloc]initWithTitle:@"Delete Image" message: deleteMessage delegate:nil cancelButtonTitle:@"Cancel" otherButtonTitles:@"Delete", nil];
                }
            
            alert.delegate = self;
            [alert show];
            
        }
}

-(void)alertView: (UIAlertView*) alertView clickedButtonAtIndex:(NSInteger)buttonIndex
{
    switch(buttonIndex)
    {
        case 0:
            // cancel
            break;
        case 1:
        {
            // delete image
            [self deleteImage];
            [self dismissViewControllerAnimated:YES completion:^(){
                self.onDismiss(self, YES); // let StepViewController know an image was deleted
            }];
            break;
        }
    }
}

/* deleteMedia - delete the image from BIP
 */

-(void)deleteImage{
    if(!self.customCamera) {
        //    NSLog(@"deleting image at URL %@", imageURL);
        NSURL *deleteImageURL = [NSURL URLWithString:deleteImageURLString];
        
        // send JSON request
        NSMutableURLRequest *request = [NSMutableURLRequest new];
        [request setURL:deleteImageURL];
        [request setHTTPMethod:@"DELETE"];
        
        // receive JSON response
        NSURLResponse * response = nil;
        NSData * receivedData = nil;
        
        NSError *error = [[NSError alloc] init];
        
        receivedData = [NSMutableData data];
        receivedData = [NSURLConnection sendSynchronousRequest:request returningResponse:&response error:&error];
        
        NSString *jsonString = [[NSString alloc] initWithData:receivedData encoding:NSUTF8StringEncoding];
        
        NSLog(@"deleted image! %@", jsonString);
    }
}


-(void)deleteVideo{
    //    NSLog(@"deleting image at URL %@", imageURL);
    NSURL *deleteVideoURL = [NSURL URLWithString:deleteImageURLString];
    
    // send JSON request
    NSMutableURLRequest *request = [NSMutableURLRequest new];
    [request setURL: deleteVideoURL];
    [request setHTTPMethod:@"DELETE"];
    
    // receive JSON response
    NSURLResponse * response = nil;
    NSData * receivedData = nil;
    
    NSError *error = [[NSError alloc] init];
    
    receivedData = [NSMutableData data];
    receivedData = [NSURLConnection sendSynchronousRequest:request returningResponse:&response error:&error];
    
    NSString *jsonString = [[NSString alloc] initWithData:receivedData encoding:NSUTF8StringEncoding];
    
    //    NSLog(@"deleted video!");
}



#pragma mark closePreview
-(IBAction)closePreview{
    //    NSLog(@"in closePreview");
    [[NSNotificationCenter defaultCenter] postNotificationName:@"MediaPreviewDismissed" object:nil];
    [self dismissViewControllerAnimated:YES completion:^(){
        [self.player stop];
        self.onDismiss(self, NO);
    }];
}

- (void) handleNetworkChange:(NSNotification *)notice
{
    if([ReachabilityManager isReachable]){
        internetAvailable = YES;
    }else{
        NoInternetViewController *nivc =[self.storyboard instantiateViewControllerWithIdentifier:@"NoInternet"];
        if(internetAvailable == YES){
            [self presentViewController:nivc animated:YES completion:^{
            }];
        }
        internetAvailable = NO;
    }
}


@end
