package com.downloader.core;

import java.util.concurrent.ThreadFactory;

public class PriorityThreadFactory implements ThreadFactory {
  private final int mThreadPriority;

  PriorityThreadFactory(int threadPriority) { this.mThreadPriority = threadPriority; }

  @Override
  public Thread newThread(Runnable runnable) {
    Thread thread = new Thread(runnable);
    thread.setPriority(Math.max(Thread.MIN_PRIORITY, Math.min(Thread.MAX_PRIORITY, mThreadPriority)));
    return thread;
  }
}
