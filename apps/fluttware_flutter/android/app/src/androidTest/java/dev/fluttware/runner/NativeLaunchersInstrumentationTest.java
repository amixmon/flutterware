package dev.fluttware.runner;

import android.content.Context;
import android.system.Os;

import androidx.test.ext.junit.runners.AndroidJUnit4;
import androidx.test.platform.app.InstrumentationRegistry;

import java.io.BufferedReader;
import java.io.File;
import java.io.InputStreamReader;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.util.Map;
import java.util.concurrent.TimeUnit;

import org.junit.Before;
import org.junit.Test;
import org.junit.runner.RunWith;

import static org.junit.Assert.assertEquals;
import static org.junit.Assert.assertTrue;

/** Device coverage for immutable launchers and writable toolchain data. */
@RunWith(AndroidJUnit4.class)
public final class NativeLaunchersInstrumentationTest {
    private Context context;
    private NativeLaunchers launchers;

    @Before
    public void setUp() throws Exception {
        context = InstrumentationRegistry.getInstrumentation().getTargetContext();
        launchers = NativeLaunchers.from(context);
    }

    @Test
    public void testProbeExecutesDirectlyFromNativeLibraryDirectory() throws Exception {
        File probe = launchers.probe().getCanonicalFile();
        assertEquals(launchers.directory(), probe.getParentFile());
        assertTrue(probe.canExecute());

        Process process = new ProcessBuilder(probe.getAbsolutePath(), "instrumentation")
                .directory(context.getCacheDir())
                .redirectErrorStream(true)
                .start();
        String output = finish(process, 15);
        assertTrue(output, output.contains("FLUTTWARE_NATIVE_PROBE_OK"));
    }

    @Test
    public void testDartInstallKeepsDataWritableAndLinksImmutableLaunchers() throws Exception {
        DartSdkInstaller.Result installed = DartSdkInstaller.install(context);
        File filesRoot = context.getFilesDir().getCanonicalFile();
        File sdkRoot = installed.sdkRoot.getCanonicalFile();

        assertTrue(sdkRoot.getAbsolutePath().startsWith(filesRoot.getAbsolutePath() + File.separator));
        assertTrue(new File(sdkRoot, "bin/snapshots/dartdev_aot.dart.snapshot").isFile());
        assertTrue(Files.isSymbolicLink(installed.dart().toPath()));
        assertTrue(launchers.isPackagedTarget(installed.dart()));
        assertTrue(launchers.isPackagedTarget(new File(sdkRoot, "bin/dartvm")));
        assertTrue(launchers.isPackagedTarget(new File(sdkRoot, "bin/dartaotruntime")));

        Process process = new ProcessBuilder(installed.dart().getAbsolutePath(), "--version")
                .directory(context.getCacheDir())
                .redirectErrorStream(true)
                .start();
        String output = finish(process, 30);
        assertTrue(output, output.contains("Dart SDK version: 3.12.2"));
        assertTrue(output, output.contains("android_arm64"));

        replaceWithStaleLink(installed.dart());
        DartSdkInstaller.Result repaired = DartSdkInstaller.install(context);
        assertTrue("Complete SDK data should be reused after an APK update", repaired.reused);
        assertTrue(launchers.isPackagedTarget(repaired.dart()));
    }

