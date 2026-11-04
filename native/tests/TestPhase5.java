import com.smartwallet.smart_wallet.DriveCodec;
import com.smartwallet.smart_wallet.MiniJson;
import com.smartwallet.smart_wallet.WidgetFormat;
import com.smartwallet.smart_wallet.SessionGate;

import java.net.URLDecoder;

/**
 * Phase 5 JVM tests: the session-gate decision, Drive REST request
 * construction + response parsing, and the widget balance
 * formatting. Run via ./build-apk.sh test. The Google SDK classes
 * themselves are exercised on-device, not here.
 */
public class TestPhase5 {

    private static int passed = 0;
    private static int failed = 0;

    private static void check(boolean cond, String name) {
        if (cond) {
            passed++;
        } else {
            failed++;
            System.out.println("FAIL: " + name);
        }
    }

    private static void eq(Object actual, Object expected, String name) {
        boolean ok = expected == null ? actual == null : expected.equals(actual);
        if (!ok) {
            System.out.println("FAIL: " + name + " — expected <" + expected
                    + "> but was <" + actual + ">");
        }
        check(ok, name);
    }

    public static void main(String[] args) throws Exception {
        testSessionGate();
        testDriveUrls();
        testDriveParsing();
        testWidgetFormat();
        System.out.println("TestPhase5: " + passed + " passed, " + failed + " failed");
        if (failed > 0) System.exit(1);
    }

    // ------------------------------------------------------------ gate

    private static void testSessionGate() {
        // Not signed in -> LOGIN regardless of anything else.
        eq(SessionGate.decide(false, false, 34, true),
                SessionGate.Route.LOGIN, "gate: guest -> login");
        eq(SessionGate.decide(false, true, 34, true),
                SessionGate.Route.LOGIN, "gate: signed-out + bio flag -> login");

        // Signed in, biometric off -> DASHBOARD.
        eq(SessionGate.decide(true, false, 34, true),
                SessionGate.Route.DASHBOARD, "gate: plain session -> dashboard");

        // Signed in + biometric on + available -> BIOMETRIC.
        eq(SessionGate.decide(true, true, 34, true),
                SessionGate.Route.BIOMETRIC, "gate: bio on -> lock");
        eq(SessionGate.decide(true, true, 28, true),
                SessionGate.Route.BIOMETRIC, "gate: bio on API 28 -> lock");

        // Biometric on but impossible -> DASHBOARD (never locked out).
        eq(SessionGate.decide(true, true, 27, true),
                SessionGate.Route.DASHBOARD, "gate: API 27 -> dashboard");
        eq(SessionGate.decide(true, true, 26, false),
                SessionGate.Route.DASHBOARD, "gate: API 26 -> dashboard");
        eq(SessionGate.decide(true, true, 34, false),
                SessionGate.Route.DASHBOARD, "gate: no hw/enrolment -> dashboard");
    }

    // ------------------------------------------------------------ drive urls

    private static String queryParam(String url, String key) throws Exception {
        String q = url.substring(url.indexOf('?') + 1);
        for (String pair : q.split("&")) {
            int i = pair.indexOf('=');
            if (pair.substring(0, i).equals(key)) {
                return URLDecoder.decode(pair.substring(i + 1), "UTF-8");
            }
        }
        return null;
    }

    private static void testDriveUrls() throws Exception {
        String list = DriveCodec.listUrl();
        check(list.startsWith("https://www.googleapis.com/drive/v3/files?"),
                "list url base");
        eq(queryParam(list, "spaces"), "appDataFolder", "list url spaces");
        eq(queryParam(list, "q"),
                "name = 'smart_wallet_backup.smartwallet' and trashed = false",
                "list url query");
        eq(queryParam(list, "fields"), "files(id,name,modifiedTime,size)",
                "list url fields");

        eq(DriveCodec.createFileUrl(),
                "https://www.googleapis.com/drive/v3/files", "create url");
        String meta = DriveCodec.createMetadataJson();
        check(meta.contains("\"name\":\"smart_wallet_backup.smartwallet\""),
                "metadata name");
        check(meta.contains("\"parents\":[\"appDataFolder\"]"), "metadata parents");
        check(meta.contains("Smart Wallet Encrypted Database Cloud Backup"),
                "metadata description");

        eq(DriveCodec.uploadMediaUrl("abc123"),
                "https://www.googleapis.com/upload/drive/v3/files/abc123?uploadType=media",
                "upload media url");
        eq(DriveCodec.downloadUrl("abc123"),
                "https://www.googleapis.com/drive/v3/files/abc123?alt=media",
                "download url");
        check(DriveCodec.downloadUrl("a b").contains("a+b")
                        || DriveCodec.downloadUrl("a b").contains("a%20b"),
                "download url encodes id");
    }

