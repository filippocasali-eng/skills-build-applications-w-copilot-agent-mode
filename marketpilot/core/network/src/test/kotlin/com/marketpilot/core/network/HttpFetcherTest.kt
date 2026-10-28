package com.marketpilot.core.network

import com.marketpilot.core.model.ProviderErrorKind
import kotlinx.coroutines.runBlocking
import okhttp3.OkHttpClient
import okhttp3.mockwebserver.MockResponse
import okhttp3.mockwebserver.MockWebServer
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertTrue

class HttpFetcherTest {
    private fun fetcher(server: MockWebServer) = HttpFetcher(
        OkHttpClient.Builder().addInterceptor(HttpsOnlyInterceptor()).build(),
        HostRateLimiter(emptyMap(), 0), maxAttempts = 3, baseBackoffMs = 1,
    )

    @Test fun retriesServerErrorsThenSucceeds() = runBlocking {
        MockWebServer().use { s ->
            s.enqueue(MockResponse().setResponseCode(503))
            s.enqueue(MockResponse().setBody("ok"))
            val r = fetcher(s).get(s.url("/x").toString())
            assertTrue(r is FetchResult.Ok)
            assertEquals("ok", (r as FetchResult.Ok).response.body)
            assertEquals(2, s.requestCount)
        }
    }

    @Test fun rateLimitIsReportedWithRetryAfter() = runBlocking {
        MockWebServer().use { s ->
            repeat(3) { s.enqueue(MockResponse().setResponseCode(429).setHeader("Retry-After", "120")) }
            val r = fetcher(s).get(s.url("/x").toString()) as FetchResult.Failed
            assertEquals(ProviderErrorKind.RATE_LIMITED, r.error.kind)
            assertEquals(120L, r.retryAfterSeconds)
            assertEquals(1, s.requestCount) // long Retry-After: no hammering
        }
    }

    @Test fun authErrorsAreNotRetried() = runBlocking {
        MockWebServer().use { s ->
            s.enqueue(MockResponse().setResponseCode(403))
            val r = fetcher(s).get(s.url("/x").toString()) as FetchResult.Failed
            assertEquals(ProviderErrorKind.AUTH, r.error.kind)
            assertEquals(1, s.requestCount)
        }
    }

    @Test fun cleartextToRemoteHostIsRefused() = runBlocking {
        val r = fetcher(MockWebServer()).get("http://example.com/data") as FetchResult.Failed
        assertEquals(ProviderErrorKind.NETWORK, r.error.kind)
        assertTrue(r.error.message.contains("HTTPS"))
    }

    @Test fun limiterSpacesRequests() = runBlocking {
        var clock = 0L
        val limiter = HostRateLimiter(mapOf("h" to 1000L))
        limiter.acquire("h") { clock }
        val start = System.currentTimeMillis()
        clock = 990L
        limiter.acquire("h") { clock }
        assertTrue(System.currentTimeMillis() - start >= 5)
    }
}
