//
//  LaunchAsRoot.m
//  SileoRootBundle
//
//  Created by Andromeda on 27/05/2021.
//  Copyright © 2021 CoolStar. All rights reserved.
//

#import "LaunchAsRoot.h"
#pragma clang diagnostic ignored "-Wdeprecated-declarations"

@implementation LaunchAsRoot

AuthorizationRef authRef;

- (NSString *)launchAsRoot:(const char ** [])arguments {
    AuthorizationExecuteWithPrivileges(authRef, (const char *)arguments[0], kAuthorizationFlagDefaults, (char * const *)arguments, NULL);
    return @"cum";
}

-(id)init {
    self = [super init];
    if (self) {
        OSStatus status;
        AuthorizationFlags flags = kAuthorizationFlagDefaults;
        status = AuthorizationCreate(NULL, kAuthorizationEmptyEnvironment, flags, &authRef);
        if (status != errAuthorizationSuccess) exit(0);
        
        AuthorizationItem items = {kAuthorizationRightExecute, 0, NULL, 0};
        AuthorizationRights rights = {1, &items};
        flags = kAuthorizationFlagDefaults |
        kAuthorizationFlagInteractionAllowed |
        kAuthorizationFlagPreAuthorize |
        kAuthorizationFlagExtendRights;
        status = AuthorizationCopyRights(authRef, &rights, NULL, flags, NULL );
        
        if (status != errAuthorizationSuccess) {
            exit(0);
        }
    }
    return self;
}

@end
