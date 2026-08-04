package dev.fluttware.runner;

import android.content.Context;

import java.io.File;
import java.io.FileOutputStream;
import java.io.InputStream;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.security.MessageDigest;
import java.util.zip.ZipEntry;
import java.util.zip.ZipInputStream;

/** Installs the minimal Android Dart SDK data shipped in APK assets. */
public final class DartSdkInstaller {
    public static final String VERSION = "3.12.2";
    private static final String ASSET = "dart/dart-sdk-3.12.2-android-arm64.zip";
    private static final String ARCHIVE_SHA256 =
            "56ff79e303240379c029ebad06dcba9adac3875879d4c88a4bb3d09600aa2c54";
    private static final String INSTALL_NAME = "dart-3.12.2-android-arm64";

    public static final class Result {
        public final File sdkRoot;
        public final String archiveSha256;
        public final boolean reused;
        public final long elapsedMillis;

        private Result(File sdkRoot, String archiveSha256, boolean reused, long elapsedMillis) {
            this.sdkRoot = sdkRoot;
            this.archiveSha256 = archiveSha256;
            this.reused = reused;
            this.elapsedMillis = elapsedMillis;
        }

        public File dart() {
            return new File(sdkRoot, "bin/dart");
        }
    }

    private DartSdkInstaller() {}

    public static Result install(Context context) throws Exception {
        long started = System.currentTimeMillis();
        NativeLaunchers launchers = NativeLaunchers.from(context);
        File toolchains = new File(context.getFilesDir(), "toolchains");
        File destination = new File(toolchains, INSTALL_NAME);
        File sdkRoot = new File(destination, "dart-sdk");
        File marker = new File(destination, ".archive.sha256");
        String archiveSha256 = ARCHIVE_SHA256;

        if (isComplete(sdkRoot)
                && marker.isFile()
                && archiveSha256.equals(readText(marker).trim())) {
            launchers.linkDartSdk(sdkRoot);
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
            byte[] buffer = new byte[128 * 1024];
            while ((entry = archive.getNextEntry()) != null) {
                File output = new File(temporary, entry.getName());
                String outputCanonical = output.getCanonicalPath();
                if (!outputCanonical.startsWith(temporaryCanonical)) {
                    throw new SecurityException("Archive entry escapes destination: " + entry.getName());
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

        File temporarySdkRoot = new File(temporary, "dart-sdk");
        if (!isComplete(temporarySdkRoot)) {
            throw new IllegalStateException("Extracted Dart SDK is incomplete: " + temporarySdkRoot);
        }
        writeText(new File(temporary, ".archive.sha256"), archiveSha256 + "\n");
        launchers.linkDartSdk(temporarySdkRoot);

        deleteRecursively(destination);
        if (!temporary.renameTo(destination)) {
            throw new IllegalStateException("Could not activate Dart SDK at " + destination);
        }
        launchers.linkDartSdk(sdkRoot);
        return new Result(
                sdkRoot, archiveSha256, false, System.currentTimeMillis() - started);
    }

    private static boolean isComplete(File sdkRoot) {
        return new File(sdkRoot, "bin/dart").isFile()
                && new File(sdkRoot, "bin/dartvm").isFile()
                && new File(sdkRoot, "bin/dartaotruntime").isFile()
                && new File(sdkRoot, "bin/snapshots/dartdev_aot.dart.snapshot").isFile()
                && new File(sdkRoot, "bin/snapshots/gen_kernel_aot.dart.snapshot").isFile()
                && new File(sdkRoot, "lib/_internal/vm_platform_product.dill").isFile()
                && new File(sdkRoot, "version").isFile();
    }

    private static String sha256(InputStream input) throws Exception {
        MessageDigest digest = MessageDigest.getInstance("SHA-256");
        byte[] buffer = new byte[128 * 1024];
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
        if (!file.exists()) {
            return;
        }
        if (file.isDirectory()) {
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
