//
//  CameraViewController.m
//  BiP
//
//  Created by Amber Meighan on 1/20/15.
//  Copyright (c) 2015 LLK. All rights reserved.
//

#import "CameraViewController.h"
#import "PBJVision.h"
#import "Multimedia.h"
#import "Constants.h"
#import "WSAssetPicker.h" //# for adding images
#import "MediaPreviewViewController.h"
#import "EditStepViewController.h"
#import "NoInternetViewController.h"
#import "Reachability.h"
#import "ReachabilityManager.h"
#import <AVFoundation/AVFoundation.h> //for camera and video
#import <AssetsLibrary/AssetsLibrary.h> //for camera and video
#import <CoreMedia/CoreMedia.h> //for video
#import <MediaPlayer/MediaPlayer.h> //for video
#import <MobileCoreServices/MobileCoreServices.h> //for video
#import <QuartzCore/QuartzCore.h> //for video
#import <AudioToolbox/AudioToolbox.h> //for making sounds and stuff

@interface CameraViewController () <WSAssetPickerControllerDelegate>
@property (strong, nonatomic) PBJVision *camera;
@property AVCaptureSession *session;
@property AVCaptureStillImageOutput *stillImage;
@property NSDictionary *imageDimensions;
@property int selectedImagePosition;
@property (strong, atomic) ALAssetsLibrary* library;
@property ALAssetsGroup *album;
@property UIImageView *tappedImage;
@property (strong, nonatomic) ALAssetsLibrary *assetsLibrary;

//for accelerometer
@property CMMotionManager *motionManager; //For accelerometer
@property OrientationByAccelerometer currentOrientationByAccelerometer;
@property MediaCaptureStates currentCaptureState;

//for timer
@property int currentSeconds;
@property int currentMinutes;
@property NSTimer * timer;

//for video
@property NSURL * videoPathURL;

//outlets
@property (weak, nonatomic) IBOutlet UIButton *centerButtonOutlet;
@property (weak, nonatomic) IBOutlet UIButton *rightButtonOutlet;
@property (weak, nonatomic) IBOutlet UILabel *timerOutlet;

@end

@implementation CameraViewController
{
    NSString* albumName;
    BOOL internetAvailable;
    //UIImage * playIcon;
}

#pragma mark Setup/UI Methods

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.navigationController.navigationBar.topItem.title = @"";
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(deleteMedia)
                                                 name:@"DeleteImage"
                                               object:nil];
    
    self.library = [[ALAssetsLibrary alloc] init];
    
    [self.library enumerateGroupsWithTypes:ALAssetsGroupAlbum
                                usingBlock:^(ALAssetsGroup *group, BOOL *stop) {
                                    if ([[group valueForProperty:ALAssetsGroupPropertyName] isEqualToString:albumName]) {
                                        self.album = group;
                                    } else {
                                        [self.library addAssetsGroupAlbumWithName:albumName resultBlock:^(ALAssetsGroup *group)
                                         {
//                                             NSLog(@"Added Album");
                                         }
                                                                     failureBlock:^(NSError *error)
                                         {NSLog(@"Failed to add block");}
                                         ];
                                    }
                                }
                              failureBlock:^(NSError* error) {
                              }];
    self.media = [[NSMutableArray alloc] init];
    self.assets = [[NSMutableArray alloc] init];
}

