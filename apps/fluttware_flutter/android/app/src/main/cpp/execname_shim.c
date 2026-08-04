#include <errno.h>
#include <fcntl.h>
#include <limits.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/syscall.h>
#include <unistd.h>

/*
 * OpenJDK derives JAVA_HOME from /proc/self/exe. Flutterware's launchers live
 * in nativeLibraryDir, while the JDK image remains writable data in filesDir.
 * This preload shim reports the logical $JAVA_HOME/bin/<tool> path only to a
 * packaged OpenJDK launcher. All other readlink calls go straight to the
 * kernel, so Dart and Android tools retain their normal behavior.
 */

static ssize_t kernel_readlink(const char* path, char* buffer, size_t size) {
  return syscall(__NR_readlinkat, AT_FDCWD, path, buffer, size);
}

static const char* launcher_name(const char* executable) {
  static const struct {
    const char* packaged;
    const char* logical;
  } launchers[] = {
      {"libflutterware_java.so", "java"},
      {"libflutterware_javac.so", "javac"},
      {"libflutterware_jar.so", "jar"},
      {"libflutterware_jarsigner.so", "jarsigner"},
      {"libflutterware_keytool.so", "keytool"},
  };

  const char* base = strrchr(executable, '/');
  base = base == NULL ? executable : base + 1;
  for (size_t index = 0; index < sizeof(launchers) / sizeof(launchers[0]); index++) {
    if (strcmp(base, launchers[index].packaged) == 0) {
      return launchers[index].logical;
    }
  }
  return NULL;
}

__attribute__((visibility("default")))
ssize_t readlink(const char* path, char* buffer, size_t size) {
  if (path != NULL && strcmp(path, "/proc/self/exe") == 0) {
    char executable[PATH_MAX + 1];
    const ssize_t length = kernel_readlink(path, executable, PATH_MAX);
    if (length >= 0) {
      executable[length] = '\0';
      const char* tool = launcher_name(executable);
      const char* java_home = getenv("FLUTTERWARE_JAVA_HOME");
      if (tool != NULL && java_home != NULL && java_home[0] == '/') {
        char logical[PATH_MAX + 1];
        const int written = snprintf(
            logical, sizeof(logical), "%s/bin/%s", java_home, tool);
        if (written < 0 || (size_t)written >= sizeof(logical)) {
          errno = ENAMETOOLONG;
          return -1;
        }
        const size_t copy = (size_t)written < size ? (size_t)written : size;
        memcpy(buffer, logical, copy);
        return (ssize_t)copy;
      }
    }
  }
  return kernel_readlink(path, buffer, size);
}
