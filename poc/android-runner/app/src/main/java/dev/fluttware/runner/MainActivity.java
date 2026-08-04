package dev.fluttware.runner;

import android.app.Activity;
import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.content.IntentFilter;
import android.content.pm.PackageInstaller;
import android.graphics.Color;
import android.os.Build;
import android.os.Bundle;
import android.util.Log;
import android.view.ViewGroup;
import android.widget.Button;
import android.widget.EditText;
import android.widget.LinearLayout;
import android.widget.ScrollView;
import android.widget.TextView;

import java.io.File;
import java.io.FileOutputStream;
import java.io.InputStream;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;

public final class MainActivity extends Activity {
    private static final String TAG = "FluttwareRunner";
    private final ProcessRunner runner = new ProcessRunner();
    private final ExecutorService sdkWorker = Executors.newSingleThreadExecutor();
    private volatile boolean dartProbeActive;
    private volatile boolean flutterProbeActive;
    private volatile boolean jdkProbeActive;
    private TextView output;
    private EditText executable;
    private EditText arguments;
    private EditText apkPath;

    private final BroadcastReceiver installReceiver = new BroadcastReceiver() {
        @Override
        public void onReceive(Context context, Intent intent) {
            int status = intent.getIntExtra(
                    PackageInstaller.EXTRA_STATUS,
                    PackageInstaller.STATUS_FAILURE);
            if (status == PackageInstaller.STATUS_PENDING_USER_ACTION) {
                Intent confirmation = intent.getParcelableExtra(Intent.EXTRA_INTENT);
                if (confirmation != null) {
                    confirmation.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
                    startActivity(confirmation);
                }
            } else {
                append("installer status=" + status + " message="
                        + intent.getStringExtra(PackageInstaller.EXTRA_STATUS_MESSAGE));
            }
        }
    };

    @Override
    protected void onCreate(Bundle state) {
        super.onCreate(state);
        setContentView(buildUi());
        IntentFilter filter = new IntentFilter(ApkInstaller.ACTION_INSTALL_STATUS);
        if (Build.VERSION.SDK_INT >= 33) {
            registerReceiver(installReceiver, filter, Context.RECEIVER_NOT_EXPORTED);
        } else {
            registerReceiver(installReceiver, filter);
        }
        append("filesDir=" + getFilesDir());
        append("nativeLibraryDir=" + getApplicationInfo().nativeLibraryDir);
        append("externalFilesDir=" + getExternalFilesDir(null));
        append("androidSdk=" + Build.VERSION.SDK_INT
                + " appTargetSdk=" + getApplicationInfo().targetSdkVersion);
        append("supportedAbis=" + Arrays.toString(Build.SUPPORTED_ABIS));
        append("Automatically running bundled Sketchware-style ARM64 probe...");
        runBundledProbe();
    }