- (void)setup
{
    //Set up preview
    AVCaptureVideoPreviewLayer *previewLayer = [[PBJVision sharedInstance] previewLayer];
    previewLayer.frame = self.frameForCapture.bounds;
    previewLayer.videoGravity = AVLayerVideoGravityResizeAspectFill;
    [self.frameForCapture.layer addSublayer:previewLayer];

    //Set up camera
    self.camera = [PBJVision sharedInstance];
    self.camera.delegate = self;
    [self.camera setCameraMode:PBJCameraModePhoto];
    [self.camera setCameraDevice:PBJCameraDeviceBack];
    [self.camera setAutoUpdatePreviewOrientation:NO];
    [self.camera setFocusMode:PBJFocusModeContinuousAutoFocus];
    [self.camera setFlashMode:PBJFlashModeAuto];
    [self.camera setThumbnailEnabled:YES];
    [self.camera setOutputFormat:PBJOutputFormatPreset];
    [self.camera setAudioCaptureEnabled: NO]; //for video
    
    //Set up button proportions
    [[self.photo imageView] setContentMode:UIViewContentModeScaleAspectFit];
    [self.photo setImageEdgeInsets:UIEdgeInsetsMake(8, 8, 8, 8)];
    [[self.gallery imageView] setContentMode:UIViewContentModeScaleAspectFit];
    [self.gallery setImageEdgeInsets:UIEdgeInsetsMake(10, 10, 10, 10)];
    [[self.video imageView] setContentMode:UIViewContentModeScaleAspectFit];
    [self.video setImageEdgeInsets:UIEdgeInsetsMake(5, 15, 5, 15)];
    
    [self.frameForCapture addSubview:self.photo];
    [self.frameForCapture addSubview:self.gallery];
    [self.frameForCapture addSubview:self.video];
    [self.frameForCapture addSubview:self.scrollView];
    [self.frameForCapture addSubview:self.timerOutlet];
    [self.camera setAutoFreezePreviewDuringCapture:YES];
    
    [self.camera startPreview];
    
    //initialize the currentOrientation to be portrait
    self.currentOrientationByAccelerometer = PORTRAIT;
    self.currentCaptureState = CAMERA;
    
    //initialize pictures on center and right buttons
    UIImage * photo = [UIImage imageNamed:@"ic_action_camera.png"];
    UIImage * video = [UIImage imageNamed:@"ic_action_video.png"];
    
    [self.rightButtonOutlet setImage:video forState:UIControlStateNormal];
    [self.centerButtonOutlet setImage:photo forState:UIControlStateNormal];
    
    //initialize timer to be hidden
    [self.timerOutlet setHidden: YES];
    
    //initialize scroller dimentions
    self.imageDimensions = @{@"width": [NSNumber numberWithInt:45], @"height": [NSNumber numberWithInt:45]};
    albumName = @"Build in Progress";
    if(self.media.count == 0){[[self navigationItem] setRightBarButtonItem:nil];}
    
    //Starting accelerometer updates
    [self startAccelerometerOrientationUpdates];
    

}


-(void)viewWillAppear:(BOOL)animated
{
    NSLog(@"viewWillAppear");
    [self setup];
    [self addImagesToScrollView];

}


-(void) viewWillDisappear:(BOOL)animated
{
    [self stopAccelerometerOrientationUpdates];
}

#pragma mark Accelerometer

