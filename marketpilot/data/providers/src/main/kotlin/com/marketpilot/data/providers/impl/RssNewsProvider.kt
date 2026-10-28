package com.marketpilot.data.providers.impl

import com.marketpilot.core.common.AppClock
import com.marketpilot.core.model.Freshness
import com.marketpilot.core.model.NewsItem
import com.marketpilot.core.model.ProviderDescriptor
import com.marketpilot.core.model.ProviderError
import com.marketpilot.core.model.ProviderErrorKind
import com.marketpilot.core.model.ProviderResult
import com.marketpilot.core.network.FetchResult
import com.marketpilot.core.network.HttpFetcher
import com.marketpilot.data.providers.NewsProvider
import com.marketpilot.data.providers.ProviderCatalog
import com.marketpilot.domain.scoring.NewsClassifier
import java.security.MessageDigest
import java.time.Instant
import java.time.LocalDate
import java.time.OffsetDateTime
import java.time.ZoneOffset
import java.time.ZonedDateTime
import java.time.format.DateTimeFormatter

object RssParser {
    data class Item(val title: String, val link: String, val published: Instant?, val description: String?)

    private fun parseDate(s: String?): Instant? {
        val t = s?.trim()?.takeIf { it.isNotEmpty() } ?: return null
        return runCatching { ZonedDateTime.parse(t, DateTimeFormatter.RFC_1123_DATE_TIME).toInstant() }.getOrNull()
            ?: runCatching { OffsetDateTime.parse(t).toInstant() }.getOrNull()
            ?: runCatching { Instant.parse(t) }.getOrNull()
    }

    /** RSS 2.0 and Atom. Descriptions are kept verbatim (HTML tags stripped), never generated. */
    fun parse(xml: String): List<Item> {
        val root = SafeXml.parse(xml).documentElement
        val rssItems = root.descendants("item").map { e ->
            Item(
                e.child("title").text() ?: "", e.child("link").text() ?: e.child("guid").text() ?: "",
                parseDate(e.child("pubDate").text() ?: e.child("date").text()), e.child("description").text()?.let(::stripHtml),
            )
        }
        val atomItems = root.children("entry").map { e ->
            Item(
                e.child("title").text() ?: "", e.child("link")?.getAttribute("href") ?: "",
                parseDate(e.child("updated").text() ?: e.child("published").text()), e.child("summary").text()?.let(::stripHtml),
            )
        }
        return (rssItems + atomItems).filter { it.title.isNotBlank() && it.link.startsWith("https://") }
    }

    fun stripHtml(s: String): String = s.replace(Regex("<[^>]+>"), " ").replace("&nbsp;", " ").replace(Regex("\\s+"), " ").trim()
}

/** A news feed: official RSS (Fed, SEC) or per-symbol Yahoo Finance RSS. */
class RssNewsProvider(
    private val http: HttpFetcher,
    override val descriptor: ProviderDescriptor,
    private val feedUrls: (List<String>) -> List<Pair<String, List<String>>>,
    private val publisher: String,
    private val clock: AppClock = AppClock.SYSTEM,
) : NewsProvider {

    override suspend fun news(symbols: List<String>, since: LocalDate): ProviderResult<List<NewsItem>> {
        val now = clock.now()
        val feeds = feedUrls(symbols)
        val out = mutableListOf<NewsItem>()
        var firstError: ProviderError? = null
        val sinceInstant = since.atStartOfDay(ZoneOffset.UTC).toInstant()
        for ((url, related) in feeds) {
            when (val r = http.get(url)) {
                is FetchResult.Failed -> if (firstError == null) firstError = r.error
                is FetchResult.Ok -> runCatching { RssParser.parse(r.response.body) }.onSuccess { items ->
                    items.filter { it.published != null && !it.published.isBefore(sinceInstant) }.forEach { i ->
                        out += NewsItem(
                            id = sha1(i.link), headline = i.title, publisher = publisher, publishedAt = i.published!!, url = i.link,
                            relatedSymbols = related, category = NewsClassifier.categorize(i.title, i.description),
                            description = i.description?.take(500), providerId = descriptor.id,
                        )
                    }
                }.onFailure { if (firstError == null) firstError = parseError("Feed RSS non valido") }
            }
        }
        val src = feeds.firstOrNull()?.first ?: descriptor.homepage
        if (out.isEmpty() && firstError != null) return fail(descriptor, src, now, firstError!!)
        return ok(descriptor, src, out.toList(), out.maxOfOrNull { it.publishedAt }, now, Freshness.DELAYED,
            quality = com.marketpilot.core.model.DataQuality(if (firstError == null) 1.0 else 0.5, listOfNotNull(firstError?.message)))
    }

    companion object {
        fun sha1(s: String): String = MessageDigest.getInstance("SHA-1").digest(s.toByteArray()).joinToString("") { "%02x".format(it) }

        fun federalReserve(http: HttpFetcher, clock: AppClock = AppClock.SYSTEM) = RssNewsProvider(
            http, ProviderCatalog.FED_RSS, { listOf("https://www.federalreserve.gov/feeds/press_all.xml" to emptyList()) }, "Federal Reserve", clock,
        )

        fun secPress(http: HttpFetcher, clock: AppClock = AppClock.SYSTEM) = RssNewsProvider(
            http, ProviderCatalog.SEC_RSS, { listOf("https://www.sec.gov/news/pressreleases.rss" to emptyList()) }, "SEC", clock,
        )

        fun yahooHeadlines(http: HttpFetcher, clock: AppClock = AppClock.SYSTEM) = RssNewsProvider(
            http, ProviderCatalog.YAHOO_RSS,
            { symbols -> symbols.map { "https://feeds.finance.yahoo.com/rss/2.0/headline?s=${java.net.URLEncoder.encode(it, "UTF-8")}&region=US&lang=en-US" to listOf(it) } },
            "Yahoo Finance (RSS)", clock,
        )
    }
}

internal fun notConfigured(d: ProviderDescriptor, what: String) = ProviderError(ProviderErrorKind.NOT_CONFIGURED, "$what non configurata per ${d.displayName}")
