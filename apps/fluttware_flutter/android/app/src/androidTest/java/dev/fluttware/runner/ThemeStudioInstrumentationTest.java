package dev.fluttware.runner;

import android.content.Context;

import androidx.test.ext.junit.runners.AndroidJUnit4;
import androidx.test.platform.app.InstrumentationRegistry;

import com.flutterware.app.projects.ProjectStore;
import com.flutterware.app.runtime.RuntimeService;
import com.flutterware.app.runtime.RuntimeStateStore;

import org.junit.Test;
import org.junit.runner.RunWith;

import java.io.File;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.util.HashMap;
import java.util.Map;

import static org.junit.Assert.assertEquals;
import static org.junit.Assert.assertFalse;
import static org.junit.Assert.assertTrue;

/** Device coverage for theme metadata persistence and generated-source parity. */
@RunWith(AndroidJUnit4.class)
public final class ThemeStudioInstrumentationTest {
    @Test
    public void testThemeSettingsRegenerateLightAndDarkMaterialThemes() throws Exception {
        Context context = InstrumentationRegistry.getInstrumentation().getTargetContext();
        String id = "themetest" + Long.toString(System.currentTimeMillis()).substring(8);
        File project = new File(new File(context.getFilesDir(), "projects"), id);

        try {
            Map<String, Object> projectValues = new HashMap<>();
            projectValues.put("id", id);
            projectValues.put("name", "Theme test");
            projectValues.put("packageName", "dev.flutterware." + id);
            ProjectStore.INSTANCE.create(context, projectValues);

            Map<String, Object> settings = new HashMap<>();
            settings.put("mode", "dark");
            settings.put("seedColor", 0xFF6750A4L);
            settings.put("fontFamily", "Roboto");
            settings.put("cornerRadius", 24.0);
            settings.put("cardElevation", 3.0);
            settings.put("inputFilled", false);
            Map<String, Object> updated = ProjectStore.INSTANCE.updateTheme(
                    context, id, settings);

            assertEquals(4, updated.get("schemaVersion"));
            Map<?, ?> storedTheme = (Map<?, ?>) updated.get("theme");
            assertEquals("dark", storedTheme.get("mode"));
            assertEquals(24.0, (Double) storedTheme.get("cornerRadius"), 0.0);
            assertFalse((Boolean) storedTheme.get("inputFilled"));

            String app = read(new File(project, "lib/app/app.dart"));
            assertTrue(app, app.contains("theme: buildAppTheme(Brightness.light)"));
            assertTrue(app, app.contains("darkTheme: buildAppTheme(Brightness.dark)"));
            assertTrue(app, app.contains("themeMode: ThemeMode.dark"));

            String theme = read(new File(project, "lib/core/theme/app_theme.dart"));
            assertTrue(theme, theme.contains("useMaterial3: true"));
            assertTrue(theme, theme.contains("const seedColor = Color(0xFF6750A4)"));
            assertTrue(theme, theme.contains("const cornerRadius = 24.0"));
            assertTrue(theme, theme.contains("fontFamily: 'Roboto'"));
            assertTrue(theme, theme.contains("elevation: 3.0"));
            assertTrue(theme, theme.contains("filled: false"));

            String page = read(new File(
                    project, "lib/features/home/presentation/pages/home_page.dart"));
            assertTrue(page, page.contains("body: SizedBox.expand(child: Column("));

            RuntimeService.Companion.start(
                    context, id, "Theme test", "dev.flutterware." + id);
            Map<String, ?> buildState = waitForBuild();
            assertEquals(buildState.toString(), "completed", buildState.get("phase"));
            File apk = new File((String) buildState.get("apkPath"));
            assertTrue(apk.toString(), apk.isFile() && apk.length() > 0);
        } finally {
            deleteRecursively(project);
        }
    }

    private static Map<String, ?> waitForBuild() throws Exception {
        long deadline = System.currentTimeMillis() + 6 * 60 * 1000L;
        Map<String, ?> state;
        do {
            Thread.sleep(500);
            state = RuntimeStateStore.INSTANCE.snapshot();
            if (!Boolean.TRUE.equals(state.get("busy")) &&
                    !"idle".equals(state.get("phase"))) {
                return state;
            }
        } while (System.currentTimeMillis() < deadline);
        throw new AssertionError("Theme build timed out: " + state);
    }

    private static String read(File file) throws Exception {
        return new String(Files.readAllBytes(file.toPath()), StandardCharsets.UTF_8);
    }

    private static void deleteRecursively(File file) {
        File[] children = file.listFiles();
        if (children != null) {
            for (File child : children) deleteRecursively(child);
        }
        if (file.exists() && !file.delete()) {
            throw new AssertionError("Could not delete test project " + file);
        }
    }
}
