//
//  LaunchAsRoot.h
//  Sileo
//
//  Created by Amy on 27/05/2021.
//  Copyright © 2021 Amy While. All rights reserved.
//

#ifndef LaunchAsRoot_h
#define LaunchAsRoot_h

#import <Foundation/Foundation.h>
#import <Security/Authorization.h>

@protocol LaunchAsRootProtocol
-(id)init;
-(NSArray *)launchAsRoot:(NSArray *)args launchPath:(NSString *)launchPath;
@end

@interface LaunchAsRoot: NSObject<LaunchAsRootProtocol>
@end
#endif /* LaunchAsRoot_h */
