package com.smartwallet.smart_wallet;

import java.io.UnsupportedEncodingException;
import java.net.URLEncoder;
import java.time.Instant;
import java.time.ZoneId;
import java.time.format.DateTimeFormatter;
import java.util.List;
import java.util.Locale;
import java.util.Map;

/**
 * Pure request/response construction for the Google Drive v3 REST
 * calls behind DriveBackupService (Phase 5) — everything except the
 * actual HTTP and auth, so it is unit-testable on the JVM. Mirrors
 * Flutter's GoogleDriveBackupService: the backup lives in the
 * appDataFolder under the fixed name smart_wallet_backup.smartwallet.
 */
public final class DriveCodec {

    public static final String BACKUP_FILE_NAME = "smart_wallet_backup.smartwallet";
    public static final String BACKUP_DESCRIPTION =
            "Smart Wallet Encrypted Database Cloud Backup";
    public static final String APP_DATA_FOLDER = "appDataFolder";

    private static final String API = "https://www.googleapis.com/drive/v3";
    private static final String UPLOAD_API = "https://www.googleapis.com/upload/drive/v3";

    private DriveCodec() {}

    /** One backup file as Drive reports it. */
    public static final class BackupInfo {
        public final String fileId;
        public final String name;
        /** RFC 3339 timestamp exactly as Drive returned it. */
        public final String modifiedTime;
        public final long sizeBytes;

        public BackupInfo(String fileId, String name, String modifiedTime, long sizeBytes) {
            this.fileId = fileId;
            this.name = name;
            this.modifiedTime = modifiedTime;
            this.sizeBytes = sizeBytes;
        }

        /** "4 Nov 2026, 4:25 PM" in the device zone, or the raw value. */
        public String prettyModified() {
            if (modifiedTime == null) return "";
            try {
                Instant t = Instant.parse(modifiedTime);
                return DateTimeFormatter.ofPattern("d MMM yyyy, h:mm a", Locale.ENGLISH)
                        .withZone(ZoneId.systemDefault()).format(t);
            } catch (Exception e) {
                return modifiedTime;
            }
        }

        /** "12.3 KB" style size, like a file listing. */
        public String prettySize() {
            if (sizeBytes < 1024) return sizeBytes + " B";
            double kb = sizeBytes / 1024.0;
            if (kb < 1024) return String.format(Locale.US, "%.1f KB", kb);
            return String.format(Locale.US, "%.1f MB", kb / 1024.0);
        }
    }

    public static String urlEncode(String value) {
        try {
            return URLEncoder.encode(value, "UTF-8");
        } catch (UnsupportedEncodingException e) {
            throw new IllegalStateException(e);
        }
    }

    /**
     * GET the (single) backup file in appDataFolder:
     * files?spaces=appDataFolder&q=name='...' and trashed=false
     * &fields=files(id,name,modifiedTime,size)
     */
    public static String listUrl() {
        String q = "name = '" + BACKUP_FILE_NAME + "' and trashed = false";
        return API + "/files?spaces=" + APP_DATA_FOLDER
                + "&q=" + urlEncode(q)
                + "&fields=" + urlEncode("files(id,name,modifiedTime,size)");
    }

    /** POST create-file metadata endpoint (step 1 of a fresh upload). */
    public static String createFileUrl() {
        return API + "/files";
    }

    /** Metadata JSON body for creating the backup file. */
    public static String createMetadataJson() {
        return "{\"name\":\"" + BACKUP_FILE_NAME + "\",\"parents\":[\""
                + APP_DATA_FOLDER + "\"],\"description\":\""
                + BACKUP_DESCRIPTION + "\"}";
    }

    /**
     * PATCH media-upload endpoint used both to create content on a
     * fresh file and to overwrite an existing one (uploadType=media).
     */
    public static String uploadMediaUrl(String fileId) {
        return UPLOAD_API + "/files/" + urlEncode(fileId) + "?uploadType=media";
    }

    /** GET file content. */
    public static String downloadUrl(String fileId) {
        return API + "/files/" + urlEncode(fileId) + "?alt=media";
    }

    /** First file of a list response, or null when Drive has none. */
    public static BackupInfo parseFirstFile(String json) throws MiniJson.JsonException {
        Map<String, Object> root = MiniJson.parseObject(json);
        Object filesObj = root.get("files");
        if (!(filesObj instanceof List) || ((List<?>) filesObj).isEmpty()) return null;
        Object first = ((List<?>) filesObj).get(0);
        if (!(first instanceof Map)) return null;
        Map<?, ?> f = (Map<?, ?>) first;
        long size = 0;
        Object sizeObj = f.get("size");
        if (sizeObj instanceof Number) size = ((Number) sizeObj).longValue();
        else if (sizeObj instanceof String) {
            try { size = Long.parseLong((String) sizeObj); } catch (Exception ignored) {}
        }
        return new BackupInfo(str(f.get("id")), str(f.get("name")),
                str(f.get("modifiedTime")), size);
    }

    /** The id out of a create-file response. */
    public static String parseCreatedId(String json) throws MiniJson.JsonException {
        Map<String, Object> root = MiniJson.parseObject(json);
        String id = str(root.get("id"));
        if (id == null) throw new MiniJson.JsonException("Drive create response had no id");
        return id;
    }

    /** Best human error out of a Drive error body, else "HTTP n". */
    public static String errorMessage(String body, int httpCode) {
        if (body != null && !body.isEmpty()) {
            try {
                Map<String, Object> root = MiniJson.parseObject(body);
                Object err = root.get("error");
                if (err instanceof Map) {
                    String msg = str(((Map<?, ?>) err).get("message"));
                    if (msg != null && !msg.isEmpty()) return msg;
                }
            } catch (Exception ignored) {}
        }
        return "HTTP " + httpCode;
    }

    private static String str(Object o) {
        return o instanceof String ? (String) o : null;
    }
}