-(void) startAccelerometerOrientationUpdates
{
    //changing device orientation using accelerometer
    
    self.motionManager = [[CMMotionManager alloc] init];
    self.motionManager.accelerometerUpdateInterval = .5;
    
    const double PORTRAIT_ROTATION = 0;
    const double LANDSCAPE_LEFT_ROTATION = M_PI_2;
    const double LANDSCAPE_RIGHT_ROTATION = -M_PI_2;
    
    void (^orientationChangedTo)(OrientationByAccelerometer, double, double) =
    ^(OrientationByAccelerometer orientation, double x, double y) {
        
        self.currentOrientationByAccelerometer = orientation;
        
        double rotationRadians;
        
        //NSLog(@"x: %f, y: %f", x, y);
        if (orientation == LANDSCAPE_LEFT){
            rotationRadians = LANDSCAPE_LEFT_ROTATION;
            [self.camera setCameraOrientation:PBJCameraOrientationLandscapeRight];
//            NSLog(@"Landscape Left");
        } else if (orientation == LANDSCAPE_RIGHT) {
            rotationRadians = LANDSCAPE_RIGHT_ROTATION;
            [self.camera setCameraOrientation:PBJCameraOrientationLandscapeLeft];
//            NSLog(@"Landscape Right");
        } else if (orientation == PORTRAIT) {
            rotationRadians = PORTRAIT_ROTATION;
            [self.camera setCameraOrientation:PBJCameraOrientationPortrait];
//            NSLog(@"Portrait");
        } else {
            rotationRadians = PORTRAIT_ROTATION; //default to portrait
            [self.camera setCameraOrientation:PBJCameraOrientationPortrait];
//            NSLog(@"No Change");
        }
        
        [self.photo imageView].transform = CGAffineTransformMakeRotation(rotationRadians);
        [self.gallery imageView].transform = CGAffineTransformMakeRotation(rotationRadians);
        [self.video imageView].transform = CGAffineTransformMakeRotation(rotationRadians);
        
        
        //Keeps timer in position when rotated
        //12 = (timerWidth - timerHeight)/2
        int SHIFT;
        if (rotationRadians > 0) { // == -M_PI_2, landscape right
            SHIFT = -12;
        } else if (rotationRadians < 0) {
            SHIFT = 12;
        } else {
            SHIFT = 0;
        }
        
        //Rotating timer
        CGAffineTransform transformShift = CGAffineTransformMakeTranslation(SHIFT, SHIFT);
        CGAffineTransform transformRotate = CGAffineTransformMakeRotation(rotationRadians);
        self.timerOutlet.transform = CGAffineTransformConcat(transformShift, transformRotate);
    };
    
    //setup accelerometer updates
    if ([self.motionManager isAccelerometerAvailable]){
        NSOperationQueue *queue = [[NSOperationQueue alloc] init];
        [self.motionManager startAccelerometerUpdatesToQueue:queue
                                                 withHandler:^(CMAccelerometerData *accelerometerData, NSError *error){
                                                     dispatch_async(dispatch_get_main_queue(), ^{
                                                         
                                                         //interpreting accelerometer data
                                                         
                                                         double x = accelerometerData.acceleration.x;
                                                         double y = accelerometerData.acceleration.y;
                                                         
                                                         //buffer for better handling
                                                         if (fabs(x) + fabs(y) >= .5 &&
                                                             fabs(x - y) >= .1
                                                             ){
                                                             
                                                             //landscape
                                                             if (fabs(x) > fabs(y)){
                                                                 //landscape right
                                                                 if (x > 0) {
                                                                     orientationChangedTo(LANDSCAPE_RIGHT, x, y);
                                                                     //landscape left
                                                                 } else {
                                                                     orientationChangedTo(LANDSCAPE_LEFT, x, y);
                                                                 }
                                                                 
                                                                 //portrait
                                                             } else {
                                                                 orientationChangedTo(PORTRAIT, x, y);
                                                             }
                                                             //no change
                                                         } else {
                                                             orientationChangedTo(NO_CHANGE, x, y);
                                                         }
                                                         
                                                     });
                                                 }];
        
    }
}

-(void) stopAccelerometerOrientationUpdates
{
    //Stops accelerometer updates as no longer needed
    [[self motionManager] stopAccelerometerUpdates];
}


//Used to detect orientation with default UIDeviceOrientation settings
//Fails when rotation lock is enabled
/*
 Changes made when the orientation of the device is changed.
 
- (void)orientationChanged{
    
    if([[UIDevice currentDevice] orientation] == UIDeviceOrientationPortrait){
        [self.photo imageView].transform = CGAffineTransformMakeRotation(0);
        
        [self.gallery imageView].transform = CGAffineTransformMakeRotation(0);
        
        [self.video imageView].transform = CGAffineTransformMakeRotation(0);
        
//        [self.camera setCameraOrientation:PBJCameraOrientationPortrait];

    } else if ([[UIDevice currentDevice] orientation] == UIDeviceOrientationLandscapeLeft){
        [self.photo imageView].transform = CGAffineTransformMakeRotation(M_PI_2);
        
        [self.gallery imageView].transform = CGAffineTransformMakeRotation(M_PI_2);
        
        [self.video imageView].transform = CGAffineTransformMakeRotation(M_PI_2);
        
//        [self.camera setCameraOrientation:PBJCameraOrientationLandscapeLeft];
        
    } else if ([[UIDevice currentDevice] orientation] == UIDeviceOrientationLandscapeRight){
        [self.photo imageView].transform = CGAffineTransformMakeRotation(-M_PI_2);
        
        [self.gallery imageView].transform = CGAffineTransformMakeRotation(-M_PI_2);
        
        [self.video imageView].transform = CGAffineTransformMakeRotation(-M_PI_2);
        
//        [self.camera setCameraOrientation:PBJCameraOrientationLandscapeRight];
    }
}
*/


