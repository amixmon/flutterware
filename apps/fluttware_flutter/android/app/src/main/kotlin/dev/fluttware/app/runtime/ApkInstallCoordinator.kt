package com.flutterware.app.runtime

import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.pm.PackageInstaller
import java.io.File
import java.io.FileInputStream

object ApkInstallCoordinator {
    const val ACTION_INSTALL_STATUS = "com.flutterware.app.INSTALL_STATUS"

    fun stage(context: Context, apk: File) {
        require(apk.isFile) { "APK does not exist: $apk" }
        val installer = context.packageManager.packageInstaller
        val params = PackageInstaller.SessionParams(PackageInstaller.SessionParams.MODE_FULL_INSTALL)
            .apply { setSize(apk.length()) }
        val sessionId = installer.createSession(params)

        try {
            installer.openSession(sessionId).use { session ->
                FileInputStream(apk).use { input ->
                    session.openWrite("base.apk", 0, apk.length()).use { output ->
                        input.copyTo(output, 1024 * 1024)
                        session.fsync(output)
                    }
                }
                val callback = Intent(ACTION_INSTALL_STATUS).setPackage(context.packageName)
                val pending = PendingIntent.getBroadcast(
                    context,
                    sessionId,
                    callback,
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_MUTABLE,
                )
                session.commit(pending.intentSender)
            }
        } catch (error: Throwable) {
            installer.abandonSession(sessionId)
            throw error
        }
    }
}
