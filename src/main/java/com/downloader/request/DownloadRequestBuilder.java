package com.downloader.request;

import com.downloader.Constants;
import com.downloader.Priority;
import java.util.*;

public class DownloadRequestBuilder implements RequestBuilder {
  String url;
  String dirPath;
  String fileName;
  Priority priority = Priority.MEDIUM;
  Object tag;
  int readTimeout = Constants.DEFAULT_READ_TIMEOUT_IN_MILLS;
  int connectTimeout = Constants.DEFAULT_CONNECT_TIMEOUT_IN_MILLS;
  String userAgent = Constants.DEFAULT_USER_AGENT;
  HashMap<String, List<String>> headerMap = new HashMap<>();

  public DownloadRequestBuilder(String url, String dirPath, String fileName) {
    this.url = url;
    this.dirPath = dirPath;
    this.fileName = fileName;
  }

  public DownloadRequestBuilder setHeader(String name, String value) {
    headerMap.computeIfAbsent(name, k -> new ArrayList<>()).add(value);
    return this;
  }
  public DownloadRequestBuilder setPriority(Priority priority) { this.priority = priority; return this; }
  public DownloadRequestBuilder setTag(Object tag) { this.tag = tag; return this; }
  public DownloadRequestBuilder setReadTimeout(int readTimeout) { this.readTimeout = readTimeout; return this; }
  public DownloadRequestBuilder setConnectTimeout(int connectTimeout) { this.connectTimeout = connectTimeout; return this; }
  public DownloadRequestBuilder setUserAgent(String userAgent) { this.userAgent = userAgent; return this; }
  public DownloadRequest build() { return new DownloadRequest(this); }
}