    @Test
    public void testJdkAndAndroidSdkInstallAndExecutePackagedLaunchers() throws Exception {
        JdkInstaller.Result jdk = JdkInstaller.install(context);
        AndroidSdkInstaller.Result androidSdk = AndroidSdkInstaller.install(context);
        assertWithinFilesDirectory(jdk.javaHome);
        assertWithinFilesDirectory(androidSdk.sdkRoot);
        assertTrue(launchers.isPackagedTarget(jdk.java()));
        assertTrue(launchers.isPackagedTarget(androidSdk.aapt2()));

        replaceWithStaleLink(jdk.java());
        replaceWithStaleLink(androidSdk.aapt2());
        jdk = JdkInstaller.install(context);
        androidSdk = AndroidSdkInstaller.install(context);
        assertTrue("Complete JDK data should be reused after an APK update", jdk.reused);
        assertTrue("Complete Android SDK data should be reused after an APK update", androidSdk.reused);
        assertTrue(launchers.isPackagedTarget(jdk.java()));
        assertTrue(launchers.isPackagedTarget(androidSdk.aapt2()));

        ProcessBuilder javaBuilder = new ProcessBuilder(jdk.java().getAbsolutePath(), "--version")
                .directory(context.getCacheDir())
                .redirectErrorStream(true);
        Map<String, String> javaEnvironment = javaBuilder.environment();
        javaEnvironment.put("JAVA_HOME", jdk.javaHome.getAbsolutePath());
        javaEnvironment.put("FLUTTERWARE_JAVA_HOME", jdk.javaHome.getAbsolutePath());
        javaEnvironment.put("JAVA_TOOL_OPTIONS", "-Djdk.lang.Process.launchMechanism=FORK");
        javaEnvironment.put("LD_PRELOAD", launchers.execNameShim().getAbsolutePath());
        javaEnvironment.put("LD_LIBRARY_PATH", jdk.libraryPath());
        String javaOutput = finish(javaBuilder.start(), 60);
        assertTrue(javaOutput, javaOutput.contains("openjdk 21.0.12"));

        ProcessBuilder aapt2Builder = new ProcessBuilder(
                androidSdk.aapt2().getAbsolutePath(), "version")
                .directory(context.getCacheDir())
                .redirectErrorStream(true);
        aapt2Builder.environment().put("LD_LIBRARY_PATH", androidSdk.libraryPath());
        String aapt2Output = finish(aapt2Builder.start(), 30);
        assertTrue(aapt2Output, aapt2Output.contains("Android Asset Packaging Tool"));
    }

    @Test
    public void testEveryLogicalEntryPointResolvesIntoNativeLibraryDirectory() throws Exception {
        File fixture = new File(context.getCacheDir(), "native-launcher-links");
        deleteRecursively(fixture);
        assertTrue(fixture.mkdirs());

        File dartSdk = new File(fixture, "dart-sdk");
        File javaHome = new File(fixture, "jdk");
        File androidSdk = new File(fixture, "android-sdk");
        launchers.linkDartSdk(dartSdk);
        launchers.linkJdk(javaHome);
        launchers.linkAndroidSdk(androidSdk, "36.0.0");

        for (File logical : new File[] {
                new File(dartSdk, "bin/dart"),
                new File(dartSdk, "bin/dartvm"),
                new File(dartSdk, "bin/dartaotruntime"),
                new File(javaHome, "bin/java"),
                new File(javaHome, "bin/javac"),
                new File(javaHome, "bin/jar"),
                new File(javaHome, "bin/jarsigner"),
                new File(javaHome, "bin/keytool"),
                new File(javaHome, "lib/jexec"),
                new File(javaHome, "lib/jspawnhelper"),
                new File(androidSdk, "build-tools/36.0.0/aapt2"),
        }) {
            assertTrue(logical.toString(), Files.isSymbolicLink(logical.toPath()));
            assertTrue(logical.toString(), launchers.isPackagedTarget(logical));
        }
    }

    private static String readOutput(Process process) throws Exception {
        StringBuilder output = new StringBuilder();
        try (BufferedReader reader = new BufferedReader(
                new InputStreamReader(process.getInputStream(), StandardCharsets.UTF_8))) {
            String line;
            while ((line = reader.readLine()) != null) {
                output.append(line).append('\n');
            }
        }
        return output.toString();
    }

    private static String finish(Process process, long timeoutSeconds) throws Exception {
        if (!process.waitFor(timeoutSeconds, TimeUnit.SECONDS)) {
            process.destroyForcibly();
            process.waitFor(5, TimeUnit.SECONDS);
            throw new AssertionError("Process timed out after " + timeoutSeconds + " seconds");
        }
        String output = readOutput(process);
        assertEquals(output, 0, process.exitValue());
        return output;
    }

    private void assertWithinFilesDirectory(File path) throws Exception {
        String filesRoot = context.getFilesDir().getCanonicalPath() + File.separator;
        assertTrue(path.toString(), path.getCanonicalPath().startsWith(filesRoot));
    }

    private static void replaceWithStaleLink(File logicalPath) throws Exception {
        Files.delete(logicalPath.toPath());
        Os.symlink(
                "/data/app/obsolete-flutterware/lib/arm64/" + logicalPath.getName(),
                logicalPath.getAbsolutePath());
        assertTrue(Files.isSymbolicLink(logicalPath.toPath()));
    }

    private static void deleteRecursively(File file) {
        if (!file.exists() && !Files.isSymbolicLink(file.toPath())) return;
        File[] children = file.listFiles();
        if (children != null) {
            for (File child : children) deleteRecursively(child);
        }
        assertTrue("Could not delete " + file, file.delete());
    }
}
