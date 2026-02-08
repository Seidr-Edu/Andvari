package com.downloader.database;

import com.downloader.Context;
import com.downloader.platform.SQLiteDatabase;
import java.time.Instant;
import java.util.*;
import java.util.concurrent.ConcurrentHashMap;

public class AppDbHelper implements DbHelper {
  public static final String TABLE_NAME = "downloads";
  private final SQLiteDatabase db;
  private final Map<Integer, DownloadModel> store = new ConcurrentHashMap<>();

  public AppDbHelper(Context context) { this.db = new SQLiteDatabase(); }
  public DownloadModel find(int id) { return store.get(id); }
  public void insert(DownloadModel model) { store.put(model.getId(), model); }
  public void update(DownloadModel model) { store.put(model.getId(), model); }
  public void updateProgress(int id, long downloadedBytes, long lastModifiedAt) {
    DownloadModel m = store.get(id);
    if (m != null) { m.setDownloadedBytes(downloadedBytes); m.setLastModifiedAt(lastModifiedAt); }
  }
  public void remove(int id) { store.remove(id); }
  public List<DownloadModel> getUnwantedModels(int days) {
    long cutoff = Instant.now().minusSeconds(days * 86400L).toEpochMilli();
    List<DownloadModel> out = new ArrayList<>();
    for (DownloadModel m : store.values()) if (m.getLastModifiedAt() < cutoff) out.add(m);
    return out;
  }
  public void clear() { store.clear(); }
}
