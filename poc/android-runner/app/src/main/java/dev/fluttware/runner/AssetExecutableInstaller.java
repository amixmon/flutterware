package dev.fluttware.runner;

import android.content.Context;
import android.os.Build;
import android.system.Os;

import java.io.File;
import java.io.FileInputStream;
import java.io.FileOutputStream;
import java.io.InputStream;
import java.security.MessageDigest;
import java.util.Arrays;

/** Implements the asset -> cacheDir -> chmod flow used by Sketchware Pro. */
public final class AssetExecutableInstaller {
    private static final String ARM64_ABI = "arm64-v8a";
    private static final String ARM64_ASSET = "native/fluttware-probe-arm64-v8a";

    private AssetExecutableInstaller() {}

    public static File installArm64Probe(Context context) throws Exception {
        if (!Arrays.asList(Build.SUPPORTED_ABIS).contains(ARM64_ABI)) {
            throw new IllegalStateException(
                    "This first probe only supports arm64-v8a; device ABIs="
                            + Arrays.toString(Build.SUPPORTED_ABIS));
        }

        File destination = new File(context.getCacheDir(), "fluttware-native-probe");
        File temporary = new File(context.getCacheDir(), "fluttware-native-probe.tmp");

        try (InputStream input = context.getAssets().open(ARM64_ASSET);
             FileOutputStream output = new FileOutputStream(temporary)) {
            byte[] buffer = new byte[64 * 1024];
            int count;
            while ((count = input.read(buffer)) >= 0) {
                output.write(buffer, 0, count);
            }
            output.getFD().sync();
        }

        if (!destination.isFile() || !sha256(temporary).equals(sha256(destination))) {
            if (destination.exists() && !destination.delete()) {
                throw new IllegalStateException("Could not replace " + destination);
            }
            if (!temporary.renameTo(destination)) {
                throw new IllegalStateException("Could not move executable to " + destination);
            }
        } else if (!temporary.delete()) {
            throw new IllegalStateException("Could not delete unchanged temporary file " + temporary);
        }

        Os.chmod(destination.getAbsolutePath(), 0700);
        return destination;
    }

    public static String sha256(File file) throws Exception {
        MessageDigest digest = MessageDigest.getInstance("SHA-256");
        try (FileInputStream input = new FileInputStream(file)) {
            byte[] buffer = new byte[64 * 1024];
            int count;
            while ((count = input.read(buffer)) >= 0) {
                digest.update(buffer, 0, count);
            }
        }
        StringBuilder result = new StringBuilder();
        for (byte value : digest.digest()) {
            result.append(String.format("%02x", value & 0xff));
        }
        return result.toString();
    }
}
