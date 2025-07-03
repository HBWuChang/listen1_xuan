package io.flutter.plugins.webview_cookie_manager

import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import org.junit.Test
import java.lang.Error

class WebViewCookieManagerExampleTest {
    @Test
    fun onMethodCall_withoutDomainAttribute() {
        val plugin = WebviewCookieManagerPlugin()
        val cookie = mutableMapOf("cookie_name" to "name", "cookie_value" to "value")
        cookie["asString"] = cookie.toString()
        val methodCall = MethodCall("setCookies", listOf(cookie))

        plugin.onMethodCall(methodCall, object : MethodChannel.Result {
            override fun success(result: Any?) {}
            override fun error(errorCode: String?, errorMessage: String?, errorDetails: Any?) {
                throw Error("Code: ${errorCode ?: "null"}\nMessage: ${errorMessage ?: "null"}")
            }
            override fun notImplemented() {
                throw NotImplementedError("Method 'setCookies' not implemented")
            }
        })
    }
}