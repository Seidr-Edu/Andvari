package com.downloader;

public class Progress {
  public long currentBytes;
  public long totalBytes;

  public Progress(long currentBytes, long totalBytes) {
    this.currentBytes = currentBytes;
    this.totalBytes = totalBytes;
  }

  @Override
  public String toString() {
    return "Progress{" + currentBytes + "/" + totalBytes + "}";
  }
}
