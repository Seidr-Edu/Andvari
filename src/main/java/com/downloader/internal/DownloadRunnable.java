package com.downloader.internal;

import com.downloader.Priority;
import com.downloader.Response;
import com.downloader.request.DownloadRequest;

public class DownloadRunnable implements Runnable {
  public final Priority priority;
  public final int sequence;
  public final DownloadRequest request;

  DownloadRunnable(DownloadRequest request) {
    this.request = request;
    this.priority = request.getPriority();
    this.sequence = request.getSequenceNumber();
  }

  @Override
  public void run() {
    Response response = DownloadTask.create(request).run();
    if (response.isSuccessful()) request.deliverSuccess();
    else if (response.isPaused()) request.deliverPauseEvent();
    else if (!response.isCancelled()) request.deliverError(response.getError());
  }
}
