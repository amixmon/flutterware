package dev.fluttware.runner;

import java.io.BufferedReader;
import java.io.Closeable;
import java.io.File;
import java.io.IOException;
import java.io.InputStream;
import java.io.InputStreamReader;
import java.nio.charset.StandardCharsets;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.Future;
import java.util.concurrent.TimeUnit;
import java.util.concurrent.TimeoutException;
import java.util.concurrent.atomic.AtomicInteger;

/** Runs one child process and drains both pipes to prevent child-process stalls. */
public final class ProcessRunner implements Closeable {
    public interface Listener {
        void onLine(boolean stderr, String line);
        void onExit(int exitCode, long elapsedMillis);
        void onFailure(Throwable error);
    }

    private final AtomicInteger workerId = new AtomicInteger();
    private final ExecutorService workers = Executors.newCachedThreadPool(task -> {
        Thread thread = new Thread(task, "fluttware-process-" + workerId.incrementAndGet());
        thread.setDaemon(true);
        return thread;
    });
    private volatile Process activeProcess;
    private volatile Future<?> activeTask;
    private volatile boolean cancelRequested;

    public synchronized void start(
            List<String> command,
            File workingDirectory,
            Map<String, String> environment,
            Listener listener) {
        if (activeTask != null && !activeTask.isDone()) {
            throw new IllegalStateException("A process is already running");
        }
        cancelRequested = false;
        List<String> safeCommand = new ArrayList<>(command);
        activeTask = workers.submit(() -> run(safeCommand, workingDirectory, environment, listener));
    }

    private void run(
            List<String> command,
            File workingDirectory,
            Map<String, String> environment,
            Listener listener) {
        long started = System.currentTimeMillis();
        try {
            ProcessBuilder builder = new ProcessBuilder(command);
            builder.directory(workingDirectory);
            builder.environment().putAll(environment);
            builder.redirectErrorStream(false);
            Process process = builder.start();
            activeProcess = process;

            Future<?> stdout = workers.submit(() -> pump(process.getInputStream(), false, listener));
            Future<?> stderr = workers.submit(() -> pump(process.getErrorStream(), true, listener));
            int exitCode = process.waitFor();
            if (cancelRequested) {
                closeQuietly(process.getInputStream());
                closeQuietly(process.getErrorStream());
                stdout.cancel(true);
                stderr.cancel(true);
            } else {
                awaitPump(stdout, process.getInputStream());
                awaitPump(stderr, process.getErrorStream());
            }
            listener.onExit(exitCode, System.currentTimeMillis() - started);
        } catch (Throwable error) {
            listener.onFailure(error);
        } finally {
            activeProcess = null;
        }
    }

    private void pump(InputStream input, boolean stderr, Listener listener) {
        try (BufferedReader reader = new BufferedReader(
                new InputStreamReader(input, StandardCharsets.UTF_8))) {
            String line;
            while ((line = reader.readLine()) != null) {
                listener.onLine(stderr, line);
            }
        } catch (IOException error) {
            if (!cancelRequested) {
                listener.onFailure(error);
            }
        }
    }

    private static void awaitPump(Future<?> pump, InputStream input) throws Exception {
        try {
            pump.get(1500, TimeUnit.MILLISECONDS);
        } catch (TimeoutException timeout) {
            closeQuietly(input);
            pump.cancel(true);
        }
    }

    private static void closeQuietly(InputStream input) {
        try {
            input.close();
        } catch (IOException ignored) {
            // The process may have closed the descriptor concurrently.
        }
    }

    public void cancel() {
        Process process = activeProcess;
        if (process == null) {
            return;
        }
        cancelRequested = true;
        process.destroy();
        workers.submit(() -> {
            try {
                Thread.sleep(1500);
            } catch (InterruptedException ignored) {
                Thread.currentThread().interrupt();
            }
            if (process.isAlive()) {
                process.destroyForcibly();
            }
        });
    }

    @Override
    public void close() {
        cancel();
        workers.shutdownNow();
    }
}
