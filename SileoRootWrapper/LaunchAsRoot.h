//
//  LaunchAsRoot.h
//  SileoRootWrapper
//
//  Created by Sileo Team on 27/05/2021.
//  Copyright © 2022 Sileo Team. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <Security/Authorization.h>
#import <ServiceManagement/ServiceManagement.h>

@interface LaunchAsRoot : NSObject
@property (class, readonly) LaunchAsRoot *shared;
- (NSXPCConnection *)connection;
- (BOOL)installDaemon;
@end
