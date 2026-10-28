package com.marketpilot.core.network

import com.marketpilot.core.model.ProviderError
import com.marketpilot.core.model.ProviderErrorKind
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.delay
import kotlinx.coroutines.suspendCancellableCoroutine
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import okhttp3.Call
import okhttp3.Callback
import okhttp3.FormBody
import okhttp3.Interceptor
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.Response
import java.io.IOException
import java.net.SocketTimeoutException
import java.util.concurrent.ConcurrentHashMap
import java.util.concurrent.TimeUnit
import kotlin.coroutines.resume
import kotlin.coroutines.resumeWithException

data class HttpResponse(val code: Int, val body: String, val headers: Map<String, String>, val url: String) {
    val isSuccessful: Boolean get() = code in 200..299
    fun header(name: String): String? = headers.entries.firstOrNull { it.key.equals(name, ignoreCase = true) }?.value
}

sealed interface FetchResult {
    data class Ok(val response: HttpResponse) : FetchResult
    data class Failed(val error: ProviderError, val retryAfterSeconds: Long? = null) : FetchResult
}

object HttpClients {
    /** Strict timeouts; plain HTTP is refused (all providers are HTTPS). */
    fun create(userAgent: String): OkHttpClient = OkHttpClient.Builder()
        .connectTimeout(10, TimeUnit.SECONDS)
        .readTimeout(25, TimeUnit.SECONDS)
        .writeTimeout(15, TimeUnit.SECONDS)
        .callTimeout(45, TimeUnit.SECONDS)
        .followRedirects(true)
        .followSslRedirects(false)
        .addInterceptor(HttpsOnlyInterceptor())
        .addInterceptor(Interceptor { chain ->
            val req = chain.request()
            chain.proceed(if (req.header("User-Agent") == null) req.newBuilder().header("User-Agent", userAgent).build() else req)
        })
        .build()
}

class HttpsOnlyInterceptor(private val allowCleartextHosts: Set<String> = setOf("localhost", "127.0.0.1")) : Interceptor {
    override fun intercept(chain: Interceptor.Chain): Response {
        val url = chain.request().url
        if (!url.isHttps && url.host !in allowCleartextHosts) throw IOException("Connessione non HTTPS rifiutata: ${url.host}")
        return chain.proceed(chain.request())
    }
}

/** Simple per-host spacing limiter: at most one request every [minIntervalMs] per host. */
class HostRateLimiter(private val minIntervalMsByHost: Map<String, Long>, private val defaultIntervalMs: Long = 250) {
    private val locks = ConcurrentHashMap<String, Mutex>()
    private val last = ConcurrentHashMap<String, Long>()

    suspend fun acquire(host: String, now: () -> Long = System::currentTimeMillis) {
        val interval = minIntervalMsByHost.entries.firstOrNull { host.endsWith(it.key) }?.value ?: defaultIntervalMs
        locks.getOrPut(host) { Mutex() }.withLock {
            val wait = (last[host] ?: 0L) + interval - now()
            if (wait > 0) delay(wait)
            last[host] = now()
        }
    }

    /** Pushes the next allowed request for [host] into the future (after a 429). */
    fun backOff(host: String, seconds: Long, now: () -> Long = System::currentTimeMillis) {
        last[host] = now() + seconds * 1000
    }
}

class HttpFetcher(
    private val client: OkHttpClient,
    private val limiter: HostRateLimiter = HostRateLimiter(DEFAULT_LIMITS),
    private val maxAttempts: Int = 3,
    private val baseBackoffMs: Long = 800,
) {
    suspend fun get(url: String, headers: Map<String, String> = emptyMap()): FetchResult =
        execute(Request.Builder().url(url).apply { headers.forEach { (k, v) -> header(k, v) } }.get().build())

    suspend fun postForm(url: String, form: Map<String, String>, headers: Map<String, String> = emptyMap()): FetchResult {
        val body = FormBody.Builder().apply { form.forEach { (k, v) -> add(k, v) } }.build()
        return execute(Request.Builder().url(url).apply { headers.forEach { (k, v) -> header(k, v) } }.post(body).build(), retry = false)
    }

    private suspend fun execute(request: Request, retry: Boolean = true): FetchResult {
        var attempt = 0
        var last: FetchResult.Failed? = null
        while (attempt < (if (retry) maxAttempts else 1)) {
            attempt++
            limiter.acquire(request.url.host)
            val result = try {
                val resp = client.newCall(request).await()
                resp.use {
                    val body = it.body?.string() ?: ""
                    val hr = HttpResponse(it.code, body, it.headers.toMultimap().mapValues { e -> e.value.joinToString(",") }, it.request.url.toString())
                    when {
                        it.isSuccessful -> return FetchResult.Ok(hr)
                        it.code == 429 -> {
                            val ra = it.header("Retry-After")?.toLongOrNull() ?: (attempt * 5L)
                            limiter.backOff(request.url.host, ra)
                            FetchResult.Failed(ProviderError(ProviderErrorKind.RATE_LIMITED, "Limite di richieste raggiunto (HTTP 429)", 429), ra)
                        }
                        it.code == 401 || it.code == 403 -> FetchResult.Failed(ProviderError(ProviderErrorKind.AUTH, "Accesso negato (HTTP ${it.code})", it.code))
                        it.code == 404 -> FetchResult.Failed(ProviderError(ProviderErrorKind.HTTP, "Risorsa non trovata (HTTP 404)", 404))
                        else -> FetchResult.Failed(ProviderError(ProviderErrorKind.HTTP, "Errore HTTP ${it.code}", it.code))
                    }
                }
            } catch (e: CancellationException) {
                throw e
            } catch (e: SocketTimeoutException) {
                FetchResult.Failed(ProviderError(ProviderErrorKind.TIMEOUT, "Timeout di rete"))
            } catch (e: IOException) {
                FetchResult.Failed(ProviderError(ProviderErrorKind.NETWORK, "Errore di rete: ${e.message ?: e.javaClass.simpleName}"))
            }
            last = result as FetchResult.Failed
            if (!result.error.isRetryable || result.error.kind == ProviderErrorKind.RATE_LIMITED && (result.retryAfterSeconds ?: 0) > 30) break
            if (attempt < maxAttempts && retry) delay(baseBackoffMs * (1L shl (attempt - 1)))
        }
        return last ?: FetchResult.Failed(ProviderError(ProviderErrorKind.NETWORK, "Richiesta non eseguita"))
    }

    companion object {
        /** Conservative spacing per host (SEC fair access policy allows up to 10 req/s). */
        val DEFAULT_LIMITS = mapOf(
            "sec.gov" to 150L,
            "finance.yahoo.com" to 350L,
            "alphavantage.co" to 13_000L, // free tier: 5 requests/minute
            "finnhub.io" to 1_100L, // free tier: 60 requests/minute
            "reddit.com" to 1_100L,
            "stlouisfed.org" to 300L,
        )
    }
}

suspend fun Call.await(): Response = suspendCancellableCoroutine { cont ->
    enqueue(object : Callback {
        override fun onResponse(call: Call, response: Response) = cont.resume(response)
        override fun onFailure(call: Call, e: IOException) { if (!cont.isCancelled) cont.resumeWithException(e) }
    })
    cont.invokeOnCancellation { runCatching { cancel() } }
}
