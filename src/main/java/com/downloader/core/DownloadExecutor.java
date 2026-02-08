package com.downloader.core;

import java.util.concurrent.*;

public class DownloadExecutor {
  private final ExecutorService service;

  DownloadExecutor(int maxNumThreads, ThreadFactory threadFactory) {
    service = Executors.newFixedThreadPool(maxNumThreads, threadFactory);
  }

  public Future<?> submit(Runnable task) { return service.submit(task); }
  public void shutdown() { service.shutdownNow(); }
}
