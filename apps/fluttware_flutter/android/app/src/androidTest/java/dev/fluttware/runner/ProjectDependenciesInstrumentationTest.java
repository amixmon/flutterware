package dev.fluttware.runner;

import android.content.Context;

import androidx.test.ext.junit.runners.AndroidJUnit4;
import androidx.test.platform.app.InstrumentationRegistry;

import com.flutterware.app.projects.ProjectStore;

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

/** Device coverage for project metadata and deterministic pubspec dependency editing. */
@RunWith(AndroidJUnit4.class)
public final class ProjectDependenciesInstrumentationTest {
    @Test
    public void testAddUpdateAndRemoveManagedDependency() throws Exception {
        Context context = InstrumentationRegistry.getInstrumentation().getTargetContext();
        String id = "pkgtest" + Long.toString(System.currentTimeMillis()).substring(7);
        File project = new File(new File(context.getFilesDir(), "projects"), id);

        try {
            Map<String, Object> values = new HashMap<>();
            values.put("id", id);
            values.put("name", "Package test");
            values.put("packageName", "dev.flutterware." + id);
            ProjectStore.INSTANCE.create(context, values);

            Map<String, Object> dependency = new HashMap<>();
            dependency.put("name", "collection");
            dependency.put("constraint", "^1.19.0");
            dependency.put("compatibility", "pureDart");
            assertEquals(
                    "collection",
                    ProjectStore.INSTANCE.upsertDependency(context, id, dependency).get(0).get("name"));

            File pubspec = new File(project, "pubspec.yaml");
            String first = read(pubspec);
            assertTrue(first, first.contains("  # Flutterware-managed dependencies."));
            assertTrue(first, first.contains("  collection: ^1.19.0"));

            dependency.put("constraint", ">=1.18.0 <2.0.0");
            ProjectStore.INSTANCE.upsertDependency(context, id, dependency);
            String updated = read(pubspec);
            assertTrue(updated, updated.contains("  collection: >=1.18.0 <2.0.0"));
            assertEquals(1, count(updated, "# Flutterware-managed dependencies."));

            assertTrue(
                    ProjectStore.INSTANCE.removeDependency(context, id, "collection").isEmpty());
            String removed = read(pubspec);
            assertFalse(removed, removed.contains("Flutterware-managed dependencies"));
            assertTrue(removed, removed.contains("  flutter:\n    sdk: flutter"));
        } finally {
            deleteRecursively(project);
        }
    }

    private static int count(String source, String pattern) {
        int count = 0;
        int index = 0;
        while ((index = source.indexOf(pattern, index)) >= 0) {
            count++;
            index += pattern.length();
        }
        return count;
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
