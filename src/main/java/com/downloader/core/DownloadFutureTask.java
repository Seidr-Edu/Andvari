package com.downloader.core;

import com.downloader.internal.DownloadRunnable;

public class DownloadFutureTask implements Comparable<DownloadFutureTask> {
  private final DownloadRunnable runnable;

  DownloadFutureTask(DownloadRunnable downloadRunnable) { this.runnable = downloadRunnable; }

  @Override
  public int compareTo(DownloadFutureTask other) {
    int priorityDiff = other.runnable.priority.ordinal() - runnable.priority.ordinal();
    if (priorityDiff != 0) return priorityDiff;
    return Integer.compare(runnable.sequence, other.runnable.sequence);
  }
}
