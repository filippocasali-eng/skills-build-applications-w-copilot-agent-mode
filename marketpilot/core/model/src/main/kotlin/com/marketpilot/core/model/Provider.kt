package com.marketpilot.core.model

import kotlinx.serialization.Serializable
import java.time.Instant

@Serializable
enum class Freshness {
    /** Observation from the current session, within a few minutes. */
    LIVE,
    /** Observation from the current session but delayed (typically 15+ minutes). */
    DELAYED,
    /** Close of the most recent completed session. */
    END_OF_DAY,
    /** Older than the most recent completed session. */
    STALE,
    UNKNOWN,
}

@Serializable
enum class ProviderErrorKind {
    NETWORK, TIMEOUT, HTTP, RATE_LIMITED, PARSE, EMPTY, UNSUPPORTED, NOT_CONFIGURED, AUTH, BLOCKED, CANCELLED,
}

@Serializable
data class ProviderError(
    val kind: ProviderErrorKind,
    val message: String,
    val httpCode: Int? = null,
) {
    val isRetryable: Boolean
        get() = kind == ProviderErrorKind.NETWORK || kind == ProviderErrorKind.TIMEOUT ||
            kind == ProviderErrorKind.RATE_LIMITED || (kind == ProviderErrorKind.HTTP && (httpCode ?: 0) >= 500)
}

@Serializable
data class RateLimitInfo(
    val requestsPerMinute: Int? = null,
    val remaining: Int? = null,
    val retryAfterSeconds: Long? = null,
)

@Serializable
data class DataQuality(
    /** 0..1 share of expected fields/rows present. */
    val completeness: Double = 1.0,
    val warnings: List<String> = emptyList(),
)

@Serializable
data class SourceInfo(
    val providerId: String,
    val providerName: String,
    /** URL or stable identifier of the exact resource read. */
    val sourceUrl: String,
)

/**
 * Envelope returned by every provider call. Data is never returned without its provenance,
 * timestamps and freshness. On failure [data] is null and [error] is set.
 */
data class ProviderResult<out T>(
    val data: T?,
    val source: SourceInfo,
    val observedAt: Instant?,
    val retrievedAt: Instant,
    val freshness: Freshness,
    val currency: String? = null,
    val instrumentId: String? = null,
    val quality: DataQuality = DataQuality(),
    val error: ProviderError? = null,
    val rateLimit: RateLimitInfo? = null,
) {
    val isSuccess: Boolean get() = data != null && error == null

    fun <R> map(transform: (T) -> R): ProviderResult<R> = ProviderResult(
        data = data?.let(transform), source = source, observedAt = observedAt, retrievedAt = retrievedAt,
        freshness = freshness, currency = currency, instrumentId = instrumentId, quality = quality,
        error = error, rateLimit = rateLimit,
    )

    companion object {
        fun <T> failure(
            source: SourceInfo,
            error: ProviderError,
            retrievedAt: Instant,
            instrumentId: String? = null,
            rateLimit: RateLimitInfo? = null,
        ): ProviderResult<T> = ProviderResult(
            data = null, source = source, observedAt = null, retrievedAt = retrievedAt,
            freshness = Freshness.UNKNOWN, instrumentId = instrumentId, error = error, rateLimit = rateLimit,
        )
    }
}

@Serializable
enum class ProviderOperationalState {
    /** Verified by a successful real request during the last refresh. */
    OPERATIONAL,
    /** Last request failed or returned partial data. */
    DEGRADED,
    /** Provider needs a user credential that is not configured. */
    NEEDS_CONFIGURATION,
    /** Disabled by the user. */
    DISABLED,
    /** Cannot legitimately be used directly from Android (documented reason). */
    UNSUPPORTED,
    /** Never contacted yet. */
    UNTESTED,
}

@Serializable
enum class ProviderCapability { QUOTES, HISTORY, FUNDAMENTALS, NEWS, SOCIAL, INSIDERS, INSTITUTIONAL, MACRO, FX }

@Serializable
data class ProviderDescriptor(
    val id: String,
    val displayName: String,
    val capabilities: Set<ProviderCapability>,
    val requiresApiKey: Boolean,
    val official: Boolean,
    val homepage: String,
    val termsNote: String,
    val defaultEnabled: Boolean,
)

@Serializable
data class ProviderStatus(
    val providerId: String,
    val state: ProviderOperationalState,
    @Serializable(with = InstantSerializer::class) val lastSuccessAt: Instant? = null,
    @Serializable(with = InstantSerializer::class) val lastAttemptAt: Instant? = null,
    val lastError: String? = null,
    val successCount: Int = 0,
    val failureCount: Int = 0,
)
