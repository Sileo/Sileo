//
//  LaunchAsRoot.m
//  SileoRootWrapper
//
//  Created by Sileo Team on 27/05/2021.
//  Copyright © 2021 Sileo Team. All rights reserved.
//

#import "LaunchAsRoot.h"

@implementation LaunchAsRoot
+ (instancetype)shared {
    static LaunchAsRoot *singleton;
    static dispatch_once_t token;
    dispatch_once(&token, ^{
        singleton = [[self alloc] init];
    });
    return singleton;
}

-(NSXPCConnection *)connection {
    return [[NSXPCConnection alloc] initWithMachServiceName:@"SileoRootDaemon" options: NSXPCConnectionPrivileged];
}

-(BOOL)installDaemon {
    AuthorizationItem authItem      = { kSMRightBlessPrivilegedHelper, 0, NULL, 0 };
    AuthorizationRights authRights  = { 1, &authItem };
    AuthorizationFlags flags        =   kAuthorizationFlagDefaults              |
    kAuthorizationFlagInteractionAllowed    |
    kAuthorizationFlagPreAuthorize          |
    kAuthorizationFlagExtendRights;

    AuthorizationRef authRef = NULL;

    OSStatus status = AuthorizationCreate(&authRights, kAuthorizationEmptyEnvironment, flags, &authRef);
    if (status != errAuthorizationSuccess) {
        exit(0);
    }
    NSString *name = @"SileoRootDaemon";
    CFStringRef str = (__bridge CFStringRef)name;
    CFErrorRef error;
    BOOL success = SMJobBless(kSMDomainSystemLaunchd, str, authRef, &error);
    if (!success) {
        NSLog(@"[Sileo] SMJobBless failed with error %@", error);
        exit(0);
    }
    free(error);
    AuthorizationFree(authRef, kAuthorizationFlagDefaults);
    NSLog(@"[Sileo] helper installed succesfully");
    return YES;
}

@end
