package com.downloader.database;

import java.util.Collections;
import java.util.List;

public class NoOpsDbHelper implements DbHelper {
  public NoOpsDbHelper() {}
  public DownloadModel find(int id) { DownloadModel model = new DownloadModel(); model.setId(id); return model; }
  public void insert(DownloadModel model) {}
  public void update(DownloadModel model) {}
  public void updateProgress(int id, long downloadedBytes, long lastModifiedAt) {}
  public void remove(int id) {}
  public List<DownloadModel> getUnwantedModels(int days) { return Collections.emptyList(); }
  public void clear() {}
}
