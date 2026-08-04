package dev.fluttware.runner;

import android.app.PendingIntent;
import android.content.Context;
import android.content.Intent;
import android.content.pm.PackageInstaller;

import java.io.File;
import java.io.FileInputStream;
import java.io.OutputStream;

/** Stages an APK through Android's supported, user-mediated PackageInstaller API. */
public final class ApkInstaller {
    public static final String ACTION_INSTALL_STATUS =
            "dev.fluttware.runner.INSTALL_STATUS";

    private ApkInstaller() {}

    public static void install(Context context, File apk) throws Exception {
        if (!apk.isFile()) {
            throw new IllegalArgumentException("APK does not exist: " + apk);
        }
        PackageInstaller installer = context.getPackageManager().getPackageInstaller();
        PackageInstaller.SessionParams params = new PackageInstaller.SessionParams(
                PackageInstaller.SessionParams.MODE_FULL_INSTALL);
        params.setSize(apk.length());
        int sessionId = installer.createSession(params);

        try (PackageInstaller.Session session = installer.openSession(sessionId)) {
            // PackageInstaller rejects commit() while any stream opened by this
            // session is still alive. Keep the copy in its own nested scope so
            // both streams are closed before commit().
            try (FileInputStream input = new FileInputStream(apk);
                 OutputStream output = session.openWrite("base.apk", 0, apk.length())) {
                byte[] buffer = new byte[1024 * 1024];
                int count;
                while ((count = input.read(buffer)) >= 0) {
                    output.write(buffer, 0, count);
                }
                session.fsync(output);
            }

            Intent callback = new Intent(ACTION_INSTALL_STATUS)
                    .setPackage(context.getPackageName());
            PendingIntent pending = PendingIntent.getBroadcast(
                    context,
                    sessionId,
                    callback,
                    PendingIntent.FLAG_UPDATE_CURRENT | PendingIntent.FLAG_MUTABLE);
            session.commit(pending.getIntentSender());
        } catch (Exception error) {
            installer.abandonSession(sessionId);
            throw error;
        }
    }
}
