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

- (instancetype)init {
    self = [super init];
    [self authenticateIfNeeded];
    return self;
}

- (void)dealloc {
    AuthorizationFree(self.authRef, kAuthorizationFlagDefaults);
}

- (BOOL)authenticateIfNeeded {
    if (self.authRef != NULL) {
        return YES;
    }
    
    OSStatus status;
    AuthorizationRef authRef;
    
    status = AuthorizationCreate(NULL, kAuthorizationEmptyEnvironment, kAuthorizationFlagDefaults, &authRef);
    if (status != errAuthorizationSuccess) {
        AuthorizationFree(authRef, kAuthorizationFlagDefaults);
        return NO;
    }
    
    AuthorizationItem right1 = {kAuthorizationRightExecute, 0, NULL, 0};
    AuthorizationItem rights[] = {right1};
    AuthorizationRights requestedRights = {sizeof(rights) / sizeof(right1), rights};
    
    const char *reason = "Sileo wants to interact with apt as root.";
    AuthorizationItem env1 = {kAuthorizationEnvironmentPrompt, strlen(reason), (void *)reason, 0};
    AuthorizationItem envs[] = {env1};
    AuthorizationRights environment = {sizeof(envs) / sizeof(env1), envs};
    
    AuthorizationFlags flags = kAuthorizationFlagDefaults | kAuthorizationFlagExtendRights | kAuthorizationFlagInteractionAllowed | kAuthorizationFlagPreAuthorize;
    AuthorizationRights *grantedRights;
    status = AuthorizationCopyRights(authRef, &requestedRights, &environment, flags, &grantedRights);
    if (status != errAuthorizationSuccess) {
        AuthorizationFree(authRef, kAuthorizationFlagDefaults);
        return NO;
    }
    
    self.authRef = authRef;
    return YES;
}

- (NSString *)spawnWithPath:(NSString *)path args:(NSArray<NSString *> *)args {
    [self authenticateIfNeeded];
    
    NSUInteger argCount = args.count;
    size_t size = (argCount + 1) * sizeof(const char *);
    const char **arguments = malloc(size);
    for (int i = 0; i < argCount; i++) {
        arguments[i] = [args objectAtIndex:i].UTF8String;
    }
    arguments[argCount] = NULL;
    
    FILE *stream;
    #pragma clang diagnostic push
    #pragma clang diagnostic ignored "-Wdeprecated-declarations"
    OSStatus status = AuthorizationExecuteWithPrivileges(self.authRef, path.UTF8String, kAuthorizationFlagDefaults, (char * const *)arguments, &stream);
    #pragma clang diagnostic pop
    free(arguments);
    if (status != errAuthorizationSuccess) {
        return nil;
    }
    
    NSMutableString *output = [NSMutableString string];
    while (true) {
        char c = fgetc(stream);
        if (feof(stream) != 0) {
            break;
        }
        [output appendFormat:@"%c", c];
    }
    
    return output;
}
@end
