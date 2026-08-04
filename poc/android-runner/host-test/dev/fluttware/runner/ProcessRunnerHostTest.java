package dev.fluttware.runner;

import java.io.File;
import java.util.ArrayList;
import java.util.Collections;
import java.util.List;
import java.util.Map;
import java.util.concurrent.CountDownLatch;
import java.util.concurrent.TimeUnit;

/** JUnit-free control test for pipe draining and cancellation on the host. */
public final class ProcessRunnerHostTest {
    public static void main(String[] args) throws Exception {
        testStdoutStderrAndExit();
        testCancellation();
        System.out.println("ProcessRunnerHostTest: PASS");
    }

    private static void testStdoutStderrAndExit() throws Exception {
        List<String> lines = Collections.synchronizedList(new ArrayList<>());
        CountDownLatch exited = new CountDownLatch(1);
        try (ProcessRunner runner = new ProcessRunner()) {
            runner.start(
                    List.of("/bin/sh", "-c", "printf 'out\\n'; printf 'err\\n' >&2"),
                    new File("."),
                    Map.of("FLUTTWARE_TEST", "1"),
                    listener(lines, exited));
            require(exited.await(5, TimeUnit.SECONDS), "process did not exit");
        }
        require(lines.contains("O:out"), "stdout was not captured: " + lines);
        require(lines.contains("E:err"), "stderr was not captured: " + lines);
        require(lines.contains("X:0"), "exit code was not captured: " + lines);
    }

    private static void testCancellation() throws Exception {
        List<String> lines = Collections.synchronizedList(new ArrayList<>());
        CountDownLatch exited = new CountDownLatch(1);
        try (ProcessRunner runner = new ProcessRunner()) {
            runner.start(
                    List.of("/bin/sh", "-c", "sleep 10"),
                    new File("."),
                    Map.of(),
                    listener(lines, exited));
            Thread.sleep(200);
            runner.cancel();
            require(exited.await(5, TimeUnit.SECONDS), "cancelled process did not exit");
        }
        require(lines.stream().anyMatch(line -> line.startsWith("X:")),
                "cancelled exit code was not captured: " + lines);
    }

    private static ProcessRunner.Listener listener(
            List<String> lines,
            CountDownLatch exited) {
        return new ProcessRunner.Listener() {
            @Override public void onLine(boolean stderr, String line) {
                lines.add((stderr ? "E:" : "O:") + line);
            }
            @Override public void onExit(int exitCode, long elapsedMillis) {
                lines.add("X:" + exitCode);
                exited.countDown();
            }
            @Override public void onFailure(Throwable error) {
                lines.add("F:" + error);
                exited.countDown();
            }
        };
    }

    private static void require(boolean condition, String message) {
        if (!condition) {
            throw new AssertionError(message);
        }
    }
}
