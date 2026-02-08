package com.downloader.internal;

import com.downloader.Constants;
import com.downloader.Progress;
import com.downloader.Response;
import com.downloader.Status;
import com.downloader.Error;
import com.downloader.database.DownloadModel;
import com.downloader.handler.ProgressHandler;
import com.downloader.httpclient.HttpClient;
import com.downloader.internal.stream.FileDownloadOutputStream;
import com.downloader.internal.stream.FileDownloadRandomAccessFile;
import com.downloader.platform.Message;
import com.downloader.request.DownloadRequest;
import com.downloader.utils.Utils;
import java.io.*;
import java.nio.charset.StandardCharsets;

public class DownloadTask {
  private static final int BUFFER_SIZE = 8192;
  private static final long TIME_GAP_FOR_SYNC = 100;
  private static final long MIN_BYTES_FOR_SYNC = 16 * 1024;
  private final DownloadRequest request;
  private ProgressHandler progressHandler;
  private long lastSyncTime;
  private long lastSyncBytes;
  private InputStream inputStream;
  private FileDownloadOutputStream outputStream;
  private HttpClient httpClient;
  private long totalBytes;
  private int responseCode;
  private String eTag;
  private boolean isResumeSupported;
  private String tempPath;

  static DownloadTask create(DownloadRequest request) { return new DownloadTask(request); }

  Response run() {
    Response response = new Response();
    try {
      this.progressHandler = request.getOnProgressListener() == null ? null : new ProgressHandler(request.getOnProgressListener());
      this.httpClient = Utils.getRedirectedConnectionIfAny(ComponentHolder.getInstance().getHttpClient().clone(), request);
      this.httpClient.connect(request);
      this.responseCode = httpClient.getResponseCode();
      if (responseCode >= 400) {
        Error error = new Error();
        error.setServerError(true);
        error.setResponseCode(responseCode);
        error.setServerErrorMessage(convertStreamToString(httpClient.getErrorStream()));
        response.setError(error);
        return response;
      }
      this.totalBytes = httpClient.getContentLength();
      request.setTotalBytes(totalBytes);
      this.tempPath = Utils.getTempPath(request.getDirPath(), request.getFileName());
      File targetDir = new File(request.getDirPath());
      targetDir.mkdirs();
      this.outputStream = FileDownloadRandomAccessFile.create(new File(tempPath));
      this.inputStream = httpClient.getInputStream();
      byte[] b = new byte[BUFFER_SIZE];
      int n;
      while ((n = inputStream.read(b)) != -1) {
        if (request.getStatus() == Status.CANCELLED) { response.setCancelled(true); return response; }
        if (request.getStatus() == Status.PAUSED) { response.setPaused(true); return response; }
        outputStream.write(b, 0, n);
        request.setDownloadedBytes(request.getDownloadedBytes() + n);
        sendProgress();
        syncIfRequired(outputStream);
      }
      sync(outputStream);
      Utils.renameFileName(tempPath, Utils.getPath(request.getDirPath(), request.getFileName()));
      response.setSuccessful(isSuccessful());
      return response;
    } catch (Exception e) {
      Error error = new Error();
      error.setConnectionError(true);
      error.setConnectionException(e);
      response.setError(error);
      return response;
    } finally {
      closeAllSafely(outputStream);
      if (httpClient != null) httpClient.close();
    }
  }

  private void deleteTempFile() { new File(tempPath).delete(); }
  private boolean isSuccessful() { return request.getDownloadedBytes() >= totalBytes || totalBytes <= 0; }
  private void setResumeSupportedOrNot() { isResumeSupported = false; }
  private boolean checkIfFreshStartRequiredAndStart(DownloadModel model) { return false; }
  private boolean isETagChanged(DownloadModel model) { return false; }
  private DownloadModel getDownloadModelIfAlreadyPresentInDatabase() { DownloadModel model = new DownloadModel(); model.setId(request.getDownloadId()); return model; }
  private void createAndInsertNewModel() {}
  private void removeNoMoreNeededModelFromDatabase() {}
  private void sendProgress() {
    if (progressHandler != null) progressHandler.handleMessage(new Message(Constants.UPDATE, new Progress(request.getDownloadedBytes(), totalBytes)));
  }
  private void syncIfRequired(FileDownloadOutputStream outputStream) {
    long now = System.currentTimeMillis();
    if (now - lastSyncTime > TIME_GAP_FOR_SYNC || request.getDownloadedBytes() - lastSyncBytes > MIN_BYTES_FOR_SYNC) sync(outputStream);
  }
  private void sync(FileDownloadOutputStream outputStream) {
    outputStream.flushAndSync();
    lastSyncTime = System.currentTimeMillis();
    lastSyncBytes = request.getDownloadedBytes();
  }
  private void closeAllSafely(FileDownloadOutputStream outputStream) {
    try { if (inputStream != null) inputStream.close(); } catch (IOException ignored) {}
    if (outputStream != null) outputStream.close();
  }
  private String convertStreamToString(InputStream stream) {
    try { return new String(stream.readAllBytes(), StandardCharsets.UTF_8); } catch (IOException e) { return e.getMessage(); }
  }
  private DownloadTask(DownloadRequest request) { this.request = request; }
}
