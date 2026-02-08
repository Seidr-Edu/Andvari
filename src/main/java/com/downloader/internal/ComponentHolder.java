package com.downloader.internal;

import com.downloader.*;
import com.downloader.database.*;
import com.downloader.httpclient.DefaultHttpClient;
import com.downloader.httpclient.HttpClient;

public class ComponentHolder {
  private static final ComponentHolder INSTANCE = new ComponentHolder();
  private int readTimeout = Constants.DEFAULT_READ_TIMEOUT_IN_MILLS;
  private int connectTimeout = Constants.DEFAULT_CONNECT_TIMEOUT_IN_MILLS;
  private String userAgent = Constants.DEFAULT_USER_AGENT;
  private HttpClient httpClient = new DefaultHttpClient();
  private DbHelper dbHelper = new NoOpsDbHelper();

  public static ComponentHolder getInstance() { return INSTANCE; }

  public void init(Context context, PRDownloaderConfig config) {
    this.readTimeout = config.getReadTimeout();
    this.connectTimeout = config.getConnectTimeout();
    this.userAgent = config.getUserAgent();
    this.httpClient = config.getHttpClient() == null ? new DefaultHttpClient() : config.getHttpClient();
    this.dbHelper = config.isDatabaseEnabled() ? new AppDbHelper(context) : new NoOpsDbHelper();
  }
  public int getReadTimeout() { return readTimeout; }
  public int getConnectTimeout() { return connectTimeout; }
  public String getUserAgent() { return userAgent; }
  public DbHelper getDbHelper() { return dbHelper; }
  public HttpClient getHttpClient() { return httpClient; }
}