#pragma mark Buttons

//NOTE:
//self.photo refers to center button
//self.video refers to right button
//To implement video/camera switching buttons, only functions of, images, and colors of buttons were changed, not actual buttons, so images may represent different

//TODO - promput user to enable camera/ microphone
//CENTER BUTTON
- (IBAction)centerButton:(id)sender
{
    
    //TODO - use [self.camera isRecording] check
    if (self.currentCaptureState == CAMERA){
        
        [self.camera capturePhoto];
        NSLog(@"currentCaptureState: No change");
        
    } else if (self.currentCaptureState == VIDEO_NOT_RECORDING){
        if (![self.camera isRecording]){
            
            //Switch to video mode
            [self.camera setCameraMode:PBJCameraModeVideo];
            [self.camera setAudioCaptureEnabled: YES];
            [self.camera setAutoFreezePreviewDuringCapture:NO];
            [self.camera startVideoCapture];
            self.currentCaptureState = VIDEO_IS_RECORDING;
            NSLog(@"currentCaptureState: Video is recording");
            
            //changing color to red when recording
            UIColor * red = [UIColor redColor];
            [self.centerButtonOutlet setBackgroundColor:red];
            
            //starting timer
            [self startTimer];
            
            //Lock orientation, doesn't change while recording
            [self stopAccelerometerOrientationUpdates];
            
            

        }
        
    } else if (self.currentCaptureState == VIDEO_IS_RECORDING){
        if ([self.camera isRecording]){
            
            //Swith to camera mode
            [self.camera endVideoCapture];
            [self.camera setAudioCaptureEnabled: YES];
            [self.camera setAutoFreezePreviewDuringCapture:YES];
            [self.camera setCameraMode:PBJCameraModePhoto];
            self.currentCaptureState = VIDEO_NOT_RECORDING;
            NSLog(@"currentCaptureState: Video not recording");
            
            //changes color back to blue when not recording
            UIColor * lightBlue = [UIColor colorWithRed:.25490 green:.66667 blue:.847059 alpha:1.0];
            [self.centerButtonOutlet setBackgroundColor:lightBlue];
            
            //stopping timer
            [self stopTimer];
            
            //Unlock orientation after recording
            [self startAccelerometerOrientationUpdates];
            
        }
    }
    
    //for playing sounds
    AudioServicesPlaySystemSound(0x450);
        
}

//RIGHT BUTTON
- (IBAction)rightButton:(id)sender
{
    if (self.currentCaptureState == CAMERA){ //button shows video
        
        //switching images
        UIImage * photo = [UIImage imageNamed:@"ic_action_camera.png"];
        UIImage * video = [UIImage imageNamed:@"ic_action_video.png"];
        
        [self.rightButtonOutlet setImage:photo forState:UIControlStateNormal];
        [self.centerButtonOutlet setImage:video forState:UIControlStateNormal];
        
        //changing capture state
        self.currentCaptureState = VIDEO_NOT_RECORDING;
        NSLog(@"currentCaptureState: Video not recording");
        
        
    } else if (self.currentCaptureState == VIDEO_NOT_RECORDING){ //button shows camera
        
        //switching images
        UIImage * photo = [UIImage imageNamed:@"ic_action_camera.png"];
        UIImage * video = [UIImage imageNamed:@"ic_action_video.png"];
        
        [self.rightButtonOutlet setImage:video forState:UIControlStateNormal];
        [self.centerButtonOutlet setImage:photo forState:UIControlStateNormal];
        
        //changing capture state
        self.currentCaptureState = CAMERA;
        NSLog(@"currentCaptureState: Camera");
        
    } else { //button shows camera, video is being recorded
        //do nothing, cannot switch while recording
    }
    
    AudioServicesPlayAlertSound(kSystemSoundID_Vibrate);
    
}

//LEFT BUTTON
- (IBAction)selectLocalMedia:(id)sender
{

    if (self.currentCaptureState != VIDEO_IS_RECORDING){
        self.assetsLibrary = [Constants defaultAssetsLibrary];
        WSAssetPickerController *picker = [[WSAssetPickerController alloc] initWithAssetsLibrary:[Constants defaultAssetsLibrary]];
        picker.delegate = self;
        [self presentViewController:picker animated:YES completion:NULL];
    } else {
        //do nothing, must finish recording first
    }
    
}


