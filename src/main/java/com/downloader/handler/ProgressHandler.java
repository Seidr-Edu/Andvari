package com.downloader.handler;

import com.downloader.OnProgressListener;
import com.downloader.Progress;
import com.downloader.platform.Message;

public class ProgressHandler {
  private final OnProgressListener listener;

  public ProgressHandler(OnProgressListener listener) { this.listener = listener; }

  public void handleMessage(Message msg) {
    if (msg.obj instanceof Progress progress) listener.onProgress(progress);
  }
}
