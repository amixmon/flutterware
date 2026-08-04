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

/** Installs the patched Flutter Tools kernel and project templates. */
public final class FlutterToolInstaller {
    public static final String VERSION = "3.44.8";
    private static final String ASSET = "flutter/flutter-tool-3.44.8-android-arm64.zip";
    private static final String ARCHIVE_SHA256 =
            "ec1d0108927c9071ad42f1180dd8b6b226b6142806bf9e45f33c4c7866edf883";
    private static final String INSTALL_NAME = "flutter-3.44.8-android-arm64";

    public static final class Result {
        public final File flutterRoot;
        public final File compatibilityBin;
        public final String archiveSha256;
        public final boolean reused;
        public final long elapsedMillis;

        private Result(
                File flutterRoot,
                File compatibilityBin,
                String archiveSha256,
                boolean reused,
                long elapsedMillis) {
            this.flutterRoot = flutterRoot;
            this.compatibilityBin = compatibilityBin;
            this.archiveSha256 = archiveSha256;
            this.reused = reused;
            this.elapsedMillis = elapsedMillis;
        }

        public File toolKernel() {
            return new File(flutterRoot, "bin/cache/flutter_tools.dill");
        }
    }

    private FlutterToolInstaller() {}

    public static Result install(Context context, File dartSdkRoot) throws Exception {
        long started = System.currentTimeMillis();
        File toolchains = new File(context.getFilesDir(), "toolchains");
        File destination = new File(toolchains, INSTALL_NAME);
        File flutterRoot = new File(destination, "flutter");
        File compatibilityBin = new File(destination, "flutter-compat-bin");
        File marker = new File(destination, ".archive.sha256");
        String archiveSha256 = ARCHIVE_SHA256;

        if (isArchiveComplete(flutterRoot, compatibilityBin)
                && marker.isFile()
                && archiveSha256.equals(readText(marker).trim())) {
            prepareRuntime(flutterRoot, compatibilityBin, dartSdkRoot);
            return new Result(
                    flutterRoot,
                    compatibilityBin,
                    archiveSha256,
                    true,
                    System.currentTimeMillis() - started);
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

        File temporaryFlutterRoot = new File(temporary, "flutter");
        File temporaryCompatibilityBin = new File(temporary, "flutter-compat-bin");
        if (!isArchiveComplete(temporaryFlutterRoot, temporaryCompatibilityBin)) {
            throw new IllegalStateException("Extracted Flutter tool is incomplete: " + temporary);
        }
        writeText(new File(temporary, ".archive.sha256"), archiveSha256 + "\n");
        deleteRecursively(destination);
        if (!temporary.renameTo(destination)) {
            throw new IllegalStateException("Could not activate Flutter tool at " + destination);
        }
        prepareRuntime(flutterRoot, compatibilityBin, dartSdkRoot);
        return new Result(
                flutterRoot,
                compatibilityBin,
                archiveSha256,
                false,
                System.currentTimeMillis() - started);
    }

    private static boolean isArchiveComplete(File flutterRoot, File compatibilityBin) {
        return new File(flutterRoot, "bin/cache/flutter_tools.dill").isFile()
                && new File(flutterRoot, "bin/flutter").isFile()
                && new File(flutterRoot, "bin/cache/flutter.version.json").isFile()
                && new File(flutterRoot, "bin/cache/engine.realm").isFile()
                && new File(flutterRoot, "bin/cache/engine_stamp.json").isFile()
                && new File(flutterRoot, "bin/cache/artifacts/gradle_wrapper/gradlew").isFile()
                && new File(flutterRoot, "bin/cache/pkg/sky_engine/pubspec.yaml").isFile()
                && new File(flutterRoot, "bin/cache/pkg/flutter_gpu/pubspec.yaml").isFile()
                && new File(flutterRoot, "packages/flutter_tools/templates/template_manifest.json").isFile()
                && new File(flutterRoot, "packages/flutter_tools/gradle/build.gradle.kts").isFile()
                && new File(flutterRoot, "packages/flutter/pubspec.yaml").isFile()
                && new File(compatibilityBin, "git").isFile();
    }

    private static void prepareRuntime(
            File flutterRoot, File compatibilityBin, File dartSdkRoot) throws Exception {
        File gitShim = new File(compatibilityBin, "git");
        if (!Files.isSymbolicLink(gitShim.toPath())
                || !"/system/bin/false".equals(Os.readlink(gitShim.getAbsolutePath()))) {
            if (gitShim.exists() || Files.isSymbolicLink(gitShim.toPath())) {
                Files.delete(gitShim.toPath());
            }
            Os.symlink("/system/bin/false", gitShim.getAbsolutePath());
        }
        File dartLink = new File(flutterRoot, "bin/cache/dart-sdk");
        File parent = dartLink.getParentFile();
        if (parent != null && !parent.isDirectory() && !parent.mkdirs()) {
            throw new IllegalStateException("Could not create " + parent);
        }
        if (Files.isSymbolicLink(dartLink.toPath())) {
            String existingTarget = Os.readlink(dartLink.getAbsolutePath());
            if (!dartSdkRoot.getAbsolutePath().equals(existingTarget)) {
                Files.delete(dartLink.toPath());
            }
        } else if (dartLink.exists()) {
            throw new IllegalStateException("Dart SDK link path is occupied: " + dartLink);
        }
        if (!Files.isSymbolicLink(dartLink.toPath())) {
            Os.symlink(dartSdkRoot.getAbsolutePath(), dartLink.getAbsolutePath());
        }
        if (!new File(dartLink, "bin/dart").isFile()) {
            throw new IllegalStateException("Flutter Dart SDK link is incomplete: " + dartLink);
        }
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