#pragma mark Timer

- (void)startTimer
{
    //re-initializing time to 00:00
    self.currentSeconds = 0;
    self.currentMinutes = 0;
    
    //creates and fires timer
    self.timer = [NSTimer scheduledTimerWithTimeInterval:1.0 target:self selector:@selector(updateTimer) userInfo:nil repeats:YES];
    [self.timer fire];
    
    //makes timer visible
    [self.timerOutlet setHidden: NO];
    
}

- (void)updateTimer
{
    
    //create string that will be displayed
    NSString * secondsString;
    NSString * minutesString;
    
    if (self.currentSeconds <= 9){
        secondsString = [NSString stringWithFormat:@":0%i", self.currentSeconds];
    } else {
        secondsString = [NSString stringWithFormat:@":%i", self.currentSeconds];
    }
    
    if (self.currentMinutes <= 9) {
        minutesString = [NSString stringWithFormat:@"0%i", self.currentMinutes];
    } else {
        minutesString = [NSString stringWithFormat:@"%i", self.currentMinutes];
    }
    
    NSString * timerString = [minutesString stringByAppendingString: secondsString];
    [self.timerOutlet setText: timerString];
    
    //increment seconds by 1, rollover to minutes
    self.currentSeconds++;
    
    if (self.currentSeconds >= 60){
        self.currentMinutes++;
        self.currentSeconds = 0;
    }
    
}

- (void)stopTimer
{
    //makes timer invisible
    [self.timerOutlet setHidden: YES];
    
    //invalidates/stops timer. Reset reference to nil (safety precaution)
    [self.timer invalidate];
    self.timer = nil;
    
    //re-initialize time to 0.
    self.currentSeconds = 0;
    self.currentMinutes = 0;
}


#pragma mark WSAssetPickerControllerDelegate Methods

- (void)assetPickerControllerDidCancel:(WSAssetPickerController *)sender
{
    // Dismiss the WSAssetPickerController.
    NSLog(@"dismissed assetPicker");
    
    // re-add notification observers
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(keyboardWasShown:)
                                                 name:UIKeyboardDidShowNotification object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(keyboardWillBeHidden:)
                                                 name:UIKeyboardWillHideNotification object:nil];
    
    [self dismissViewControllerAnimated:YES completion:NULL];
}

- (void)assetPickerController:(WSAssetPickerController *)sender didFinishPickingMediaWithAssets:(NSArray *)assets
{
    
    // Dismiss the WSAssetPickerController.
    [self dismissViewControllerAnimated:YES completion:^{
        NSLog(@"dismissed assetPickerController");
        
        // re-add notification observers
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(keyboardWasShown:)
                                                     name:UIKeyboardDidShowNotification object:nil];
        
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(keyboardWillBeHidden:)
                                                     name:UIKeyboardWillHideNotification object:nil];
        
        
        // add thumbnails to the view while the assets are being uploaded
        for (ALAsset *asset in assets) {
            Multimedia *media = [[Multimedia alloc]init];
            [self.assets addObject:asset];
            
            //[asset ]

            // add image to scrollView
            UIImage *image = [[UIImage alloc] initWithCGImage:asset.defaultRepresentation.fullScreenImage];
            CGRect imageRect = {276,0,90,90};
            UIImageView *imageView = [[UIImageView alloc] initWithFrame:imageRect];
            imageView.image = image;
            imageView.contentMode = UIViewContentModeScaleAspectFill;
            
            // add play icon if necessary
            if([[asset valueForProperty:ALAssetPropertyType] isEqual:ALAssetTypeVideo]){
                [media setVideo:asset.defaultRepresentation.url];
            }
            
            [imageView setClipsToBounds:YES];
            [media setView:imageView];
            [self.media addObject:media]; //add to uploadImages
            
        }
        
        // reload contents
        NSLog(@"reloading addImagesToScrollView");
        [self addImagesToScrollView];
        
    }];
}

