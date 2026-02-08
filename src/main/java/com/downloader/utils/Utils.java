package com.downloader.utils;

import com.downloader.database.DbHelper;
import com.downloader.database.DownloadModel;
import com.downloader.httpclient.HttpClient;
import com.downloader.internal.ComponentHolder;
import com.downloader.request.DownloadRequest;
import java.io.File;
import java.util.List;

public final class Utils {
  private static final int MAX_REDIRECTION = 5;

  public static String getPath(String dirPath, String fileName) { return dirPath + File.separator + fileName; }
  public static String getTempPath(String dirPath, String fileName) { return getPath(dirPath, fileName) + ".temp"; }
  public static void renameFileName(String oldPath, String newPath) { new File(oldPath).renameTo(new File(newPath)); }
  public static void deleteTempFileAndDatabaseEntryInBackground(String path, int downloadId) {
    new File(path).delete();
    ComponentHolder.getInstance().getDbHelper().remove(downloadId);
  }
  public static void deleteUnwantedModelsAndTempFiles(int days) {
    DbHelper db = ComponentHolder.getInstance().getDbHelper();
    List<DownloadModel> models = db.getUnwantedModels(days);
    for (DownloadModel m : models) {
      new File(getTempPath(m.getDirPath(), m.getFileName())).delete();
      db.remove(m.getId());
    }
  }
  public static int getUniqueId(String url, String dirPath, String fileName) {
    return Math.abs((url + "|" + dirPath + "|" + fileName).hashCode());
  }
  public static HttpClient getRedirectedConnectionIfAny(HttpClient httpClient, DownloadRequest request) { return httpClient; }
  private static boolean isRedirection(int code) { return code >= 300 && code < 400; }
  private Utils() {}
}
