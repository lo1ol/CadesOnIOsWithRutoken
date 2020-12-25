//
//  CreateFileAppDelegate.h
//  CreateFile
//
//  Created by Кондакова Татьяна Андреевна on 03.12.10.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import <UIKit/UIKit.h>

@class CreateFileViewController;

@interface CreateFileAppDelegate : NSObject <UIApplicationDelegate> {
    UIWindow *window;
    CreateFileViewController *viewController;
}

@property (nonatomic, strong) IBOutlet UIWindow *window;
@property (nonatomic, strong) IBOutlet CreateFileViewController *viewController;

@end
