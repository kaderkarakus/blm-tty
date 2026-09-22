#ifndef BLM_PTY_SPAWN_H
#define BLM_PTY_SPAWN_H

#include <sys/types.h>
#include <unistd.h>

int blm_pty_spawn(const char *path,
                  char *const argv[],
                  char *const envp[],
                  int cols,
                  int rows,
                  int *master_fd,
                  pid_t *pid_out);

#endif