#pragma mark Picture
- (void)vision:(PBJVision *)vision capturedPhoto:(NSDictionary *)photoDict error:(NSError *)error
{
    NSLog(@"capturedPhoto called");
    if(error)
        return;
    
    //See PBJVision.h for reference
    
    UIImage * capturedPhoto = [photoDict objectForKey:PBJVisionPhotoImageKey]; //photoDict contains capturedPhoto
    
    CGImageRef cgi_image = [capturedPhoto CGImage]; //used in init of photoImage
    
    //Saving image with correct orientation given by accelerometer
    OrientationByAccelerometer currentOrientation = self.currentOrientationByAccelerometer;
    UIImageOrientation ui_orientation;
    
    if (currentOrientation == LANDSCAPE_LEFT){
        ui_orientation = UIImageOrientationUp;
    } else if (currentOrientation == LANDSCAPE_RIGHT){
        ui_orientation = UIImageOrientationDown;
    } else { //(currentOrientation == PORTRAIT)
        ui_orientation = UIImageOrientationRight;
    }
    
    UIImage *photoImage = [[UIImage alloc] initWithCGImage: cgi_image
                                                scale: 1.0
                                          orientation: ui_orientation];
    
    
     
    NSData *photoData = [photoDict objectForKey:PBJVisionPhotoMetadataKey];
    
    UIImageView *imageView = [[UIImageView alloc]init];
    imageView.image = photoImage;
    
    Multimedia *media = [[Multimedia alloc]init];
    [media setView:imageView];
    
    [self.media addObject:media]; //add to uploadImages
    
    [self.camera unfreezePreview];
    [self addImagesToScrollView];
    [self saveImageToAlbum:photoImage:photoData];
}




/*
 Saves image to camera roll
 */
- (void) saveImageToAlbum: (UIImage *) image: (NSData *) imageData
{
    [self.library enumerateGroupsWithTypes:ALAssetsGroupAlbum
                                usingBlock:^(ALAssetsGroup *group, BOOL *stop) {
                                    if ([[group valueForProperty:ALAssetsGroupPropertyName] isEqualToString:albumName]) {
                                        self.album = group;
                                    }
                                }
                              failureBlock:^(NSError* error) {
                                  NSLog(@"Failed to find Group Album");
                              }];
    
    //Saving images to camera roll in the correct orientation
   
    //Convert UIImageOrientation to ALAssetOrientation
    UIImageOrientation ui_orientation = image.imageOrientation;
    ALAssetOrientation al_orientation;
    
    if (ui_orientation == UIImageOrientationUp) {
        al_orientation = ALAssetOrientationUp;
    } else if (ui_orientation == UIImageOrientationDown) {
        al_orientation = ALAssetOrientationDown;
    } else { //(ui_orientation == UIImageOrientationRight)
        al_orientation = ALAssetOrientationRight;
    } //default to portrait
    
    CGImageRef img = [image CGImage];
    
    [self.library writeImageToSavedPhotosAlbum:img
                                   orientation:al_orientation
                               completionBlock:^(NSURL* assetURL, NSError* error) {
                                   if (error.code == 0) {
                                       
                                       // try to get the asset
                                       [self.library assetForURL:assetURL
                                                     resultBlock:^(ALAsset *asset) {
                                                         // assign the photo to the album
                                                         [self.album addAsset:asset];
                                                         
                                                         [self.assets addObject:asset];
                                                     }
                                                    failureBlock:^(NSError* error) {
                                                        NSLog(@"Failed to save photo to library");
                                                    }];
                                   } else {
                                   }
                               }];
    
    
}


#pragma mark Video

- (void)vision:(PBJVision *)vision capturedVideo:(NSDictionary *)videoDict error:(NSError *)error{
    
    if (error){
        return;
    }
    
    [self saveVideoToAlbum:videoDict];
}


