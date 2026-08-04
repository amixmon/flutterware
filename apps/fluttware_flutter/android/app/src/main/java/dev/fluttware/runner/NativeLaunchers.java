package dev.fluttware.runner;

import android.content.Context;
import android.system.Os;

import java.io.File;
import java.nio.file.Files;
import java.util.LinkedHashMap;
import java.util.Map;

/** Resolves immutable executables installed by Android in nativeLibraryDir. */
public final class NativeLaunchers {
    private static final Map<String, String> PACKAGED_NAMES = new LinkedHashMap<>();

    static {
        PACKAGED_NAMES.put("probe", "libflutterware_probe.so");
        PACKAGED_NAMES.put("dart", "libflutterware_dart.so");
        PACKAGED_NAMES.put("dartvm", "libflutterware_dartvm.so");
        PACKAGED_NAMES.put("dartaotruntime", "libflutterware_dartaotruntime.so");
        PACKAGED_NAMES.put("java", "libflutterware_java.so");
        PACKAGED_NAMES.put("javac", "libflutterware_javac.so");
        PACKAGED_NAMES.put("jar", "libflutterware_jar.so");
        PACKAGED_NAMES.put("jarsigner", "libflutterware_jarsigner.so");
        PACKAGED_NAMES.put("keytool", "libflutterware_keytool.so");
        PACKAGED_NAMES.put("jexec", "libflutterware_jexec.so");
        PACKAGED_NAMES.put("jspawnhelper", "libflutterware_jspawnhelper.so");
        PACKAGED_NAMES.put("aapt2", "libflutterware_aapt2.so");
        PACKAGED_NAMES.put("execname", "libflutterware_execname.so");
    }

    private final File nativeLibraryDirectory;
    private final Map<String, File> files;

    private NativeLaunchers(File nativeLibraryDirectory, Map<String, File> files) {
        this.nativeLibraryDirectory = nativeLibraryDirectory;
        this.files = files;
    }

    public static NativeLaunchers from(Context context) throws Exception {
        File directory = new File(context.getApplicationInfo().nativeLibraryDir).getCanonicalFile();
        if (!directory.isDirectory()) {
            throw new IllegalStateException("Native library directory is missing: " + directory);
        }

        Map<String, File> resolved = new LinkedHashMap<>();
        for (Map.Entry<String, String> entry : PACKAGED_NAMES.entrySet()) {
            File launcher = new File(directory, entry.getValue()).getCanonicalFile();
            if (!directory.equals(launcher.getParentFile())) {
                throw new SecurityException("Native launcher escaped package directory: " + launcher);
            }
            if (!launcher.isFile() || !launcher.canExecute()) {
                throw new IllegalStateException("Packaged native launcher is unavailable: " + launcher);
            }
            resolved.put(entry.getKey(), launcher);
        }
        return new NativeLaunchers(directory, resolved);
    }

    public File directory() {
        return nativeLibraryDirectory;
    }

    public File probe() {
        return required("probe");
    }

    public File dart() {
        return required("dart");
    }

    public File dartVm() {
        return required("dartvm");
    }

    public File dartAotRuntime() {
        return required("dartaotruntime");
    }

    public File java() {
        return required("java");
    }

    public File javac() {
        return required("javac");
    }

    public File jar() {
        return required("jar");
    }

    public File jarsigner() {
        return required("jarsigner");
    }

    public File keytool() {
        return required("keytool");
    }

    public File jexec() {
        return required("jexec");
    }

    public File jspawnHelper() {
        return required("jspawnhelper");
    }

    public File aapt2() {
        return required("aapt2");
    }

    public File execNameShim() {
        return required("execname");
    }

    public void linkDartSdk(File sdkRoot) throws Exception {
        File bin = new File(sdkRoot, "bin");
        replaceWithLink(new File(bin, "dart"), dart());
        replaceWithLink(new File(bin, "dartvm"), dartVm());
        replaceWithLink(new File(bin, "dartaotruntime"), dartAotRuntime());
    }

    public void linkJdk(File javaHome) throws Exception {
        File bin = new File(javaHome, "bin");
        replaceWithLink(new File(bin, "java"), java());
        replaceWithLink(new File(bin, "javac"), javac());
        replaceWithLink(new File(bin, "jar"), jar());
        replaceWithLink(new File(bin, "jarsigner"), jarsigner());
        replaceWithLink(new File(bin, "keytool"), keytool());
        replaceWithLink(new File(javaHome, "lib/jexec"), jexec());
        replaceWithLink(new File(javaHome, "lib/jspawnhelper"), jspawnHelper());
    }

    public void linkAndroidSdk(File sdkRoot, String buildToolsVersion) throws Exception {
        replaceWithLink(
                new File(sdkRoot, "build-tools/" + buildToolsVersion + "/aapt2"),
                aapt2());
    }

    public boolean isPackagedTarget(File logicalPath) throws Exception {
        if (!Files.isSymbolicLink(logicalPath.toPath())) {
            return false;
        }
        File target = logicalPath.getCanonicalFile();
        return nativeLibraryDirectory.equals(target.getParentFile())
                && files.containsValue(target)
                && target.canExecute();
    }

    private File required(String key) {
        File value = files.get(key);
        if (value == null) {
            throw new IllegalArgumentException("Unknown native launcher: " + key);
        }
        return value;
    }

    private void replaceWithLink(File logicalPath, File target) throws Exception {
        File parent = logicalPath.getParentFile();
        if (parent == null || (!parent.isDirectory() && !parent.mkdirs())) {
            throw new IllegalStateException("Could not create launcher directory: " + parent);
        }
        if (logicalPath.exists() || Files.isSymbolicLink(logicalPath.toPath())) {
            if (Files.isSymbolicLink(logicalPath.toPath())
                    && target.getCanonicalFile().equals(logicalPath.getCanonicalFile())) {
                return;
            }
            if (!logicalPath.delete()) {
                throw new IllegalStateException("Could not replace writable launcher: " + logicalPath);
            }
        }
        Os.symlink(target.getAbsolutePath(), logicalPath.getAbsolutePath());
        if (!isPackagedTarget(logicalPath)) {
            throw new IllegalStateException("Launcher link did not resolve into nativeLibraryDir: " + logicalPath);
        }
    }
}
