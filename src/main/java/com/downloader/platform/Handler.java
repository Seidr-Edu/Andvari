package com.downloader.platform;

import java.util.concurrent.Executor;

public class Handler {
  private final Executor executor;

  public Handler(Executor executor) { this.executor = executor; }

  public void post(Runnable runnable) { executor.execute(runnable); }
}
