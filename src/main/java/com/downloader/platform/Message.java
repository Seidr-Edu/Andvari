package com.downloader.platform;

public class Message {
  public final int what;
  public final Object obj;

  public Message(int what, Object obj) {
    this.what = what;
    this.obj = obj;
  }
}
