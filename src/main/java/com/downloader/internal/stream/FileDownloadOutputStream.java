package com.downloader.internal.stream;

public interface FileDownloadOutputStream {
  void write(byte[] b, int off, int len);
  void flushAndSync();
  void close();
  void seek(long offset);
  void setLength(long newLength);
}
