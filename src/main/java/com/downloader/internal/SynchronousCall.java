package com.downloader.internal;

import com.downloader.Response;
import com.downloader.request.DownloadRequest;

public class SynchronousCall {
  public final DownloadRequest request;

  public SynchronousCall(DownloadRequest request) { this.request = request; }

  public Response execute() { return DownloadTask.create(request).run(); }
}
