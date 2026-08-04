package dev.fluttware.runner;

import android.content.Context;
import android.system.Os;

import java.io.File;
import java.io.FileOutputStream;
import java.io.InputStream;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.security.MessageDigest;
import java.util.zip.ZipEntry;
import java.util.zip.ZipInputStream;

/** Installs the minimal Android/Bionic ARM64 OpenJDK runtime shipped in assets. */
public final class JdkInstaller {
    public static final String VERSION = "21.0.12";
    private static final String ASSET = "jdk/openjdk-21.0.12-android-arm64.zip";
    private static final String ARCHIVE_SHA256 =
            "d8e689d6c70b53510a112f60759b0a9461371c8418a755019041d98b9f4d77db";
    private static final String INSTALL_NAME = "openjdk-21.0.12-android-arm64";

    public static final class Result {
        public final File javaHome;
        public final String archiveSha256;
        public final boolean reused;
        public final long elapsedMillis;

        private Result(
                File javaHome,
                String archiveSha256,
                boolean reused,
                long elapsedMillis) {
            this.javaHome = javaHome;
            this.archiveSha256 = archiveSha256;
            this.reused = reused;
            this.elapsedMillis = elapsedMillis;
        }

        public File java() {
            return new File(javaHome, "bin/java");
        }

        public String libraryPath() {
            return new File(javaHome, "lib/server").getAbsolutePath()
                    + ":" + new File(javaHome, "lib").getAbsolutePath();
        }
    }

    private JdkInstaller() {}

    public static Result install(Context context) throws Exception {
        long started = System.currentTimeMillis();
        File toolchains = new File(context.getFilesDir(), "toolchains");
        File destination = new File(toolchains, INSTALL_NAME);
        File javaHome = new File(destination, "jdk");
        File marker = new File(destination, ".archive.sha256");
        String archiveSha256 = ARCHIVE_SHA256;

        if (isComplete(javaHome)
                && marker.isFile()
                && archiveSha256.equals(readText(marker).trim())) {
            chmodExecutables(javaHome);
            return new Result(
                    javaHome, archiveSha256, true, System.currentTimeMillis() - started);
        }

        if (!toolchains.isDirectory() && !toolchains.mkdirs()) {
            throw new IllegalStateException("Could not create " + toolchains);
        }
        File temporary = new File(toolchains, INSTALL_NAME + ".installing");
        deleteRecursively(temporary);
        if (!temporary.mkdirs()) {
            throw new IllegalStateException("Could not create " + temporary);
        }

        String temporaryCanonical = temporary.getCanonicalPath() + File.separator;
        try (ZipInputStream archive = new ZipInputStream(context.getAssets().open(ASSET))) {
            ZipEntry entry;
            byte[] buffer = new byte[256 * 1024];
            while ((entry = archive.getNextEntry()) != null) {
                File output = new File(temporary, entry.getName());
                String outputCanonical = output.getCanonicalPath();
                if (!outputCanonical.startsWith(temporaryCanonical)) {
                    throw new SecurityException(
                            "Archive entry escapes destination: " + entry.getName());
                }
                if (entry.isDirectory()) {
                    if (!output.isDirectory() && !output.mkdirs()) {
                        throw new IllegalStateException("Could not create " + output);
                    }
                } else {
                    File parent = output.getParentFile();
                    if (parent != null && !parent.isDirectory() && !parent.mkdirs()) {
                        throw new IllegalStateException("Could not create " + parent);
                    }
                    try (FileOutputStream file = new FileOutputStream(output)) {
                        int count;
                        while ((count = archive.read(buffer)) >= 0) {
                            file.write(buffer, 0, count);
                        }
                        // The atomic install marker makes per-file fsync unnecessary.
                    }
                }
                archive.closeEntry();
            }
        }

        File temporaryJavaHome = new File(temporary, "jdk");
        if (!isComplete(temporaryJavaHome)) {
            throw new IllegalStateException(
                    "Extracted OpenJDK runtime is incomplete: " + temporaryJavaHome);
        }
        writeText(new File(temporary, ".archive.sha256"), archiveSha256 + "\n");
        chmodExecutables(temporaryJavaHome);

        deleteRecursively(destination);
        if (!temporary.renameTo(destination)) {
            throw new IllegalStateException("Could not activate OpenJDK at " + destination);
        }
        chmodExecutables(javaHome);
        return new Result(
                javaHome, archiveSha256, false, System.currentTimeMillis() - started);
    }

    private static boolean isComplete(File javaHome) {
        return new File(javaHome, "bin/java").isFile()
                && new File(javaHome, "bin/javac").isFile()
                && new File(javaHome, "release").isFile()
                && new File(javaHome, "lib/modules").isFile()
                && new File(javaHome, "lib/server/libjvm.so").isFile()
                && new File(javaHome, "lib/libjava.so").isFile()
                && new File(javaHome, "lib/libandroid-shmem.so").isFile()
                && new File(javaHome, "lib/libandroid-spawn.so").isFile()
                && new File(javaHome, "lib/libc++_shared.so").isFile()
                && new File(javaHome, "lib/libz.so.1").isFile();
    }

    private static void chmodExecutables(File javaHome) throws Exception {
        for (String launcher : new String[] {"java", "javac", "jar", "jarsigner", "keytool"}) {
            Os.chmod(new File(javaHome, "bin/" + launcher).getAbsolutePath(), 0700);
        }
        Os.chmod(new File(javaHome, "lib/jexec").getAbsolutePath(), 0700);
        Os.chmod(new File(javaHome, "lib/jspawnhelper").getAbsolutePath(), 0700);
    }

    private static String sha256(InputStream input) throws Exception {
        MessageDigest digest = MessageDigest.getInstance("SHA-256");
        byte[] buffer = new byte[256 * 1024];
        int count;
        while ((count = input.read(buffer)) >= 0) {
            digest.update(buffer, 0, count);
        }
        StringBuilder result = new StringBuilder();
        for (byte value : digest.digest()) {
            result.append(String.format("%02x", value & 0xff));
        }
        return result.toString();
    }

    private static String readText(File file) throws Exception {
        return new String(Files.readAllBytes(file.toPath()), StandardCharsets.UTF_8);
    }

    private static void writeText(File file, String text) throws Exception {
        try (FileOutputStream output = new FileOutputStream(file)) {
            output.write(text.getBytes(StandardCharsets.UTF_8));
            output.getFD().sync();
        }
    }

    private static void deleteRecursively(File file) throws Exception {
        if (!file.exists() && !Files.isSymbolicLink(file.toPath())) {
            return;
        }
        if (!Files.isSymbolicLink(file.toPath()) && file.isDirectory()) {
            File[] children = file.listFiles();
            if (children == null) {
                throw new IllegalStateException("Could not list " + file);
            }
            for (File child : children) {
                deleteRecursively(child);
            }
        }
        if (!file.delete()) {
            throw new IllegalStateException("Could not delete " + file);
        }
    }
}
