package com.downloader.httpclient;

import com.downloader.Constants;
import com.downloader.request.DownloadRequest;
import java.io.*;
import java.net.*;
import java.util.List;
import java.util.Map;

public class DefaultHttpClient implements HttpClient {
  private URLConnection connection;

  public DefaultHttpClient() {}

  public HttpClient clone() { return new DefaultHttpClient(); }

  public void connect(DownloadRequest request) {
    try {
      connection = URI.create(request.getUrl()).toURL().openConnection();
      if (connection instanceof HttpURLConnection http) {
        http.setConnectTimeout(request.getConnectTimeout());
        http.setReadTimeout(request.getReadTimeout());
      }
      addHeaders(request);
      connection.connect();
    } catch (IOException e) {
      throw new UncheckedIOException(e);
    }
  }

  public int getResponseCode() {
    if (connection instanceof HttpURLConnection http) {
      try { return http.getResponseCode(); } catch (IOException e) { return 500; }
    }
    return 200;
  }

  public InputStream getInputStream() {
    try { return connection.getInputStream(); } catch (IOException e) { throw new UncheckedIOException(e); }
  }
  public long getContentLength() { return connection.getContentLengthLong(); }
  public String getResponseHeader(String name) { return connection.getHeaderField(name); }
  public void close() {
    if (connection instanceof HttpURLConnection http) http.disconnect();
  }
  public Map<String, List<String>> getHeaderFields() { return connection.getHeaderFields(); }
  public InputStream getErrorStream() {
    if (connection instanceof HttpURLConnection http) return http.getErrorStream();
    return InputStream.nullInputStream();
  }

  private void addHeaders(DownloadRequest request) {
    for (Map.Entry<String, List<String>> e : request.getHeaders().entrySet()) {
      for (String v : e.getValue()) connection.addRequestProperty(e.getKey(), v);
    }
    connection.setRequestProperty(Constants.USER_AGENT, request.getUserAgent());
  }
}
