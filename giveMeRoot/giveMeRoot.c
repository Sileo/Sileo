#include <stdio.h>
#include <stdlib.h>
#include <dlfcn.h>
#include <errno.h>
#include <sysexits.h>
#include <unistd.h>
#include <string.h>
#include <sys/stat.h>

#define PROC_PIDPATHINFO_MAXSIZE  (1024)
int proc_pidpath(pid_t pid, void *buffer, uint32_t buffersize);

/* Set platform binary flag */
#define FLAG_PLATFORMIZE (1 << 1)

void patch_setuid() {
    void* handle = dlopen("/usr/lib/libjailbreak.dylib", RTLD_LAZY);
    if (!handle) return;
    
    // Reset errors
    dlerror();
    
    typedef void (*fix_setuid_prt_t)(pid_t pid);
    fix_setuid_prt_t ptr = (fix_setuid_prt_t)dlsym(handle, "jb_oneshot_fix_setuid_now");
    
    ptr(getpid());
    
    setuid(0);
}

int main(int argc, char *argv[]){
    patch_setuid();
    
    struct stat correct;
    if (lstat("/Applications/Sileo.app/Sileo", &correct) == -1){
        fprintf(stderr, "Cease your resistance!\n");
        return EX_NOPERM;
    }
    
    pid_t parent = getppid();
    bool sileo = false;
    
    char pathbuf[PROC_PIDPATHINFO_MAXSIZE] = {0};
    int ret = proc_pidpath(parent, pathbuf, sizeof(pathbuf));
    if (ret > 0){
        if (strcmp(pathbuf, "/Applications/Sileo.app/Sileo") == 0 || strcmp(pathbuf, "/Applications/Sileo-Beta.app/Sileo") == 0){
            sileo = true;
        }
    }
    
    if (sileo == false){
        fprintf(stderr, "Ice wall, coming up\n");
        return EX_NOPERM;
    }
    
    setuid(0);
    setgid(0);
    
    if (getuid() != 0){
        fprintf(stderr, "Area denied\n");
        return EX_NOPERM;
    }
    
    if (argc < 2){
        fprintf(stderr, "Reality bends to my will!\n");
        return 0;
    }

    if (strcmp(argv[1], "whoami") == 0){
        printf("root\n");
        return 0;
    }
    
    char *shell;
    if(access("/bin/zsh", X_OK) == 0) {
        shell = "/bin/zsh";
    } else {
        shell = "/bin/bash";
    }
    char *args[4] = {shell, "-c", argv[1], NULL};
    execv(args[0], args);
    return EX_UNAVAILABLE;
}