- (void) saveVideoToAlbum : (NSDictionary *)videoDict {
    
    //Extracting video path from videoDict given by PBJVision's captureVideo
    NSString *videoPathString = [videoDict objectForKey:PBJVisionVideoPathKey];
    NSURL *videoPathURL = [NSURL URLWithString:videoPathString];
    
    //Creating thumbnail
    Multimedia *media = [[Multimedia alloc]init];
    UIImage * thumbnail = [videoDict objectForKey:PBJVisionVideoThumbnailKey];
    UIImageView *imageView = [[UIImageView alloc] init];
    imageView.image = thumbnail;
    
    //Creating an ID - arbitrary, change if needed
    int mediaID = [videoPathString intValue];//trying to make ID
    
    //Create multimedia object
    [media createMediaWithMediaID:mediaID mediaPath:videoPathString videoRotation:0];
    
    //Helps with saving to the Build in Progress album
    [self.library enumerateGroupsWithTypes:ALAssetsGroupAlbum
                                usingBlock:^(ALAssetsGroup *group, BOOL *stop) {
                                    //saves to build in progress album (i think)
                                    if ([[group valueForProperty:ALAssetsGroupPropertyName] isEqualToString:albumName]) {
                                        self.album = group;
                                    }
                                }
                              failureBlock:^(NSError* error) {
                                  NSLog(@"Failed to find Group Album");
                              }];
    
    
    
    [self.library writeVideoAtPathToSavedPhotosAlbum: videoPathURL
                                     completionBlock:^(NSURL* assetURL, NSError* error) {
                                         
                                         //setting the asset URL as the videoURL - otherwise is temporary URL that MPMoviePlayers cant seeem to read
                                         [media setVideo:assetURL];
                                         [media setView:imageView];
                                         
                                         [self.media addObject:media]; //add to uploadImages
                                         
                                         [self addImagesToScrollView];
                                         
                                         if (error.code == 0) {
                                             
                                             // try to get the asset
                                             [self.library assetForURL:assetURL
                                                           resultBlock:^(ALAsset *asset) {
                                                               // assign the video to the album
                                                               [self.album addAsset:asset];
                                                               
                                                               [self.assets addObject:asset];
                                                               
                                                               
                                                           }
                                                          failureBlock:^(NSError* error) {
                                                              NSLog(@"Failed to save video to library");
                                                          }];
                                         } else {
                                         }
                                     }];
    
}

#pragma mark Media Interaction

/*
 addImagesToScrollView- adds images from step to the scrollView
 */
- (void) addImagesToScrollView {
    
    
    // clear all images in scrollView
    NSLog(@"clear all images in scrollView");
    for(UIView *v in [self.scrollView subviews]){
        [v removeFromSuperview];
    }
    
    
    // add images
    for (int i = 0; i < [self.media count]; i++){
        
        //test, above and below line, change media to assests
        
        UIImageView *view =  [[self.media objectAtIndex:i] getView];
        if ([view isKindOfClass:[UIImageView class]])
        
        {
            NSLog(@"image %s associated with video", [[self.media objectAtIndex:i] isVideo] ? "IS": " IS NOT");
            float x = i * 3;
            x += 3 + (i * [self.imageDimensions[@"width"] integerValue]);
            
            // set size of scroller
            int imageScrollerWidth = ([self.media count]) *([self.imageDimensions[@"width"] integerValue] + 3);
            [self.scrollView setContentSize:CGSizeMake(imageScrollerWidth, [self.imageDimensions[@"height"] integerValue])];
            self.scrollView.contentOffset = CGPointZero;
            
            view.frame = CGRectMake(x,0, [self.imageDimensions[@"width"] integerValue], [self.imageDimensions[@"height"] integerValue]);
            [view setClipsToBounds:YES];
            view.contentMode = UIViewContentModeScaleAspectFill;
            
            //add play button
            
            
            if([[self.media objectAtIndex:i] isVideo]){
                UIImage * playIcon = [UIImage imageNamed:@"play_icon.png"];
                UIImage *resizedPlayIcon = [self imageWithImage:playIcon scaledToSize:CGSizeMake(25, 25)];
                UIImageView *videoOverlay =[[UIImageView alloc]initWithImage:resizedPlayIcon];
                videoOverlay.contentMode = UIViewContentModeCenter;
                videoOverlay.frame = CGRectMake(x, 0, [self.imageDimensions[@"width"] integerValue]-5.0, [self.imageDimensions[@"height"] integerValue]);
                if ([[view subviews] count] == 0){
                    [view addSubview: videoOverlay];
                }
                
                videoOverlay.center = CGPointMake(view.frame.size.width/2 , view.frame.size.height/2);
                
                NSLog(@"adding video overlay");
                
            }
            
            // add image to scrollview
            [self.scrollView addSubview:view];
            
            //NSLog(@"View subview: %@", [view subviews]);
            
            // add a tapGestureRecognizer to the view
            UITapGestureRecognizer *singleTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(imageTapped:)];
            singleTap.numberOfTapsRequired = 1;
            singleTap.numberOfTouchesRequired = 1;
            view.tag = i; // add the position of the image to the tag
            [view addGestureRecognizer:singleTap];
            [view setUserInteractionEnabled:true];
        }
    }
    
    
    // scroll to end of scrollView if there's 9 or more images
    if(self.media.count >=7 ){
        CGPoint leftOffset = CGPointMake(self.scrollView.contentSize.width - self.scrollView.bounds.size.width, 0);
        [self.scrollView setContentOffset:leftOffset animated:NO];
    } else if (self.media.count >= 1){
        [self.navigationItem setRightBarButtonItem:self.upload animated:YES];
    } else if (self.media.count == 0){[[self navigationItem] setRightBarButtonItem:nil];}

}

