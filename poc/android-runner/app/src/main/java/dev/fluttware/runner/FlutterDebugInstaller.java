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

/** Installs revision-matched Flutter debug compiler, snapshots, dex, and engine data. */
public final class FlutterDebugInstaller {
    private static final String ASSET =
            "flutter-debug/flutter-debug-3.44.8-android-arm64.zip";
    private static final String INSTALL_NAME = "flutter-debug-3.44.8-android-arm64";

    public static final class Result {
        public final File debugRoot;
        public final String archiveSha256;
        public final boolean reused;
        public final long elapsedMillis;

        private Result(
                File debugRoot,
                String archiveSha256,
                boolean reused,
                long elapsedMillis) {
            this.debugRoot = debugRoot;
            this.archiveSha256 = archiveSha256;
            this.reused = reused;
            this.elapsedMillis = elapsedMillis;
        }
    }

    private FlutterDebugInstaller() {}

    public static Result install(Context context) throws Exception {
        long started = System.currentTimeMillis();
        File toolchains = new File(context.getFilesDir(), "toolchains");
        File destination = new File(toolchains, INSTALL_NAME);
        File debugRoot = new File(destination, "flutter-debug");
        File marker = new File(destination, ".archive.sha256");
        String archiveSha256;
        try (InputStream input = context.getAssets().open(ASSET)) {
            archiveSha256 = sha256(input);
        }

        if (isComplete(debugRoot)
                && marker.isFile()
                && archiveSha256.equals(readText(marker).trim())) {
            return new Result(
                    debugRoot, archiveSha256, true, System.currentTimeMillis() - started);
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
                        file.getFD().sync();
                    }
                }
                archive.closeEntry();
            }
        }

        File temporaryDebugRoot = new File(temporary, "flutter-debug");
        if (!isComplete(temporaryDebugRoot)) {
            throw new IllegalStateException(
                    "Extracted Flutter debug toolchain is incomplete: " + temporaryDebugRoot);
        }
        writeText(new File(temporary, ".archive.sha256"), archiveSha256 + "\n");

        deleteRecursively(destination);
        if (!temporary.renameTo(destination)) {
            throw new IllegalStateException("Could not activate " + destination);
        }
        return new Result(
                debugRoot, archiveSha256, false, System.currentTimeMillis() - started);
    }

    private static boolean isComplete(File root) {
        return new File(root, "frontend_server_aot.dart.snapshot").isFile()
                && new File(root, "common/flutter_patched_sdk/platform_strong.dill").isFile()
                && new File(root, "vm_snapshot_data").isFile()
                && new File(root, "isolate_snapshot_data").isFile()
                && new File(root, "apk-template/classes.dex").isFile()
                && new File(root, "apk-template/lib/arm64-v8a/libflutter.so").isFile()
                && new File(
                        root,
                        "apk-template/assets/flutter_assets/AssetManifest.bin").isFile();
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
