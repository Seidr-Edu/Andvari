package com.downloader.core;

import com.downloader.platform.Handler;
import java.util.concurrent.Executor;

public class MainThreadExecutor implements Executor {
  private final Handler handler;

  public MainThreadExecutor() { this.handler = new Handler(Runnable::run); }

  @Override
  public void execute(Runnable runnable) { handler.post(runnable); }
}
