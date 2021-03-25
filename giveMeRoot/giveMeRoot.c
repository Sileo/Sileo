#include <stdio.h>
#include <string.h>
#include <sysexits.h>
#include <sys/stat.h>
#include <sys/types.h>
#include <unistd.h>

#define PROC_PIDPATHINFO_MAXSIZE (1024)
int proc_pidpath(pid_t pid, void *buffer, uint32_t buffersize);

int main(int argc, char *argv[]) {
    const char *sileoPath = "/Applications/Sileo.app/Sileo";
    const char *sileoBetaPath = "/Applications/Sileo-Beta.app/Sileo";
    
    struct stat statBuffer;
    int status = lstat(sileoPath, &statBuffer);
    if (status == -1) {
        fprintf(stderr, "Cease your resistance!\n");
        return EX_NOPERM;
    }
    
    pid_t parentPID = getppid();
    char parentPath[PROC_PIDPATHINFO_MAXSIZE] = {0};
    status = proc_pidpath(parentPID, parentPath, sizeof(parentPath));
    if (status <= 0) {
        fprintf(stderr, "Ice wall, coming up\n");
        return EX_NOPERM;
    }
    
    if (strcmp(parentPath, sileoPath) != 0 && strcmp(parentPath, sileoBetaPath) != 0) {
        fprintf(stderr, "Stpuidity is not a right\n");
        return EX_NOPERM;
    }
    
    setuid(0);
    setgid(0);
    if (getuid() != 0) {
        fprintf(stderr, "Area denied\n");
        return EX_NOPERM;
    }
    
    if (argc < 2) {
        fprintf(stderr, "Reality bends to my will!\n");
        return 0;
    }

    if (strcmp(argv[1], "whoami") == 0) {
        printf("root\n");
        return 0;
    }

    const char *shell = "/usr/bin/sh"
    char *args[] = {(char *)shell, "-c", argv[1], NULL};
    execv(shell, args);
    
    return EX_UNAVAILABLE;
}
