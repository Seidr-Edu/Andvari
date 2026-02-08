package com.downloader.database;

import com.downloader.Context;
import com.downloader.platform.SQLiteDatabase;

public class DatabaseOpenHelper {
  private static final String DATABASE_NAME = "prdownloader.db";
  private static final int DATABASE_VERSION = 1;
  DatabaseOpenHelper(Context context) {}
  public void onCreate(SQLiteDatabase db) {}
  public void onUpgrade(SQLiteDatabase db, int i, int i1) {}
}
