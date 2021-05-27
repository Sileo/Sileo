//
//  LaunchAsRoot.h
//  Sileo
//
//  Created by Andromeda on 27/05/2021.
//  Copyright © 2021 CoolStar. All rights reserved.
//

#ifndef LaunchAsRoot_h
#define LaunchAsRoot_h

#import <Foundation/Foundation.h>
#import <Security/Authorization.h>

@protocol LaunchAsRootProtocol
-(id)init;
-(NSString *)launchAsRoot:(const char ** [])args;
@end

@interface LaunchAsRoot: NSObject<LaunchAsRootProtocol>
@end
#endif /* LaunchAsRoot_h */
