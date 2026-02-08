package com.downloader;

import com.downloader.request.DownloadRequest;
import com.sun.net.httpserver.HttpServer;
import java.net.InetSocketAddress;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.concurrent.CountDownLatch;
import java.util.concurrent.TimeUnit;

public class BehaviorTests {
  public static void main(String[] args) throws Exception {
    HttpServer server = HttpServer.create(new InetSocketAddress(0), 0);
    server.createContext("/file", ex -> {
      byte[] body = "hello-downloader".getBytes();
      ex.sendResponseHeaders(200, body.length);
      ex.getResponseBody().write(body);
      ex.close();
    });
    server.start();
    String baseUrl = "http://localhost:" + server.getAddress().getPort();

    PRDownloader.initialize(new Context());
    Path dir = Files.createTempDirectory("prdl");

    Response response = PRDownloader.download(baseUrl + "/file", dir.toString(), "a.txt").build().executeSync();
    assertTrue(response.isSuccessful(), "sync response success");
    assertTrue("hello-downloader".equals(Files.readString(dir.resolve("a.txt"))), "content matches");

    CountDownLatch done = new CountDownLatch(1);
    int id = PRDownloader.download(baseUrl + "/file", dir.toString(), "b.txt").build().start(new OnDownloadListener() {
      @Override public void onDownloadComplete() { done.countDown(); }
      @Override public void onError(Error error) { throw new RuntimeException("unexpected"); }
    });
    assertTrue(id > 0, "id created");
    assertTrue(done.await(3, TimeUnit.SECONDS), "async done");

    CountDownLatch progress = new CountDownLatch(1);
    DownloadRequest request = PRDownloader.download(baseUrl + "/file", dir.toString(), "c.txt").build();
    request.setOnProgressListener(p -> { if (p.currentBytes > 0) progress.countDown(); });
    assertTrue(request.executeSync().isSuccessful(), "progress sync success");
    assertTrue(progress.await(1, TimeUnit.SECONDS), "progress invoked");

    server.stop(0);
    PRDownloader.shutDown();
    System.out.println("Behavior tests passed");
  }

  private static void assertTrue(boolean condition, String message) {
    if (!condition) throw new IllegalStateException("Assertion failed: " + message);
  }
}
