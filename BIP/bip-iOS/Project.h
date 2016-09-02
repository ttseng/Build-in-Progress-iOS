//
//  Project.h
//  BiP
//
//  Created by ttseng on 12/1/14.
//  Copyright (c) 2014 LLK. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface Project : NSObject

@property NSString *title;
@property id projectID;
@property BOOL built;
@property UIImage *projectImage;
@property NSMutableArray *steps;
@property NSString *description;

-(void)createProject:(NSString*)projectTitle: (id)projectID: (NSString*)description;
-(void)addProject:(NSString*)projectTitle: (id)projectID: (NSString*)description: (BOOL)built: (UIImage *)projectImage: (NSMutableArray*)steps;

@end
