package com.flutterware.app.runtime

import java.io.BufferedReader
import java.io.File
import java.io.InputStreamReader
import java.nio.charset.StandardCharsets
import java.util.concurrent.Executors
import java.util.concurrent.TimeUnit

class ProcessExecutor(private val onLine: (String) -> Unit) {
    data class Result(val exitCode: Int, val elapsedMillis: Long)

    @Volatile private var activeProcess: Process? = null
    @Volatile private var cancelRequested = false

    fun run(
        command: List<String>,
        workingDirectory: File,
        environment: Map<String, String>,
    ): Result {
        check(activeProcess == null) { "Another native process is already running" }
        cancelRequested = false
        val started = System.currentTimeMillis()
        onLine("$ ${command.joinToString(" ")}")

        val process = ProcessBuilder(command)
            .directory(workingDirectory)
            .redirectErrorStream(false)
            .apply { environment().putAll(environment) }
            .start()
        activeProcess = process

        val pumps = Executors.newFixedThreadPool(2) { task ->
            Thread(task, "fluttware-output").apply { isDaemon = true }
        }
        val stdout = pumps.submit { pump(process.inputStream, "") }
        val stderr = pumps.submit { pump(process.errorStream, "E: ") }

        try {
            val exitCode = process.waitFor()
            stdout.get(3, TimeUnit.SECONDS)
            stderr.get(3, TimeUnit.SECONDS)
            if (cancelRequested) throw InterruptedException("Build cancelled")
            return Result(exitCode, System.currentTimeMillis() - started)
        } finally {
            activeProcess = null
            pumps.shutdownNow()
        }
    }

    fun cancel() {
        cancelRequested = true
        activeProcess?.let { process ->
            process.destroy()
            if (!process.waitFor(1200, TimeUnit.MILLISECONDS)) process.destroyForcibly()
        }
    }

    private fun pump(input: java.io.InputStream, prefix: String) {
        BufferedReader(InputStreamReader(input, StandardCharsets.UTF_8)).use { reader ->
            while (true) {
                val line = reader.readLine() ?: break
                onLine(prefix + line)
            }
        }
    }
}
