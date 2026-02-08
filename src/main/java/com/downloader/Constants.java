package com.downloader;

public final class Constants {
  public static final int UPDATE = 1;
  public static final String RANGE = "Range";
  public static final String ETAG = "ETag";
  public static final String USER_AGENT = "User-Agent";
  public static final String DEFAULT_USER_AGENT = "PRDownloader-Java";
  public static final int DEFAULT_READ_TIMEOUT_IN_MILLS = 30_000;
  public static final int DEFAULT_CONNECT_TIMEOUT_IN_MILLS = 30_000;
  public static final int HTTP_RANGE_NOT_SATISFIABLE = 416;
  public static final int HTTP_TEMPORARY_REDIRECT = 307;
  public static final int HTTP_PERMANENT_REDIRECT = 308;

  private Constants() {}
}