    // ------------------------------------------------------------ drive parsing

    private static void testDriveParsing() throws Exception {
        String sample = "{\"files\":[{\"id\":\"1AbC_xYz\",\"name\":\"smart_wallet_backup"
                + ".smartwallet\",\"modifiedTime\":\"2026-11-04T10:25:30.000Z\","
                + "\"size\":\"12345\"}]}";
        DriveCodec.BackupInfo info = DriveCodec.parseFirstFile(sample);
        check(info != null, "parse: info present");
        eq(info.fileId, "1AbC_xYz", "parse: id");
        eq(info.name, "smart_wallet_backup.smartwallet", "parse: name");
        eq(info.sizeBytes, 12345L, "parse: size from string");
        eq(info.prettySize(), "12.1 KB", "parse: pretty size KB");
        check(info.prettyModified().contains("2026"), "parse: pretty time has year");

        eq(DriveCodec.parseFirstFile("{\"files\":[]}"), null, "parse: empty -> null");
        eq(DriveCodec.parseFirstFile("{}"), null, "parse: no files key -> null");

        String numeric = "{\"files\":[{\"id\":\"x\",\"name\":\"n\","
                + "\"modifiedTime\":\"2026-01-01T00:00:00.000Z\",\"size\":512}]}";
        DriveCodec.BackupInfo small = DriveCodec.parseFirstFile(numeric);
        eq(small.sizeBytes, 512L, "parse: size from number");
        eq(small.prettySize(), "512 B", "parse: pretty size B");

        eq(DriveCodec.parseCreatedId("{\"id\":\"newId42\",\"name\":\"f\"}"),
                "newId42", "parse: created id");
        boolean threw = false;
        try {
            DriveCodec.parseCreatedId("{\"name\":\"f\"}");
        } catch (MiniJson.JsonException e) {
            threw = true;
        }
        check(threw, "parse: created without id throws");

        String err = "{\"error\":{\"code\":404,\"message\":\"File not found.\","
                + "\"errors\":[{\"domain\":\"global\",\"reason\":\"notFound\"}]}}";
        eq(DriveCodec.errorMessage(err, 404), "File not found.", "error: message");
        eq(DriveCodec.errorMessage("not json", 500), "HTTP 500", "error: fallback");
        eq(DriveCodec.errorMessage(null, 401), "HTTP 401", "error: null body");
    }

    // ------------------------------------------------------------ widget

    private static void testWidgetFormat() {
        eq(WidgetFormat.formatBalance(1500, "INR"),
                "₹1500.00", "widget: positive INR");
        eq(WidgetFormat.formatBalance(-250.5, "INR"),
                "-₹250.50", "widget: negative INR");
        eq(WidgetFormat.formatBalance(0, "INR"),
                "₹0.00", "widget: zero");
        eq(WidgetFormat.formatBalance(99.999, "USD"),
                "$100.00", "widget: rounding + USD");
        eq(WidgetFormat.formatBalance(1234567.89, "EUR"),
                "€1234567.89", "widget: no grouping (Flutter parity)");
        eq(WidgetFormat.currencySymbol("XYZ"), "XYZ ",
                "widget: unknown currency falls back to code");
        eq(WidgetFormat.currencySymbol(null), "₹",
                "widget: null currency defaults to rupee");
    }
}
