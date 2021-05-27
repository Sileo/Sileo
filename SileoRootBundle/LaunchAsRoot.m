//
//  LaunchAsRoot.m
//  SileoRootBundle
//
//  Created by Amy on 27/05/2021.
//  Copyright © 2021 Amy While. All rights reserved.
//

#import "LaunchAsRoot.h"

#pragma clang diagnostic ignored "-Wdeprecated-declarations"

@implementation LaunchAsRoot

AuthorizationRef authRef;

- (NSArray *)launchAsRoot:(NSArray *)arguments launchPath:(NSString *)launchPath {
    NSUInteger numArgs = [arguments count];
    char *args[numArgs + 1];
    FILE *output_pipe;
    
    const char *toolPath = [launchPath fileSystemRepresentation];
    for (int i = 0; i < numArgs; i++) {
        NSString *argString = arguments[i];
        const char *fsrep = [argString fileSystemRepresentation];
        NSUInteger stringLength = strlen(fsrep);
        args[i] = calloc((stringLength + 1), sizeof(char));
        snprintf(args[i], stringLength + 1, "%s", fsrep);
    }
    args[numArgs] = NULL;

    
    OSStatus status = AuthorizationExecuteWithPrivileges(authRef, toolPath, kAuthorizationFlagDefaults, args, &output_pipe);
    for (int i = 0; i < numArgs; i++) {
        free(args[i]);
    }
    if (status != errAuthorizationSuccess) {
        return [NSArray arrayWithObjects: [NSNumber numberWithInt: -1], @"", nil];
    }
    pid_t pid = fcntl(fileno(output_pipe), F_GETOWN, 0);
    
    NSMutableString *stdOut = [NSMutableString new];
    while (true) {
        char c = fgetc(output_pipe);
        if (feof(output_pipe) == 0) {
            NSString *tmp = [NSString stringWithFormat:@"%c", c];
            stdOut = [NSMutableString stringWithFormat:@"%@%@", stdOut, tmp];
        }
        else {
            break;
        }
    }
    fclose(output_pipe);
    return [NSArray arrayWithObjects: [NSNumber numberWithInt: pid], stdOut, nil];
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
