package com.downloader;

public class Application {
  public static void main(String[] args) {
    PRDownloader.initialize(new Context());
    System.out.println("PRDownloader bootRun started");
  }
}