    private LinearLayout buildUi() {
        int padding = Math.round(12 * getResources().getDisplayMetrics().density);
        LinearLayout root = new LinearLayout(this);
        root.setOrientation(LinearLayout.VERTICAL);
        root.setPadding(padding, padding, padding, padding);

        executable = field("Executable", "/system/bin/sh");
        arguments = field("One argument per line", "-c\nprintf 'stdout-ok\\n'; printf 'stderr-ok\\n' >&2; sleep 2; id");
        apkPath = field("APK inside this app's readable storage", new File(getFilesDir(), "workspace/app.apk").getPath());
        root.addView(executable);
        root.addView(arguments);

        LinearLayout toolButtons = new LinearLayout(this);
        Button run = button("Run", view -> runCommand());
        Button bundledProbe = button("Run bundled probe", view -> runBundledProbe());
        Button dartProbe = button("Run Dart probes", view -> runDartProbes());
        Button flutterProbe = button("Run Flutter probes", view -> runFlutterProbes());
        toolButtons.addView(run);
        toolButtons.addView(bundledProbe);
        toolButtons.addView(dartProbe);
        toolButtons.addView(flutterProbe);
        root.addView(toolButtons);

        LinearLayout actionButtons = new LinearLayout(this);
        Button jdkProbe = button("Build Flutter APK", view -> runDirectFlutterBuild());
        Button cancel = button("Cancel", view -> runner.cancel());
        Button install = button("Install APK", view -> installApk());
        actionButtons.addView(jdkProbe);
        actionButtons.addView(cancel);
        actionButtons.addView(install);
        root.addView(actionButtons);
        root.addView(apkPath);

        output = new TextView(this);
        output.setTextColor(Color.rgb(220, 255, 235));
        output.setBackgroundColor(Color.rgb(12, 28, 24));
        output.setTextIsSelectable(true);
        ScrollView scroll = new ScrollView(this);
        scroll.addView(output);
        root.addView(scroll, new LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                0,
                1));
        return root;
    }

    private EditText field(String hint, String value) {
        EditText field = new EditText(this);
        field.setHint(hint);
        field.setText(value);
        return field;
    }

    private Button button(String label, android.view.View.OnClickListener listener) {
        Button button = new Button(this);
        button.setText(label);
        button.setOnClickListener(listener);
        return button;
    }

    private void runCommand() {
        List<String> command = new ArrayList<>();
        command.add(executable.getText().toString());
        for (String argument : arguments.getText().toString().split("\\n", -1)) {
            if (!argument.isEmpty()) {
                command.add(argument);
            }
        }
        Map<String, String> environment = new HashMap<>();
        environment.put("HOME", getFilesDir().getPath());
        environment.put("TMPDIR", getCacheDir().getPath());
        environment.put("PATH", getApplicationInfo().nativeLibraryDir + ":/system/bin:/system/xbin");
        append("$ " + command);
        try {
            runner.start(command, getFilesDir(), environment, new ProcessRunner.Listener() {
                @Override public void onLine(boolean stderr, String line) {
                    append((stderr ? "E: " : "O: ") + line);
                }
                @Override public void onExit(int exitCode, long elapsedMillis) {
                    append("exit=" + exitCode + " elapsedMs=" + elapsedMillis);
                }
                @Override public void onFailure(Throwable error) {
                    append("failure=" + error);
                }
            });
        } catch (RuntimeException error) {
            append("failure=" + error);
        }
    }

    private void runBundledProbe() {
        try {
            File workspace = new File(getFilesDir(), "workspace");
            if (!workspace.isDirectory() && !workspace.mkdirs()) {
                throw new IllegalStateException("Could not create " + workspace);
            }
            File proofFile = new File(workspace, "native-probe-output.txt");
            if (proofFile.exists() && !proofFile.delete()) {
                throw new IllegalStateException("Could not remove old proof file " + proofFile);
            }

            File probe = AssetExecutableInstaller.installArm64Probe(this);
            executable.setText(probe.getAbsolutePath());
            arguments.setText("hello-from-fluttware");
            append("probe.path=" + probe);
            append("probe.sha256=" + AssetExecutableInstaller.sha256(probe));
            append("probe.canExecute=" + probe.canExecute());

            Map<String, String> environment = new HashMap<>();
            environment.put("HOME", getFilesDir().getPath());
            environment.put("TMPDIR", getCacheDir().getPath());
            environment.put("PATH", getApplicationInfo().nativeLibraryDir
                    + ":/system/bin:/system/xbin");
            environment.put("FLUTTWARE_PROBE_TOKEN", "asset-cache-exec");

            runner.start(
                    List.of(probe.getAbsolutePath(), "hello-from-fluttware"),
                    workspace,
                    environment,
                    new ProcessRunner.Listener() {
                        @Override public void onLine(boolean stderr, String line) {
                            append((stderr ? "E: " : "O: ") + line);
                        }

                        @Override public void onExit(int exitCode, long elapsedMillis) {
                            append("probe.exit=" + exitCode + " elapsedMs=" + elapsedMillis);
                            try {
                                String proof = new String(
                                        Files.readAllBytes(proofFile.toPath()),
                                        StandardCharsets.UTF_8).trim();
                                append("proof.file=" + proofFile);
                                append("proof.content=" + proof.replace('\n', '|'));
                            } catch (Exception error) {
                                append("proof.readFailure=" + error);
                            }
                            output.postDelayed(MainActivity.this::runDartProbes, 300);
                        }

                        @Override public void onFailure(Throwable error) {
                            append("probe.failure=" + error);
                        }
                    });
        } catch (Exception error) {
            append("probe.setupFailure=" + error);
        }
    }

    private void runDartProbes() {
        if (dartProbeActive) {
            append("dart.probe=already running");
            return;
        }
        dartProbeActive = true;
        append("dart.install=checking bundled minimal SDK");
        sdkWorker.execute(() -> {
            try {
                DartSdkInstaller.Result sdk = DartSdkInstaller.install(this);
                append("dart.sdkRoot=" + sdk.sdkRoot);
                append("dart.archiveSha256=" + sdk.archiveSha256);
                append("dart.installReused=" + sdk.reused);
                append("dart.installElapsedMs=" + sdk.elapsedMillis);

                File workspace = new File(getFilesDir(), "workspace");
                if (!workspace.isDirectory() && !workspace.mkdirs()) {
                    throw new IllegalStateException("Could not create " + workspace);
                }
                File source = new File(workspace, "check_android_host.dart");
                copyAsset("dart/check_android_host.dart", source);
                File kernel = new File(workspace, "check_android_host.dill");
                File proof = new File(workspace, "dart-source-proof.txt");
                if (kernel.exists() && !kernel.delete()) {
                    throw new IllegalStateException("Could not delete " + kernel);
                }
                if (proof.exists() && !proof.delete()) {
                    throw new IllegalStateException("Could not delete " + proof);
                }

                String dart = sdk.dart().getAbsolutePath();
                String commands = "set -e\n"
                        + "echo FLUTTWARE_DART_STEP_VERSION\n"
                        + dart + " --version\n"
                        + "echo FLUTTWARE_DART_STEP_SOURCE\n"
                        + dart + " " + source.getAbsolutePath() + "\n"
                        + "echo FLUTTWARE_DART_STEP_COMPILE_KERNEL\n"
                        + dart + " compile kernel " + source.getAbsolutePath()
                        + " -o " + kernel.getAbsolutePath() + "\n"
                        + "echo FLUTTWARE_DART_STEP_RUN_KERNEL\n"
                        + dart + " " + kernel.getAbsolutePath() + "\n"
                        + "echo FLUTTWARE_DART_ALL_STEPS_OK\n";

                Map<String, String> environment = new HashMap<>();
                environment.put("HOME", getFilesDir().getAbsolutePath());
                environment.put("TMPDIR", getCacheDir().getAbsolutePath());
                environment.put("PUB_CACHE", new File(getFilesDir(), "pub-cache").getAbsolutePath());
                environment.put("PATH", sdk.sdkRoot.getAbsolutePath() + "/bin:/system/bin:/system/xbin");

                runner.start(
                        List.of("/system/bin/sh", "-c", commands),
                        workspace,
                        environment,
                        new ProcessRunner.Listener() {
                            @Override public void onLine(boolean stderr, String line) {
                                append((stderr ? "DART-E: " : "DART-O: ") + line);
                            }

                            @Override public void onExit(int exitCode, long elapsedMillis) {
                                append("dart.exit=" + exitCode + " elapsedMs=" + elapsedMillis);
                                append("dart.kernel.exists=" + kernel.isFile()
                                        + " size=" + kernel.length());
                                try {
                                    String content = new String(
                                            Files.readAllBytes(proof.toPath()),
                                            StandardCharsets.UTF_8).trim();
                                    append("dart.proof=" + content);
                                } catch (Exception error) {
                                    append("dart.proofFailure=" + error);
                            } finally {
                                dartProbeActive = false;
                            }
                            if (exitCode == 0) {
                                output.postDelayed(MainActivity.this::runFlutterProbes, 300);
                            }
                            }

                            @Override public void onFailure(Throwable error) {
                                dartProbeActive = false;
                                append("dart.failure=" + error);
                            }
                        });
            } catch (Exception error) {
                dartProbeActive = false;
                append("dart.setupFailure=" + error);
            }
        });
    }

    private void runFlutterProbes() {
        if (flutterProbeActive) {
            append("flutter.probe=already running");
            return;
        }
        flutterProbeActive = true;
        append("flutter.install=checking patched Android-host tool");
        sdkWorker.execute(() -> {
            try {
                DartSdkInstaller.Result dartSdk = DartSdkInstaller.install(this);
                FlutterToolInstaller.Result flutterSdk = FlutterToolInstaller.install(
                        this, dartSdk.sdkRoot);
                append("flutter.root=" + flutterSdk.flutterRoot);
                append("flutter.archiveSha256=" + flutterSdk.archiveSha256);
                append("flutter.installReused=" + flutterSdk.reused);
                append("flutter.installElapsedMs=" + flutterSdk.elapsedMillis);

                File workspace = new File(getFilesDir(), "workspace");
                if (!workspace.isDirectory() && !workspace.mkdirs()) {
                    throw new IllegalStateException("Could not create " + workspace);
                }
                File project = new File(workspace, "flutter_cli_project");
                File mainDart = new File(project, "lib/main.dart");
                File gradleWrapper = new File(project, "android/gradle/wrapper/gradle-wrapper.jar");
                File packageConfig = new File(project, ".dart_tool/package_config.json");

                String dart = dartSdk.dart().getAbsolutePath();
                String tool = flutterSdk.toolKernel().getAbsolutePath();
                String flutter = dart + " " + tool;
                String projectPath = project.getAbsolutePath();
                String commands = "set +e\n"
                        + "echo FLUTTWARE_FLUTTER_STEP_VERSION\n"
                        + flutter + " --version --suppress-analytics\n"
                        + "flutter_version_exit=$?\n"
                        + "echo FLUTTWARE_FLUTTER_VERSION_EXIT=$flutter_version_exit\n"
                        + "echo FLUTTWARE_FLUTTER_STEP_CREATE\n"
                        + flutter + " --suppress-analytics --no-version-check create"
                        + " --platforms=android --no-pub --empty --overwrite"
                        + " --project-name=fluttware_sample " + projectPath + "\n"
                        + "flutter_create_exit=$?\n"
                        + "echo FLUTTWARE_FLUTTER_CREATE_EXIT=$flutter_create_exit\n"
                        + "if [ -f " + mainDart.getAbsolutePath() + " ]"
                        + " && [ -f " + gradleWrapper.getAbsolutePath() + " ]; then\n"
                        + "  flutter_project_exit=0\n"
                        + "  echo FLUTTWARE_FLUTTER_PROJECT_FILES_OK\n"
                        + "else\n"
                        + "  flutter_project_exit=1\n"
                        + "  echo FLUTTWARE_FLUTTER_PROJECT_FILES_MISSING\n"
                        + "fi\n"
                        + "echo FLUTTWARE_FLUTTER_STEP_PUB_ONLINE\n"
                        + flutter + " --suppress-analytics --no-version-check pub get"
                        + " --directory " + projectPath + "\n"
                        + "flutter_pub_online_exit=$?\n"
                        + "echo FLUTTWARE_FLUTTER_PUB_ONLINE_EXIT=$flutter_pub_online_exit\n"
                        + "echo FLUTTWARE_FLUTTER_STEP_PUB_OFFLINE\n"
                        + flutter + " --suppress-analytics --no-version-check pub get --offline"
                        + " --directory " + projectPath + "\n"
                        + "flutter_pub_offline_exit=$?\n"
                        + "echo FLUTTWARE_FLUTTER_PUB_OFFLINE_EXIT=$flutter_pub_offline_exit\n"
                        + "if [ $flutter_version_exit -eq 0 ]"
                        + " && [ $flutter_create_exit -eq 0 ]"
                        + " && [ $flutter_project_exit -eq 0 ]; then\n"
                        + "  echo FLUTTWARE_FLUTTER_CORE_STEPS_OK\n"
                        + "else\n"
                        + "  echo FLUTTWARE_FLUTTER_CORE_STEPS_FAILED\n"
                        + "  exit 1\n"
                        + "fi\n"
                        + "if [ $flutter_pub_online_exit -eq 0 ]"
                        + " && [ $flutter_pub_offline_exit -eq 0 ]; then\n"
                        + "  echo FLUTTWARE_FLUTTER_ALL_STEPS_OK\n"
                        + "  exit 0\n"
                        + "fi\n"
                        + "echo FLUTTWARE_FLUTTER_PUB_STEPS_INCOMPLETE\n"
                        + "exit 2\n";

                Map<String, String> environment = new HashMap<>();
                environment.put("FLUTTER_ROOT", flutterSdk.flutterRoot.getAbsolutePath());
                environment.put("FLUTTER_ALREADY_LOCKED", "true");
                environment.put("HOME", getFilesDir().getAbsolutePath());
                environment.put("TMPDIR", getCacheDir().getAbsolutePath());
                environment.put("PUB_CACHE", new File(getFilesDir(), "pub-cache").getAbsolutePath());
                environment.put(
                        "PATH",
                        flutterSdk.compatibilityBin.getAbsolutePath()
                                + ":" + dartSdk.sdkRoot.getAbsolutePath()
                                + "/bin:/system/bin:/system/xbin");

                runner.start(
                        List.of("/system/bin/sh", "-c", commands),
                        workspace,
                        environment,
                        new ProcessRunner.Listener() {
                            @Override public void onLine(boolean stderr, String line) {
                                append((stderr ? "FLUTTER-E: " : "FLUTTER-O: ") + line);
                            }

                            @Override public void onExit(int exitCode, long elapsedMillis) {
                                append("flutter.exit=" + exitCode + " elapsedMs=" + elapsedMillis);
                                append("flutter.project.main=" + mainDart.isFile());
                                append("flutter.project.gradleWrapper=" + gradleWrapper.isFile());
                                append("flutter.project.packageConfig=" + packageConfig.isFile());
                                flutterProbeActive = false;
                                if (exitCode == 0) {
                                    output.postDelayed(
                                            MainActivity.this::runDirectFlutterBuild, 300);
                                }
                            }

                            @Override public void onFailure(Throwable error) {
                                flutterProbeActive = false;
                                append("flutter.failure=" + error);
                            }
                        });
            } catch (Exception error) {
                flutterProbeActive = false;
                append("flutter.setupFailure=" + error);
            }
        });
    }

    private void runJdkGradleProbes() {
        if (jdkProbeActive) {
            append("jdk.probe=already running");
            return;
        }
        jdkProbeActive = true;
        append("jdk.install=checking bundled Android OpenJDK");
        sdkWorker.execute(() -> {
            try {
                DartSdkInstaller.Result dartSdk = DartSdkInstaller.install(this);
                FlutterToolInstaller.Result flutterSdk = FlutterToolInstaller.install(
                        this, dartSdk.sdkRoot);
                JdkInstaller.Result jdk = JdkInstaller.install(this);
                AndroidSdkInstaller.Result androidSdk = AndroidSdkInstaller.install(this);
                append("jdk.javaHome=" + jdk.javaHome);
                append("jdk.archiveSha256=" + jdk.archiveSha256);
                append("jdk.installReused=" + jdk.reused);
                append("jdk.installElapsedMs=" + jdk.elapsedMillis);
                append("androidSdk.root=" + androidSdk.sdkRoot);
                append("androidSdk.archiveSha256=" + androidSdk.archiveSha256);
                append("androidSdk.installReused=" + androidSdk.reused);
                append("androidSdk.installElapsedMs=" + androidSdk.elapsedMillis);

                File workspace = new File(getFilesDir(), "workspace");
                File androidProject = new File(workspace, "flutter_cli_project/android");
                File wrapperJar = new File(androidProject, "gradle/wrapper/gradle-wrapper.jar");
                File wrapperProperties = new File(
                        androidProject, "gradle/wrapper/gradle-wrapper.properties");
                if (!wrapperJar.isFile() || !wrapperProperties.isFile()) {
                    jdkProbeActive = false;
                    append("jdk.gradleSetupFailure=Flutter project or Gradle wrapper is missing");
                    append("jdk.gradleSetupHint=Run Flutter probes first");
                    return;
                }

                File appBuildFile = new File(androidProject, "app/build.gradle.kts");
                String appBuild = new String(
                        Files.readAllBytes(appBuildFile.toPath()), StandardCharsets.UTF_8);
                String ndkPin = "    ndkVersion = flutter.ndkVersion\n";
                String noNdkComment =
                        "    // Fluttware: no NDK is needed for this Dart-only debug app.\n";
                if (appBuild.contains(ndkPin)) {
                    writeTextFile(appBuildFile, appBuild.replace(ndkPin, noNdkComment));
                } else if (!appBuild.contains(noNdkComment)) {
                    throw new IllegalStateException(
                            "Expected Flutter NDK template line is missing: " + appBuildFile);
                }
                append("androidProject.ndkPinRemoved=true");

                writeTextFile(
                        new File(androidProject, "local.properties"),
                        "sdk.dir=" + androidSdk.sdkRoot.getAbsolutePath() + "\n"
                                + "flutter.sdk=" + flutterSdk.flutterRoot.getAbsolutePath() + "\n");
                writeTextFile(
                        new File(androidProject, "gradle.properties"),
                        "org.gradle.jvmargs=-Xmx1536m -XX:MaxMetaspaceSize=512m"
                                + " -XX:ReservedCodeCacheSize=256m -Dfile.encoding=UTF-8"
                                + " -Duser.home=" + getFilesDir().getAbsolutePath() + "\n"
                                + "org.gradle.daemon=false\n"
                                + "org.gradle.vfs.watch=false\n"
                                + "android.useAndroidX=true\n"
                                // Flutter 3.44's Gradle plugin still needs the legacy AGP 9
                                // DSL and the external Kotlin Gradle plugin during migration.
                                + "android.newDsl=false\n"
                                + "android.builtInKotlin=false\n"
                                + "android.aapt2FromMavenOverride="
                                + androidSdk.aapt2().getAbsolutePath() + "\n");

                File gradleHome = new File(getFilesDir(), "gradle-cache");
                File javaTemp = new File(getCacheDir(), "java-tmp");
                if (!gradleHome.isDirectory() && !gradleHome.mkdirs()) {
                    throw new IllegalStateException("Could not create " + gradleHome);
                }
                if (!javaTemp.isDirectory() && !javaTemp.mkdirs()) {
                    throw new IllegalStateException("Could not create " + javaTemp);
                }

                String java = jdk.java().getAbsolutePath();
                String javac = new File(jdk.javaHome, "bin/javac").getAbsolutePath();
                String javaOptions = " -Djava.io.tmpdir=" + javaTemp.getAbsolutePath()
                        + " -Duser.home=" + getFilesDir().getAbsolutePath()
                        + " -Dorg.gradle.native=false"
                        + " -Dorg.gradle.daemon=false"
                        + " -Dorg.gradle.vfs.watch=false";
                String gradle = java + javaOptions
                        + " -classpath " + wrapperJar.getAbsolutePath()
                        + " org.gradle.wrapper.GradleWrapperMain";
                String aapt2 = androidSdk.aapt2().getAbsolutePath();
                String aaptOverride = " -Pandroid.aapt2FromMavenOverride=" + aapt2
                        + " -Pfluttware.androidHost=true";
                String commands = "set +e\n"
                        + "echo FLUTTWARE_JDK_STEP_JAVA_VERSION\n"
                        + java + " --version\n"
                        + "java_exit=$?\n"
                        + "echo FLUTTWARE_JAVA_VERSION_EXIT=$java_exit\n"
                        + "echo FLUTTWARE_JDK_STEP_JAVAC_VERSION\n"
                        + javac + " -version\n"
                        + "javac_exit=$?\n"
                        + "echo FLUTTWARE_JAVAC_VERSION_EXIT=$javac_exit\n"
                        + "echo FLUTTWARE_ANDROID_STEP_AAPT2_VERSION\n"
                        + aapt2 + " version\n"
                        + "aapt2_exit=$?\n"
                        + "echo FLUTTWARE_AAPT2_VERSION_EXIT=$aapt2_exit\n"
                        + "echo FLUTTWARE_JDK_STEP_GRADLE_ONLINE\n"
                        + gradle + " --no-daemon --version\n"
                        + "gradle_online_exit=$?\n"
                        + "echo FLUTTWARE_GRADLE_ONLINE_EXIT=$gradle_online_exit\n"
                        + "echo FLUTTWARE_JDK_STEP_GRADLE_OFFLINE\n"
                        + gradle + " --offline --no-daemon --version\n"
                        + "gradle_offline_exit=$?\n"
                        + "echo FLUTTWARE_GRADLE_OFFLINE_EXIT=$gradle_offline_exit\n"
                        + "echo FLUTTWARE_ANDROID_STEP_GRADLE_CONFIG_ONLINE\n"
                        + gradle + aaptOverride + " --no-daemon help --stacktrace\n"
                        + "gradle_config_online_exit=$?\n"
                        + "echo FLUTTWARE_GRADLE_CONFIG_ONLINE_EXIT="
                        + "$gradle_config_online_exit\n"
                        + "echo FLUTTWARE_ANDROID_STEP_GRADLE_CONFIG_OFFLINE\n"
                        + gradle + aaptOverride
                        + " --offline --no-daemon help --stacktrace\n"
                        + "gradle_config_offline_exit=$?\n"
                        + "echo FLUTTWARE_GRADLE_CONFIG_OFFLINE_EXIT="
                        + "$gradle_config_offline_exit\n"
                        + "if [ $java_exit -eq 0 ] && [ $javac_exit -eq 0 ]"
                        + " && [ $aapt2_exit -eq 0 ]"
                        + " && [ $gradle_online_exit -eq 0 ]"
                        + " && [ $gradle_offline_exit -eq 0 ]"
                        + " && [ $gradle_config_online_exit -eq 0 ]"
                        + " && [ $gradle_config_offline_exit -eq 0 ]; then\n"
                        + "  echo FLUTTWARE_ANDROID_GRADLE_CONFIG_OK\n"
                        + "  echo FLUTTWARE_JDK_GRADLE_ALL_STEPS_OK\n"
                        + "  exit 0\n"
                        + "fi\n"
                        + "echo FLUTTWARE_JDK_GRADLE_STEPS_INCOMPLETE\n"
                        + "exit 1\n";

                Map<String, String> environment = new HashMap<>();
                environment.put("HOME", getFilesDir().getAbsolutePath());
                environment.put("TMPDIR", javaTemp.getAbsolutePath());
                environment.put("JAVA_HOME", jdk.javaHome.getAbsolutePath());
                environment.put("GRADLE_USER_HOME", gradleHome.getAbsolutePath());
                environment.put("ANDROID_HOME", androidSdk.sdkRoot.getAbsolutePath());
                environment.put("ANDROID_SDK_ROOT", androidSdk.sdkRoot.getAbsolutePath());
                environment.put("FLUTTER_ROOT", flutterSdk.flutterRoot.getAbsolutePath());
                environment.put("FLUTTER_ALREADY_LOCKED", "true");
                environment.put(
                        "PUB_CACHE", new File(getFilesDir(), "pub-cache").getAbsolutePath());
                environment.put(
                        "LD_LIBRARY_PATH",
                        androidSdk.libraryPath() + ":" + jdk.libraryPath());
                environment.put(
                        "PATH",
                        new File(jdk.javaHome, "bin").getAbsolutePath()
                                + ":" + flutterSdk.compatibilityBin.getAbsolutePath()
                                + ":" + new File(flutterSdk.flutterRoot, "bin").getAbsolutePath()
                                + ":" + new File(dartSdk.sdkRoot, "bin").getAbsolutePath()
                                + ":/system/bin:/system/xbin");

                runner.start(
                        List.of("/system/bin/sh", "-c", commands),
                        androidProject,
                        environment,
                        new ProcessRunner.Listener() {
                            @Override public void onLine(boolean stderr, String line) {
                                append((stderr ? "JDK-E: " : "JDK-O: ") + line);
                            }

                            @Override public void onExit(int exitCode, long elapsedMillis) {
                                append("jdk.exit=" + exitCode + " elapsedMs=" + elapsedMillis);
                                append("jdk.gradleCache=" + gradleHome);
                                jdkProbeActive = false;
                            }

                            @Override public void onFailure(Throwable error) {
                                jdkProbeActive = false;
                                append("jdk.failure=" + error);
                            }
                        });
            } catch (Exception error) {
                jdkProbeActive = false;
                append("jdk.setupFailure=" + error);
            }
        });
    }

    private void runDirectApkBuild() {
        if (jdkProbeActive) {
            append("direct.probe=already running");
            return;
        }
        jdkProbeActive = true;
        append("direct.install=checking JDK and Android SDK");
        sdkWorker.execute(() -> {
            try {
                JdkInstaller.Result jdk = JdkInstaller.install(this);
                AndroidSdkInstaller.Result androidSdk = AndroidSdkInstaller.install(this);
                File workspace = new File(getFilesDir(), "workspace");
                if (!workspace.isDirectory() && !workspace.mkdirs()) {
                    throw new IllegalStateException("Could not create " + workspace);
                }
                File script = new File(getCacheDir(), "fluttware-direct-android-build.sh");
                copyAsset("direct-build/direct-android-build.sh", script);
                android.system.Os.chmod(script.getAbsolutePath(), 0700);
                File outputApk = new File(workspace, "app.apk");

                append("direct.javaHome=" + jdk.javaHome);
                append("direct.androidSdk=" + androidSdk.sdkRoot);
                append("direct.script=" + script);

                Map<String, String> environment = new HashMap<>();
                environment.put("HOME", getFilesDir().getAbsolutePath());
                environment.put("TMPDIR", getCacheDir().getAbsolutePath());
                environment.put("JAVA_HOME", jdk.javaHome.getAbsolutePath());
                environment.put("ANDROID_HOME", androidSdk.sdkRoot.getAbsolutePath());
                environment.put("ANDROID_SDK_ROOT", androidSdk.sdkRoot.getAbsolutePath());
                environment.put(
                        "LD_LIBRARY_PATH",
                        androidSdk.libraryPath() + ":" + jdk.libraryPath());
                environment.put(
                        "PATH",
                        new File(jdk.javaHome, "bin").getAbsolutePath()
                                + ":/system/bin:/system/xbin");

                runner.start(
                        List.of(
                                "/system/bin/sh",
                                script.getAbsolutePath(),
                                jdk.javaHome.getAbsolutePath(),
                                androidSdk.sdkRoot.getAbsolutePath(),
                                workspace.getAbsolutePath()),
                        workspace,
                        environment,
                        new ProcessRunner.Listener() {
                            @Override public void onLine(boolean stderr, String line) {
                                append((stderr ? "DIRECT-E: " : "DIRECT-O: ") + line);
                            }

                            @Override public void onExit(int exitCode, long elapsedMillis) {
                                append("direct.exit=" + exitCode + " elapsedMs=" + elapsedMillis);
                                append("direct.apk.exists=" + outputApk.isFile()
                                        + " size=" + outputApk.length());
                                runOnUiThread(() -> apkPath.setText(outputApk.getAbsolutePath()));
                                jdkProbeActive = false;
                            }

                            @Override public void onFailure(Throwable error) {
                                jdkProbeActive = false;
                                append("direct.failure=" + error);
                            }
                        });
            } catch (Exception error) {
                jdkProbeActive = false;
                append("direct.setupFailure=" + error);
            }
        });
    }

    private void runDirectFlutterBuild() {
        if (jdkProbeActive) {
            append("direct.flutter=already running");
            return;
        }
        jdkProbeActive = true;
        append("direct.flutter.install=checking all bundled toolchains");
        sdkWorker.execute(() -> {
            try {
                DartSdkInstaller.Result dartSdk = DartSdkInstaller.install(this);
                FlutterToolInstaller.Result flutterSdk = FlutterToolInstaller.install(
                        this, dartSdk.sdkRoot);
                FlutterDebugInstaller.Result flutterDebug = FlutterDebugInstaller.install(this);
                JdkInstaller.Result jdk = JdkInstaller.install(this);
                AndroidSdkInstaller.Result androidSdk = AndroidSdkInstaller.install(this);
                File workspace = new File(getFilesDir(), "workspace");
                if (!workspace.isDirectory() && !workspace.mkdirs()) {
                    throw new IllegalStateException("Could not create " + workspace);
                }

                File kernelScript = new File(getCacheDir(), "fluttware-flutter-kernel.sh");
                File apkScript = new File(getCacheDir(), "fluttware-direct-flutter-apk.sh");
                File pipelineScript = new File(getCacheDir(), "fluttware-flutter-pipeline.sh");
                copyAsset("direct-build/flutter-kernel-probe.sh", kernelScript);
                copyAsset("direct-build/direct-flutter-debug-build.sh", apkScript);
                copyAsset("direct-build/direct-flutter-pipeline.sh", pipelineScript);

                File outputApk = new File(workspace, "flutter-app.apk");
                append("direct.flutter.root=" + flutterSdk.flutterRoot);
                append("direct.flutter.debugRoot=" + flutterDebug.debugRoot);
                append("direct.flutter.debugArchiveSha256="
                        + flutterDebug.archiveSha256);
                append("direct.flutter.debugInstallReused=" + flutterDebug.reused);
                append("direct.flutter.debugInstallElapsedMs="
                        + flutterDebug.elapsedMillis);

                Map<String, String> environment = new HashMap<>();
                environment.put("HOME", getFilesDir().getAbsolutePath());
                environment.put("TMPDIR", getCacheDir().getAbsolutePath());
                environment.put("JAVA_HOME", jdk.javaHome.getAbsolutePath());
                environment.put("ANDROID_HOME", androidSdk.sdkRoot.getAbsolutePath());
                environment.put("ANDROID_SDK_ROOT", androidSdk.sdkRoot.getAbsolutePath());
                environment.put(
                        "PUB_CACHE", new File(getFilesDir(), "pub-cache").getAbsolutePath());
                environment.put(
                        "LD_LIBRARY_PATH",
                        androidSdk.libraryPath() + ":" + jdk.libraryPath());
                environment.put(
                        "PATH",
                        new File(jdk.javaHome, "bin").getAbsolutePath()
                                + ":" + new File(dartSdk.sdkRoot, "bin").getAbsolutePath()
                                + ":/system/bin:/system/xbin");

                runner.start(
                        List.of(
                                "/system/bin/sh",
                                pipelineScript.getAbsolutePath(),
                                kernelScript.getAbsolutePath(),
                                apkScript.getAbsolutePath(),
                                getFilesDir().getAbsolutePath(),
                                flutterSdk.flutterRoot.getAbsolutePath(),
                                flutterDebug.debugRoot.getAbsolutePath(),
                                jdk.javaHome.getAbsolutePath(),
                                androidSdk.sdkRoot.getAbsolutePath(),
                                workspace.getAbsolutePath()),
                        workspace,
                        environment,
                        new ProcessRunner.Listener() {
                            @Override public void onLine(boolean stderr, String line) {
                                append((stderr ? "FLUTTER-BUILD-E: " : "FLUTTER-BUILD-O: ")
                                        + line);
                            }

                            @Override public void onExit(int exitCode, long elapsedMillis) {
                                append("direct.flutter.exit=" + exitCode
                                        + " elapsedMs=" + elapsedMillis);
                                append("direct.flutter.apk.exists=" + outputApk.isFile()
                                        + " size=" + outputApk.length());
                                runOnUiThread(() -> apkPath.setText(outputApk.getAbsolutePath()));
                                jdkProbeActive = false;
                            }

                            @Override public void onFailure(Throwable error) {
                                jdkProbeActive = false;
                                append("direct.flutter.failure=" + error);
                            }
                        });
            } catch (Exception error) {
                jdkProbeActive = false;
                append("direct.flutter.setupFailure=" + error);
            }
        });
    }

    private void writeTextFile(File file, String text) throws Exception {
        File parent = file.getParentFile();
        if (parent != null && !parent.isDirectory() && !parent.mkdirs()) {
            throw new IllegalStateException("Could not create " + parent);
        }
        try (FileOutputStream output = new FileOutputStream(file)) {
            output.write(text.getBytes(StandardCharsets.UTF_8));
            output.getFD().sync();
        }
    }

    private void copyAsset(String assetPath, File destination) throws Exception {
        File parent = destination.getParentFile();
        if (parent != null && !parent.isDirectory() && !parent.mkdirs()) {
            throw new IllegalStateException("Could not create " + parent);
        }
        try (InputStream input = getAssets().open(assetPath);
             FileOutputStream output = new FileOutputStream(destination)) {
            byte[] buffer = new byte[64 * 1024];
            int count;
            while ((count = input.read(buffer)) >= 0) {
                output.write(buffer, 0, count);
            }
            output.getFD().sync();
        }
    }

    private void installApk() {
        try {
            ApkInstaller.install(this, new File(apkPath.getText().toString()));
            append("APK staged; waiting for Android confirmation");
        } catch (Exception error) {
            append("install failure=" + error);
        }
    }

    private void append(String line) {
        Log.i(TAG, line);
        runOnUiThread(() -> output.append(line + "\n"));
    }

    @Override
    protected void onDestroy() {
        unregisterReceiver(installReceiver);
        runner.close();
        sdkWorker.shutdownNow();
        super.onDestroy();
    }
}
