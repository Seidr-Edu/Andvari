package com.downloader.request;

import com.downloader.Constants;
import com.downloader.OnCancelListener;
import com.downloader.OnDownloadListener;
import com.downloader.OnPauseListener;
import com.downloader.OnProgressListener;
import com.downloader.OnStartOrResumeListener;
import com.downloader.Priority;
import com.downloader.Response;
import com.downloader.Status;
import com.downloader.Error;
import com.downloader.internal.DownloadRequestQueue;
import com.downloader.internal.SynchronousCall;
import java.util.HashMap;
import java.util.List;
import java.util.concurrent.Future;

public class DownloadRequest {
  private Priority priority;
  private Object tag;
  private String url;
  private String dirPath;
  private String fileName;
  private int sequenceNumber;
  private Future future;
  private long downloadedBytes;
  private long totalBytes;
  private int readTimeout;
  private int connectTimeout;
  private String userAgent;
  private OnProgressListener onProgressListener;
  private OnDownloadListener onDownloadListener;
  private OnStartOrResumeListener onStartOrResumeListener;
  private OnPauseListener onPauseListener;
  private OnCancelListener onCancelListener;
  private int downloadId;
  private HashMap<String, List<String>> headerMap;
  private Status status = Status.UNKNOWN;

  DownloadRequest(DownloadRequestBuilder builder) {
    this.priority = builder.priority;
    this.tag = builder.tag;
    this.url = builder.url;
    this.dirPath = builder.dirPath;
    this.fileName = builder.fileName;
    this.readTimeout = builder.readTimeout;
    this.connectTimeout = builder.connectTimeout;
    this.userAgent = builder.userAgent;
    this.headerMap = builder.headerMap;
  }

  public Priority getPriority() { return priority; }
  public void setPriority(Priority priority) { this.priority = priority; }
  public Object getTag() { return tag; }
  public void setTag(Object tag) { this.tag = tag; }
  public String getUrl() { return url; }
  public void setUrl(String url) { this.url = url; }
  public String getDirPath() { return dirPath; }
  public void setDirPath(String dirPath) { this.dirPath = dirPath; }
  public String getFileName() { return fileName; }
  public void setFileName(String fileName) { this.fileName = fileName; }
  public int getSequenceNumber() { return sequenceNumber; }
  public void setSequenceNumber(int sequenceNumber) { this.sequenceNumber = sequenceNumber; }
  public HashMap<String, List<String>> getHeaders() { return headerMap; }
  public Future getFuture() { return future; }
  public void setFuture(Future future) { this.future = future; }
  public long getDownloadedBytes() { return downloadedBytes; }
  public void setDownloadedBytes(long downloadedBytes) { this.downloadedBytes = downloadedBytes; }
  public long getTotalBytes() { return totalBytes; }
  public void setTotalBytes(long totalBytes) { this.totalBytes = totalBytes; }
  public int getReadTimeout() { return readTimeout; }
  public void setReadTimeout(int readTimeout) { this.readTimeout = readTimeout; }
  public int getConnectTimeout() { return connectTimeout; }
  public void setConnectTimeout(int connectTimeout) { this.connectTimeout = connectTimeout; }
  public String getUserAgent() { return userAgent; }
  public void setUserAgent(String userAgent) { this.userAgent = userAgent; }
  public int getDownloadId() { return downloadId; }
  public void setDownloadId(int downloadId) { this.downloadId = downloadId; }
  public Status getStatus() { return status; }
  public void setStatus(Status status) { this.status = status; }
  public OnProgressListener getOnProgressListener() { return onProgressListener; }
  public DownloadRequest setOnStartOrResumeListener(OnStartOrResumeListener l) { this.onStartOrResumeListener = l; return this; }
  public DownloadRequest setOnProgressListener(OnProgressListener l) { this.onProgressListener = l; return this; }
  public DownloadRequest setOnPauseListener(OnPauseListener l) { this.onPauseListener = l; return this; }
  public DownloadRequest setOnCancelListener(OnCancelListener l) { this.onCancelListener = l; return this; }

  public int start(OnDownloadListener listener) {
    this.onDownloadListener = listener;
    DownloadRequestQueue.getInstance().addRequest(this);
    return downloadId;
  }

  public Response executeSync() { return new SynchronousCall(this).execute(); }

  public void deliverError(Error error) { if (onDownloadListener != null) onDownloadListener.onError(error); finish(); }
  public void deliverSuccess() { if (onDownloadListener != null) onDownloadListener.onDownloadComplete(); finish(); }
  public void deliverStartEvent() { if (onStartOrResumeListener != null) onStartOrResumeListener.onStartOrResume(); }
  public void deliverPauseEvent() { if (onPauseListener != null) onPauseListener.onPause(); }
  private void deliverCancelEvent() { if (onCancelListener != null) onCancelListener.onCancel(); }

  public void cancel() {
    status = Status.CANCELLED;
    if (future != null) future.cancel(true);
    deliverCancelEvent();
  }

  private void finish() { DownloadRequestQueue.getInstance().finish(this); destroy(); }
  private void destroy() {}
  private int getReadTimeoutFromConfig() { return readTimeout > 0 ? readTimeout : Constants.DEFAULT_READ_TIMEOUT_IN_MILLS; }
  private int getConnectTimeoutFromConfig() { return connectTimeout > 0 ? connectTimeout : Constants.DEFAULT_CONNECT_TIMEOUT_IN_MILLS; }
}
