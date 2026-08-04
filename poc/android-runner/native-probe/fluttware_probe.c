#include <errno.h>
#include <limits.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/types.h>
#include <sys/utsname.h>
#include <unistd.h>

static void print_environment(const char *name) {
    const char *value = getenv(name);
    printf("env.%s=%s\n", name, value == NULL ? "<unset>" : value);
}

int main(int argc, char **argv) {
    struct utsname system_info;
    char working_directory[PATH_MAX];

    puts("FLUTTWARE_NATIVE_PROBE_OK");
    puts("compiled_abi=arm64-v8a");
    printf("pointer_bits=%zu\n", sizeof(void *) * 8);
    printf("pid=%ld uid=%ld gid=%ld\n", (long)getpid(), (long)getuid(), (long)getgid());

    if (uname(&system_info) == 0) {
        printf("uname.sysname=%s\n", system_info.sysname);
        printf("uname.release=%s\n", system_info.release);
        printf("uname.machine=%s\n", system_info.machine);
    } else {
        fprintf(stderr, "uname failed: %s\n", strerror(errno));
    }

    if (getcwd(working_directory, sizeof(working_directory)) != NULL) {
        printf("cwd=%s\n", working_directory);
    } else {
        fprintf(stderr, "getcwd failed: %s\n", strerror(errno));
    }

    print_environment("HOME");
    print_environment("TMPDIR");
    print_environment("PATH");
    print_environment("FLUTTWARE_PROBE_TOKEN");

    for (int index = 0; index < argc; index++) {
        printf("argv[%d]=%s\n", index, argv[index]);
    }

    FILE *proof = fopen("native-probe-output.txt", "w");
    if (proof == NULL) {
        fprintf(stderr, "proof file open failed: %s\n", strerror(errno));
        return 2;
    }
    fprintf(proof, "FLUTTWARE_CHILD_WRITE_OK\n");
    fprintf(proof, "pid=%ld\n", (long)getpid());
    if (fclose(proof) != 0) {
        fprintf(stderr, "proof file close failed: %s\n", strerror(errno));
        return 3;
    }

    fprintf(stderr, "FLUTTWARE_NATIVE_STDERR_OK\n");
    fflush(stdout);
    fflush(stderr);
    return 0;
}
