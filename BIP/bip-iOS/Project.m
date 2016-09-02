//
//  Project.m
//  BiP
//
//  Created by ttseng on 12/1/14.
//  Copyright (c) 2014 LLK. All rights reserved.
//

#import "Project.h"

@implementation Project

-(void)createProject:(NSString*)projectTitle: (id)projectID: (NSString*)description{
    self.title = projectTitle;
    self.projectID = projectID;
    self.description = description;
    self.built = false;
    self.steps = [[NSMutableArray alloc] init];
}

-(void)addProject:(NSString*)projectTitle: (id)projectID: (NSString*)description: (BOOL)built: (UIImage *)projectImage: (NSMutableArray*)steps{
    self.title = projectTitle;
    self.projectID = projectID;
    self.description = description;
    self.built = built;
    self.projectImage = projectImage;
    self.steps = steps;
}

@end