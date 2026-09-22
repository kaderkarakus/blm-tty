#include "pty_spawn.h"

#include <errno.h>
#include <fcntl.h>
#include <stdlib.h>
#include <string.h>
#include <sys/resource.h>
#include <unistd.h>
#include <util.h>

int blm_pty_spawn(const char *path,
                  char *const argv[],
                  char *const envp[],
                  int cols,
                  int rows,
                  int *master_fd,
                  pid_t *pid_out)
{
    if (!path || !argv || !master_fd || !pid_out) {
        errno = EINVAL;
        return -1;
    }

    struct winsize ws;
    memset(&ws, 0, sizeof(ws));
    ws.ws_col = (unsigned short)(cols > 1 ? cols : 80);
    ws.ws_row = (unsigned short)(rows > 1 ? rows : 24);

    int master = -1;
    pid_t pid = forkpty(&master, NULL, NULL, &ws);
    if (pid < 0) {
        return -1;
    }
    if (pid == 0) {
        struct rlimit rl;
        int maxfd = 256;
        if (getrlimit(RLIMIT_NOFILE, &rl) == 0 && rl.rlim_cur > 3 && rl.rlim_cur < 4096) {
            maxfd = (int)rl.rlim_cur;
        }
        for (int fd = 3; fd < maxfd; fd++) {
            (void)close(fd);
        }
        if (envp) {
            execve(path, argv, envp);
        } else {
            execv(path, argv);
        }
        _exit(127);
    }

    (void)fcntl(master, F_SETFD, FD_CLOEXEC);
    int fl = fcntl(master, F_GETFL, 0);
    if (fl >= 0) {
        (void)fcntl(master, F_SETFL, fl | O_NONBLOCK);
    }
    *master_fd = master;
    *pid_out = pid;
    return 0;
}