- (UIImage *)imageWithImage:(UIImage *)image scaledToSize:(CGSize)newSize {
    //UIGraphicsBeginImageContext(newSize);
    // In next line, pass 0.0 to use the current device's pixel scaling factor (and thus account for Retina resolution).
    // Pass 1.0 to force exact pixel size.
    UIGraphicsBeginImageContextWithOptions(newSize, NO, 0.0);
    [image drawInRect:CGRectMake(0, 0, newSize.width, newSize.height)];
    UIImage *newImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return newImage;
}

/*
 imageTapped - open up MediaPreview for selectedImage
 */
-(void)imageTapped:(UIGestureRecognizer *)gestureRecognizer{
    
    int indexTapped = (int) gestureRecognizer.view.tag;

    self.tappedImage = [self.media objectAtIndex:indexTapped];
    
    // open up media preview using the tag
    
    UIStoryboard *storyboard = [UIStoryboard storyboardWithName:@"Main" bundle:nil];
    MediaPreviewViewController *mediaPreviewVC = (MediaPreviewViewController *)[storyboard instantiateViewControllerWithIdentifier:@"MediaPreviewViewController"];
    
    mediaPreviewVC.selectedMedia = [self.media objectAtIndex:gestureRecognizer.view.tag];
    mediaPreviewVC.customCamera = YES;
    UINavigationController *navigationController = [[UINavigationController alloc] initWithRootViewController:mediaPreviewVC];
    
    //passing in whole list of multimedia objects
    mediaPreviewVC.multimediaList = self.media;
    mediaPreviewVC.currentMediaIndex = indexTapped;
    
    mediaPreviewVC.onDismiss = ^(UIViewController *sender, BOOL *didDeleteImage){
        NSLog(@"in onDismiss in EditStepViewController with didDeleteImage %s", didDeleteImage ? "YES":"NO");
        
        if(didDeleteImage){
            NSLog(@"removing deleted image");
            [self.media removeObject:self.tappedImage];
            [self.assets removeObject:[self.assets objectAtIndex:gestureRecognizer.view.tag]];
            [self addImagesToScrollView];
        }
        
        // re-add notification observers
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(keyboardWasShown:)
                                                     name:UIKeyboardDidShowNotification object:nil];
        
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(keyboardWillBeHidden:)
                                                     name:UIKeyboardWillHideNotification object:nil];
    };
    [self presentViewController:navigationController animated:YES completion:nil];
}



#pragma mark scrolling

/*
- (UIViewController *) pageViewController:(UIPageViewController *)pageViewController viewControllerAfterViewController:(UIViewController *)viewController
{
    
}

- (UIViewController *) pageViewController:(UIPageViewController *)pageViewController viewControllerBeforeViewController:(UIViewController *)viewController
{
    
}
*/


#pragma mark Other Methods


// Called when the UIKeyboardWillHideNotification is sent
- (void)keyboardWillBeHidden:(NSNotification*)aNotification
{
    UIEdgeInsets contentInsets = UIEdgeInsetsZero;
    self.scrollView.contentInset = contentInsets;
    self.scrollView.scrollIndicatorInsets = contentInsets;
}


- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
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
