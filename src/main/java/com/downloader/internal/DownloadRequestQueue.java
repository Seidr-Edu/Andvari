package com.downloader.internal;

import com.downloader.Status;
import com.downloader.core.Core;
import com.downloader.request.DownloadRequest;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.atomic.AtomicInteger;

public class DownloadRequestQueue {
  private static DownloadRequestQueue instance;
  private final Map<Integer, DownloadRequest> currentRequestMap = new ConcurrentHashMap<>();
  private final AtomicInteger sequenceGenerator = new AtomicInteger();

  public static void initialize() { instance = new DownloadRequestQueue(); }
  public static DownloadRequestQueue getInstance() {
    if (instance == null) initialize();
    return instance;
  }

  private int getSequenceNumber() { return sequenceGenerator.incrementAndGet(); }

  public void pause(int downloadId) {
    DownloadRequest r = currentRequestMap.get(downloadId);
    if (r != null) r.setStatus(Status.PAUSED);
  }

  public void resume(int downloadId) {
    DownloadRequest r = currentRequestMap.get(downloadId);
    if (r != null && r.getStatus() == Status.PAUSED) addRequest(r);
  }

  private void cancelAndRemoveFromMap(DownloadRequest request) { request.cancel(); currentRequestMap.remove(request.getDownloadId()); }
  public void cancel(int downloadId) { DownloadRequest r = currentRequestMap.get(downloadId); if (r != null) cancelAndRemoveFromMap(r); }
  public void cancel(Object tag) { currentRequestMap.values().stream().filter(r -> tag.equals(r.getTag())).toList().forEach(this::cancelAndRemoveFromMap); }
  public void cancelAll() { currentRequestMap.values().forEach(DownloadRequest::cancel); currentRequestMap.clear(); }
  public Status getStatus(int downloadId) {
    DownloadRequest r = currentRequestMap.get(downloadId);
    return r == null ? Status.UNKNOWN : r.getStatus();
  }

  public void addRequest(DownloadRequest request) {
    int id = Math.abs((request.getUrl() + request.getDirPath() + request.getFileName()).hashCode());
    request.setDownloadId(id);
    request.setSequenceNumber(getSequenceNumber());
    request.setStatus(Status.QUEUED);
    currentRequestMap.put(id, request);
    request.deliverStartEvent();
    request.setFuture(Core.getInstance().getExecutorSupplier().forDownloadTasks().submit(new DownloadRunnable(request)));
    request.setStatus(Status.RUNNING);
  }

  public void finish(DownloadRequest request) { currentRequestMap.remove(request.getDownloadId()); }

  private DownloadRequestQueue() {}
}
