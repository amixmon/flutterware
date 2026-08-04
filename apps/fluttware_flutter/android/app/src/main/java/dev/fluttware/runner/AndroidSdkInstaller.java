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

/** Installs API 36 data, Java build tools, and Android/Bionic ARM64 AAPT2. */
public final class AndroidSdkInstaller {
    public static final String VERSION = "36";
    private static final String ASSET = "android-sdk/android-sdk-36-arm64.zip";
    private static final String ARCHIVE_SHA256 =
            "9dd61cc3e347891132e2040c88bd05171c57613af4cc27ecef0c276f158e4107";
    private static final String INSTALL_NAME = "android-sdk-36-arm64";
    private static final String BUILD_TOOLS_VERSION = "36.0.0";

    public static final class Result {
        public final File sdkRoot;
        public final String archiveSha256;
        public final boolean reused;
        public final long elapsedMillis;

        private Result(
                File sdkRoot,
                String archiveSha256,
                boolean reused,
                long elapsedMillis) {
            this.sdkRoot = sdkRoot;
            this.archiveSha256 = archiveSha256;
            this.reused = reused;
            this.elapsedMillis = elapsedMillis;
        }

        public File buildTools() {
            return new File(sdkRoot, "build-tools/" + BUILD_TOOLS_VERSION);
        }

        public File aapt2() {
            return new File(buildTools(), "aapt2");
        }

        public String libraryPath() {
            return new File(buildTools(), "lib64").getAbsolutePath();
        }
    }

    private AndroidSdkInstaller() {}

    public static Result install(Context context) throws Exception {
        long started = System.currentTimeMillis();
        File toolchains = new File(context.getFilesDir(), "toolchains");
        File destination = new File(toolchains, INSTALL_NAME);
        File sdkRoot = new File(destination, "android-sdk");
        File marker = new File(destination, ".archive.sha256");
        String archiveSha256 = ARCHIVE_SHA256;

        if (isComplete(sdkRoot)
                && marker.isFile()
                && archiveSha256.equals(readText(marker).trim())) {
            chmodExecutables(sdkRoot);
            return new Result(
                    sdkRoot, archiveSha256, true, System.currentTimeMillis() - started);
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

        File temporarySdkRoot = new File(temporary, "android-sdk");
        if (!isComplete(temporarySdkRoot)) {
            throw new IllegalStateException(
                    "Extracted Android SDK is incomplete: " + temporarySdkRoot);
        }
        writeText(new File(temporary, ".archive.sha256"), archiveSha256 + "\n");
        chmodExecutables(temporarySdkRoot);

        deleteRecursively(destination);
        if (!temporary.renameTo(destination)) {
            throw new IllegalStateException("Could not activate Android SDK at " + destination);
        }
        chmodExecutables(sdkRoot);
        return new Result(
                sdkRoot, archiveSha256, false, System.currentTimeMillis() - started);
    }

    private static boolean isComplete(File sdkRoot) {
        File buildTools = new File(sdkRoot, "build-tools/" + BUILD_TOOLS_VERSION);
        return new File(sdkRoot, "platforms/android-36/android.jar").isFile()
                && new File(
                        sdkRoot,
                        "platforms/android-36/core-for-system-modules.jar").isFile()
                && new File(sdkRoot, "platforms/android-36/source.properties").isFile()
                && new File(buildTools, "aapt2").isFile()
                && new File(buildTools, "lib/d8.jar").isFile()
                && new File(buildTools, "lib/apksigner.jar").isFile()
                && new File(buildTools, "lib64/libc++_shared.so").isFile()
                && new File(buildTools, "source.properties").isFile();
    }

    private static void chmodExecutables(File sdkRoot) throws Exception {
        Os.chmod(
                new File(sdkRoot, "build-tools/" + BUILD_TOOLS_VERSION + "/aapt2")
                        .getAbsolutePath(),
                0700);
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
