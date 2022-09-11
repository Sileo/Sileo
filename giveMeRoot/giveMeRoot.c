#import <stdint.h>
#import <stdlib.h>
#import <stdio.h>
#import <unistd.h>
#import <string.h>
#import <sys/syslimits.h>
#import <sys/stat.h>
#import <sysexits.h>

extern int proc_pidpath(int pid, void *buffer, uint32_t buffersize);

const char *getBuildtimeAppPath(void) {
    const char *path = NULL;
    
#ifndef MAC
    
#ifdef PREBOOT
    
#ifdef NIGHTLY
    path = "/var/jb/Applications/Sileo-Nightly.app/Sileo-Preboot";
#elif BETA
    path = "/var/jb/Applications/Sileo-Beta.app/Sileo-Preboot";
#else
    path = "/var/jb/Applications/Sileo.app/Sileo-Preboot";
#endif
    
#else
    
#ifdef NIGHTLY
    path = "/Applications/Sileo-Nightly.app/Sileo";
#elif BETA
    path = "/Applications/Sileo-Beta.app/Sileo";
#else
    path = "/Applications/Sileo.app/Sileo";
#endif
    
#endif
    
#endif
    
    return path;
}

char *copyRuntimeAppPath(void) {
    const char *buildtimePath = getBuildtimeAppPath();
    if (buildtimePath == NULL) {
        return NULL;
    }
    
    char *runtimePath = realpath(buildtimePath, NULL);
    if (runtimePath == NULL) {
        return NULL;
    }
    
    return runtimePath;
}

int main(int argc, const char *argv[]) {
    int retval = EX_SOFTWARE;
    
    int err = 0;
    
    char *sileoAppPath = NULL;
    char *parentPath = NULL;
    
#ifndef MAC
    
    sileoAppPath = copyRuntimeAppPath();
    if (sileoAppPath == NULL) {
        fprintf(stderr, "Error: failed to retrieve Sileo app path");
        retval = EX_OSFILE;
        goto end;
    }
    
    struct stat sileoAppStat = {};
    err = lstat(sileoAppPath, &sileoAppStat);
    if (err == -1) {
        fprintf(stderr, "Error: failed to stat Sileo app path");
        retval = EX_OSFILE;
        goto end;
    }
    
    pid_t parentPID = getppid();
    
    size_t parentPathSize = PATH_MAX;
    parentPath = malloc(parentPathSize);
    if (parentPath == NULL) {
        fprintf(stderr, "Error: failed to malloc");
        retval = EX_OSERR;
        goto end;
    }
    
    memset(parentPath, 0, parentPathSize);
    
    int parentPathLength = proc_pidpath(parentPID, parentPath, parentPathSize);
    if (parentPathLength <= 0) {
        fprintf(stderr, "Error: failed to retrieve parent process path");
        retval = EX_OSERR;
        goto end;
    }
    
    if (strcmp(parentPath, sileoAppPath) != 0) {
        fprintf(stderr, "Error: permission denied, parent process is not Sileo");
        retval = EX_NOPERM;
        goto end;
    }
    
#endif
    
    setuid(0);
    setgid(0);
    
    if (getuid() != 0) {
        fprintf(stderr, "Error: failed to obtain root");
        retval = EX_OSERR;
        goto end;
    }
    
    retval = 0;
    
end:
    if (sileoAppPath != NULL) {
        free(sileoAppPath);
    }
    if (parentPath != NULL) {
        free(parentPath);
    }
    
    if (retval == 0) {
        if (argc < 2) {
            return 0;
        }
        
        if (strcmp(argv[1], "whoami") == 0) {
            printf("root\n");
            return 0;
        }
        
        const char **remainingArgs = (const char **)((uintptr_t)argv + (1 * sizeof(char *)));
        execv(remainingArgs[0], (char **)remainingArgs);
        
        fprintf(stderr, "Error: failed to execv specified task");
        return EX_OSERR;
    }
    else {
        return retval;
    }
}
