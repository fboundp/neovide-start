/// Inline functions mapping to the wait(2) macros, for import
/// into Swift.
#include <stdbool.h>
#include <sys/wait.h>

static inline bool
wifexited(int status)
{
    return 0 != WIFEXITED(status);
}

static inline bool
wifsignaled(int status)
{
    return 0 != WIFSIGNALED(status);
}

static inline bool
wifstopped(int status)
{
    return 0 != WIFSTOPPED(status);
}

static inline int
wexitstatus(int status)
{
    return WEXITSTATUS(status);
}

static inline int
wtermsig(int status)
{
    return WTERMSIG(status);
}

static inline int
wcoredump(int status)
{
    return WCOREDUMP(status);
}

static inline int
wstopsig(int status)
{
    return WIFSTOPPED(status);
}
