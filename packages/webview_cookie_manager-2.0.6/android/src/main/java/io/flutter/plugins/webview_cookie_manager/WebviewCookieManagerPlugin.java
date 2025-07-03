package io.flutter.plugins.webview_cookie_manager;

import androidx.annotation.NonNull;

import io.flutter.embedding.engine.plugins.FlutterPlugin;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;
import io.flutter.plugin.common.MethodChannel.MethodCallHandler;
import io.flutter.plugin.common.MethodChannel.Result;

import android.net.Uri;
import android.os.Build;
import android.os.Build.VERSION_CODES;
import android.webkit.CookieManager;
import android.webkit.ValueCallback;

import java.net.HttpCookie;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

/**
 * WebviewCookieManagerPlugin
 */
public class WebviewCookieManagerPlugin implements FlutterPlugin, MethodCallHandler {
    /// The MethodChannel that will the communication between Flutter and native Android
    ///
    /// This local reference serves to register the plugin with the Flutter Engine and unregister it
    /// when the Flutter Engine is detached from the Activity
    private MethodChannel channel;

    @Override
    public void onAttachedToEngine(@NonNull FlutterPluginBinding flutterPluginBinding) {
        channel = new MethodChannel(flutterPluginBinding.getBinaryMessenger(), "webview_cookie_manager");
        channel.setMethodCallHandler(this);
    }

    private static void hasCookies(final Result result) {
        CookieManager cookieManager = CookieManager.getInstance();
        final boolean hasCookies = cookieManager.hasCookies();
        result.success(hasCookies);
    }

    private static void clearCookies(final Result result) {
        CookieManager cookieManager = CookieManager.getInstance();
        final boolean hasCookies = cookieManager.hasCookies();
        if (Build.VERSION.SDK_INT >= VERSION_CODES.LOLLIPOP) {
            cookieManager.removeAllCookies(
                    new ValueCallback<Boolean>() {
                        @Override
                        public void onReceiveValue(Boolean value) {
                            result.success(hasCookies);
                        }
                    });
        } else {
            cookieManager.removeAllCookie();
            result.success(hasCookies);
        }
    }

    private static void getCookies(final MethodCall methodCall, final Result result) {
        if (!(methodCall.arguments() instanceof Map)) {
            result.error(
                    "Invalid argument. Expected Map<String,String>, received "
                            + (methodCall.arguments().getClass().getSimpleName()),
                    null,
                    null);
            return;
        }

        final Map<String, String> arguments = methodCall.arguments();

        CookieManager cookieManager = CookieManager.getInstance();

        final String url = arguments.get("url");
        final String allCookiesString = url == null ? null : cookieManager.getCookie(url);
        final ArrayList<String> individualCookieStrings = allCookiesString == null ?
                new ArrayList<String>()
                : new ArrayList<String>(Arrays.asList(allCookiesString.split(";")));

        ArrayList<Map<String, Object>> serializedCookies = new ArrayList<>();
        for (String cookieString : individualCookieStrings) {
            try {
                final HttpCookie cookie = HttpCookie.parse(cookieString).get(0);
                if (cookie.getDomain() == null) {
                    cookie.setDomain(Uri.parse(url).getHost());
                }
                if (cookie.getPath() == null) {
                    cookie.setPath("/");
                }
                serializedCookies.add(cookieToMap(cookie));
            } catch (IllegalArgumentException e) {
                // Cookie is invalid. Ignoring.
            }
        }

        result.success(serializedCookies);
    }

    private static void setCookies(final MethodCall methodCall, final Result result) {
        if (!(methodCall.arguments() instanceof List)) {
            result.error(
                    "Invalid argument. Expected List<Map<String,String>>, received "
                            + (methodCall.arguments().getClass().getSimpleName()),
                    null,
                    null);
            return;
        }

        final List<Map<String, Object>> serializedCookies = methodCall.arguments();

        CookieManager cookieManager = CookieManager.getInstance();

        for (Map<String, Object> cookieMap : serializedCookies) {
            Object origin = cookieMap.get("origin");
            String domainString = origin instanceof String ? (String)origin : null;
            if (domainString == null) {
                Object domain = cookieMap.get("domain");
                domainString = domain instanceof String ? (String)domain : "";
            }
            final String value = cookieMap.get("asString").toString();
            cookieManager.setCookie(domainString, value);
        }

        result.success(null);
    }

    private static Map<String, Object> cookieToMap(HttpCookie cookie) {
        final HashMap<String, Object> resultMap = new HashMap<>();
        resultMap.put("name", cookie.getName());
        resultMap.put("value", cookie.getValue());
        resultMap.put("path", cookie.getPath());
        resultMap.put("domain", cookie.getDomain());
        resultMap.put("secure", cookie.getSecure());

        if (!cookie.hasExpired() && !cookie.getDiscard() && cookie.getMaxAge() > 0) {
            // translate `max-age` to `expires` by computing future expiration date
            long expires = (System.currentTimeMillis() / 1000) + cookie.getMaxAge();
            resultMap.put("expires", expires);
        }

        if (Build.VERSION.SDK_INT >= VERSION_CODES.N) {
            resultMap.put("httpOnly", cookie.isHttpOnly());
        }

        return resultMap;
    }

    @Override
    public void onMethodCall(MethodCall methodCall, Result result) {
        switch (methodCall.method) {
            case "clearCookies":
                clearCookies(result);
                break;
            case "hasCookies":
                hasCookies(result);
                break;
            case "getCookies":
                getCookies(methodCall, result);
                break;
            case "setCookies":
                setCookies(methodCall, result);
                break;
            default:
                result.notImplemented();
        }
    }

    @Override
    public void onDetachedFromEngine(@NonNull FlutterPluginBinding binding) {
        channel.setMethodCallHandler(null);
        channel = null;
    }
}
