//
//  CameraViewController.h
//  BiP
//
//  Created by Amber Meighan on 1/20/15.
//  Copyright (c) 2015 LLK. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <CoreMotion/CoreMotion.h> //test
#import "PBJVision.h"

@interface CameraViewController : UIViewController <PBJVisionDelegate>
@property (strong, nonatomic) IBOutlet UIView *frameForCapture;
@property (strong, nonatomic) IBOutlet UIButton *photo;
@property (strong, nonatomic) IBOutlet UIScrollView *scrollView;
@property (strong, nonatomic) IBOutlet UIButton *gallery;
@property (strong, nonatomic) IBOutlet UIButton *video;
@property (strong, nonatomic) IBOutlet UIBarButtonItem *upload;
@property NSMutableArray *media;
@property NSMutableArray *assets;

//- (IBAction)capture:(id)sender;
- (void) deleteMedia;
- (IBAction)selectLocalMedia:(id)sender;

//Custom orientations the device can be in, using accelerometer data.
//LANDSCAPE_LEFT,LANDSCAPE_RIGHT, and PORTRAIT used to signal changes to said orientation.
//NO_CHANGE used to signal no change to current orientation
typedef enum {
    LANDSCAPE_LEFT,
    LANDSCAPE_RIGHT,
    PORTRAIT,
    NO_CHANGE
} OrientationByAccelerometer;

typedef enum {
    CAMERA,
    VIDEO_NOT_RECORDING,
    VIDEO_IS_RECORDING
} MediaCaptureStates;


@end

