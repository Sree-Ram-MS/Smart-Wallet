package com.smartwallet.smart_wallet;

import android.content.Context;

import java.io.ByteArrayOutputStream;
import java.io.InputStream;
import java.io.OutputStream;
import java.net.HttpURLConnection;
import java.net.URL;
import java.nio.charset.StandardCharsets;

/**
 * Google Drive AppData backup over the Drive v3 REST API (Phase 5),
 * the counterpart of Flutter's GoogleDriveBackupService:
 *
 *   - the backup file is smart_wallet_backup.smartwallet in
 *     appDataFolder;
 *   - upload overwrites the existing file, or creates it (metadata
 *     POST, then media PATCH — the two-step simple upload);
 *   - download fetches the file bytes for the normal restore flow;
 *   - a 401/403 clears the cached token and retries ONCE with a
 *     fresh one, like Flutter's authenticated client.
 *
 * Auth is behind the TokenProvider interface (AuthService in the
 * app) so the REST layer itself has no Google-SDK dependency. Every
 * method blocks — call from a background thread; results come back
 * through Callback, already marshalled by the caller's executor
 * choice (this class invokes callbacks on its worker thread).
 */
public final class DriveBackupService {

    public interface TokenProvider {
        String token() throws AuthService.AuthException;
        void invalidate(String token);
    }

    public interface Callback<T> {
        void onOk(T value);
        void onError(String message, android.content.Intent recoveryIntent);
    }

    private final Context ctx;
    private final TokenProvider tokens;

    public DriveBackupService(Context ctx, TokenProvider tokens) {
        this.ctx = ctx.getApplicationContext();
        this.tokens = tokens;
    }

    /** TokenProvider backed by AuthService/GoogleAuthUtil. */
    public static TokenProvider authServiceProvider(final Context ctx) {
        return new TokenProvider() {
            @Override public String token() throws AuthService.AuthException {
                return AuthService.driveTokenBlocking(ctx);
            }
            @Override public void invalidate(String token) {
                AuthService.clearTokenBlocking(ctx, token);
            }
        };
    }

    // ------------------------------------------------------------ API

    /** Cloud backup info, or onOk(null) when Drive holds no backup. */
    public void fetchInfo(final Callback<DriveCodec.BackupInfo> cb) {
        run(new Work<DriveCodec.BackupInfo>() {
            @Override public DriveCodec.BackupInfo go() throws Exception {
                HttpResult r = request("GET", DriveCodec.listUrl(), null, null);
                return DriveCodec.parseFirstFile(r.bodyText());
            }
        }, cb);
    }

    /**
     * Uploads backup bytes: PATCH media onto the existing file when
     * there is one, else create metadata + PATCH media.
     */
    public void upload(final byte[] bytes, final Callback<DriveCodec.BackupInfo> cb) {
        run(new Work<DriveCodec.BackupInfo>() {
            @Override public DriveCodec.BackupInfo go() throws Exception {
                HttpResult list = request("GET", DriveCodec.listUrl(), null, null);
                DriveCodec.BackupInfo existing = DriveCodec.parseFirstFile(list.bodyText());
                String fileId;
                if (existing != null) {
                    fileId = existing.fileId;
                } else {
                    HttpResult created = request("POST", DriveCodec.createFileUrl(),
                            "application/json; charset=UTF-8",
                            DriveCodec.createMetadataJson().getBytes(StandardCharsets.UTF_8));
                    fileId = DriveCodec.parseCreatedId(created.bodyText());
                }
                request("PATCH", DriveCodec.uploadMediaUrl(fileId),
                        "application/octet-stream", bytes);
                HttpResult after = request("GET", DriveCodec.listUrl(), null, null);
                return DriveCodec.parseFirstFile(after.bodyText());
            }
        }, cb);
    }

    /** Downloads the backup file's bytes. */
    public void download(final String fileId, final Callback<byte[]> cb) {
        run(new Work<byte[]>() {
            @Override public byte[] go() throws Exception {
                HttpResult r = request("GET", DriveCodec.downloadUrl(fileId), null, null);
                return r.body;
            }
        }, cb);
    }

    // ------------------------------------------------------------ plumbing

    private interface Work<T> {
        T go() throws Exception;
    }

    private <T> void run(final Work<T> work, final Callback<T> cb) {
        new Thread(new Runnable() {
            @Override public void run() {
                try {
                    cb.onOk(work.go());
                } catch (AuthService.AuthException e) {
                    cb.onError(e.getMessage(), e.recoveryIntent);
                } catch (Exception e) {
                    cb.onError(e.getMessage() != null ? e.getMessage()
                            : e.getClass().getSimpleName(), null);
                }
            }
        }, "drive-backup").start();
    }

    private static final class HttpResult {
        final byte[] body;
        HttpResult(byte[] body) { this.body = body; }
        String bodyText() { return new String(body, StandardCharsets.UTF_8); }
    }

    private static final class HttpError extends Exception {
        final int code;
        HttpError(int code, String msg) { super(msg); this.code = code; }
    }

    /**
     * One authenticated request; on 401/403 the token is invalidated
     * and the request retried once with a fresh token (Flutter parity).
     */
    private HttpResult request(String method, String url, String contentType, byte[] body)
            throws Exception {
        String token = tokens.token();
        try {
            return requestOnce(method, url, contentType, body, token);
        } catch (HttpError e) {
            if (e.code != 401 && e.code != 403) throw e;
            tokens.invalidate(token);
            return requestOnce(method, url, contentType, body, tokens.token());
        }
    }

    private HttpResult requestOnce(String method, String url, String contentType,
                                   byte[] body, String token) throws Exception {
        HttpURLConnection c = (HttpURLConnection) new URL(url).openConnection();
        try {
            c.setRequestMethod(method);
            c.setConnectTimeout(30_000);
            c.setReadTimeout(60_000);
            c.setRequestProperty("Authorization", "Bearer " + token);
            if (body != null) {
                c.setDoOutput(true);
                if (contentType != null) c.setRequestProperty("Content-Type", contentType);
                c.setFixedLengthStreamingMode(body.length);
                OutputStream out = c.getOutputStream();
                out.write(body);
                out.close();
            }
            int code = c.getResponseCode();
            InputStream in = code >= 200 && code < 300
                    ? c.getInputStream() : c.getErrorStream();
            byte[] data = readAll(in);
            if (code < 200 || code >= 300) {
                throw new HttpError(code, DriveCodec.errorMessage(
                        new String(data, StandardCharsets.UTF_8), code));
            }
            return new HttpResult(data);
        } finally {
            c.disconnect();
        }
    }

    private static byte[] readAll(InputStream in) throws Exception {
        if (in == null) return new byte[0];
        ByteArrayOutputStream bos = new ByteArrayOutputStream();
        byte[] buf = new byte[8192];
        int n;
        while ((n = in.read(buf)) != -1) bos.write(buf, 0, n);
        in.close();
        return bos.toByteArray();
    }
}
