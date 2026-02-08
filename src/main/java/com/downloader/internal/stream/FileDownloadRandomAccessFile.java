package com.downloader.internal.stream;

import java.io.*;

public class FileDownloadRandomAccessFile implements FileDownloadOutputStream {
  private final BufferedOutputStream out;
  private final FileDescriptor fd;
  private final RandomAccessFile randomAccess;

  private FileDownloadRandomAccessFile(File file) {
    try {
      this.randomAccess = new RandomAccessFile(file, "rw");
      this.fd = randomAccess.getFD();
      this.out = new BufferedOutputStream(new FileOutputStream(fd));
    } catch (IOException e) {
      throw new UncheckedIOException(e);
    }
  }

  public void write(byte[] b, int off, int len) {
    try { out.write(b, off, len); } catch (IOException e) { throw new UncheckedIOException(e); }
  }
  public void flushAndSync() {
    try { out.flush(); fd.sync(); } catch (IOException e) { throw new UncheckedIOException(e); }
  }
  public void close() {
    try { out.close(); randomAccess.close(); } catch (IOException e) { throw new UncheckedIOException(e); }
  }
  public void seek(long offset) {
    try { randomAccess.seek(offset); } catch (IOException e) { throw new UncheckedIOException(e); }
  }
  public void setLength(long totalBytes) {
    try { randomAccess.setLength(totalBytes); } catch (IOException e) { throw new UncheckedIOException(e); }
  }
  public static FileDownloadOutputStream create(File file) { return new FileDownloadRandomAccessFile(file); }
}
