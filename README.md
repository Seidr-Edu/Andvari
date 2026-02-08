# PRDownloader (Java Reconstruction)

## Build
```bash
./gradlew clean build
```

## Usage
```java
PRDownloader.initialize(new Context());
int id = PRDownloader.download("https://example.com/file.txt", "build/tmp", "file.txt")
    .setPriority(Priority.HIGH)
    .build()
    .start(new OnDownloadListener() {
      @Override public void onDownloadComplete() { System.out.println("done"); }
      @Override public void onError(Error error) { System.out.println(error.getServerErrorMessage()); }
    });
Status status = PRDownloader.getStatus(id);
```

## Sync usage
```java
PRDownloader.initialize(new Context());
Response response = PRDownloader.download("https://example.com/file.txt", "build/tmp", "sync.txt")
    .build()
    .executeSync();
System.out.println(response.isSuccessful());
```
