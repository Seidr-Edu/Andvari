package com.downloader.core;

import java.util.concurrent.Executor;
import java.util.concurrent.Executors;

public class DefaultExecutorSupplier implements ExecutorSupplier {
  private static final int DEFAULT_MAX_NUM_THREADS = 4;
  private final DownloadExecutor networkExecutor;
  private final Executor backgroundExecutor;
  private final Executor mainThreadExecutor;

  DefaultExecutorSupplier() {
    this.networkExecutor = new DownloadExecutor(DEFAULT_MAX_NUM_THREADS, new PriorityThreadFactory(5));
    this.backgroundExecutor = Executors.newSingleThreadExecutor();
    this.mainThreadExecutor = new MainThreadExecutor();
  }

  public DownloadExecutor forDownloadTasks() { return networkExecutor; }
  public Executor forBackgroundTasks() { return backgroundExecutor; }
  public Executor forMainThreadTasks() { return mainThreadExecutor; }
}
