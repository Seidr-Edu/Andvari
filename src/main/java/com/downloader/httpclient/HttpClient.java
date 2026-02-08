package com.downloader.httpclient;

import com.downloader.request.DownloadRequest;
import java.io.InputStream;
import java.util.List;
import java.util.Map;

public interface HttpClient {
  HttpClient clone();
  void connect(DownloadRequest request);
  int getResponseCode();
  InputStream getInputStream();
  long getContentLength();
  String getResponseHeader(String name);
  void close();
  Map<String, List<String>> getHeaderFields();
  InputStream getErrorStream();
}
