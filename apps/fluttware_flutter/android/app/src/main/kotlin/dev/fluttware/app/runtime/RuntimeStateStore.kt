package com.flutterware.app.runtime

import android.os.Handler
import android.os.Looper

object RuntimeStateStore {
    private val lock = Any()
    private val mainHandler = Handler(Looper.getMainLooper())
    private val logs = ArrayDeque<String>()

    private var listener: ((Map<String, Any?>) -> Unit)? = null
    private var phase = "idle"
    private var message = "Ready"
    private var busy = false
    private var progress = 0.0
    private var apkPath: String? = null
    private var packageName: String? = null
    private var projectId: String? = null
    private var error: String? = null

    fun setListener(value: ((Map<String, Any?>) -> Unit)?) {
        synchronized(lock) { listener = value }
        if (value != null) emit(snapshot())
    }

    fun start(id: String) {
        synchronized(lock) {
            logs.clear()
            phase = "preparing"
            message = "Preparing local runtime"
            busy = true
            progress = 0.02
            apkPath = null
            packageName = null
            projectId = id
            error = null
        }
        emitState()
    }

    fun update(newPhase: String, newMessage: String, newProgress: Double) {
        synchronized(lock) {
            phase = newPhase
            message = newMessage
            progress = newProgress.coerceIn(0.0, 1.0)
        }
        emitState()
    }

    fun log(line: String) {
        synchronized(lock) {
            logs.addLast(line)
            while (logs.size > 300) logs.removeFirst()
        }
        emit(mapOf("type" to "log", "line" to line))
    }

    fun complete(apk: String, generatedPackage: String) {
        synchronized(lock) {
            phase = "completed"
            message = "APK ready"
            progress = 1.0
            busy = false
            apkPath = apk
            packageName = generatedPackage
            error = null
        }
        emitState()
    }

    fun fail(throwable: Throwable) {
        val detail = throwable.message ?: throwable.javaClass.simpleName
        synchronized(lock) {
            phase = "failed"
            message = "Build failed"
            busy = false
            error = detail
        }
        log("ERROR: $detail")
        emitState()
    }

    fun cancelled() {
        synchronized(lock) {
            phase = "cancelled"
            message = "Build cancelled"
            busy = false
            error = null
        }
        emitState()
    }

    fun installation(messageText: String, installed: Boolean = false) {
        synchronized(lock) {
            message = messageText
            if (installed) phase = "installed"
        }
        emitState()
    }

    fun isBusy(): Boolean = synchronized(lock) { busy }

    fun currentApk(): String? = synchronized(lock) { apkPath }

    fun currentPackage(): String? = synchronized(lock) { packageName }

    fun snapshot(): Map<String, Any?> = synchronized(lock) {
        mapOf(
            "type" to "state",
            "phase" to phase,
            "message" to message,
            "busy" to busy,
            "progress" to progress,
            "apkPath" to apkPath,
            "packageName" to packageName,
            "projectId" to projectId,
            "error" to error,
            "logs" to logs.toList(),
        )
    }

    private fun emitState() = emit(snapshot())

    private fun emit(event: Map<String, Any?>) {
        val target = synchronized(lock) { listener }
        if (target != null) mainHandler.post { target(event) }
    }
}
