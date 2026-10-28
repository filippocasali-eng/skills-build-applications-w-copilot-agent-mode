package com.marketpilot.data.providers.impl

import com.marketpilot.core.common.AppClock
import com.marketpilot.core.model.Freshness
import com.marketpilot.core.model.ProviderError
import com.marketpilot.core.model.ProviderErrorKind
import com.marketpilot.core.model.ProviderResult
import com.marketpilot.core.model.RedditTickerStats
import com.marketpilot.core.network.FetchResult
import com.marketpilot.core.network.HttpFetcher
import com.marketpilot.data.providers.ProviderCatalog
import com.marketpilot.data.providers.SocialSentimentProvider
import java.time.Duration
import java.time.Instant
import java.util.Base64

data class RedditPost(
    val id: String,
    val subreddit: String,
    val author: String,
    val title: String,
    val body: String,
    val score: Int,
    val comments: Int,
    val createdAt: Instant,
    val permalink: String,
)

object RedditAnalyzer {
    /**
     * Words that are also tickers. They count only as cashtags ($A, $ALL...), never as bare words,
     * to avoid misreading ordinary English as ticker mentions.
     */
    val AMBIGUOUS = setOf(
        "A", "I", "ALL", "ARE", "BE", "CAN", "FOR", "IT", "NOW", "ON", "ONE", "OUT", "SEE", "SO", "TWO", "YOU", "DD", "CEO", "CFO",
        "USA", "GDP", "ATH", "YOLO", "EPS", "IPO", "ETF", "FED", "CPI", "AI", "EV", "PE", "MA", "V", "GO", "BIG", "OPEN", "REAL",
        "GOOD", "BEST", "LOVE", "PLAY", "RUN", "NEW", "HAS", "LOW", "HIGH", "WELL", "TOP", "AT", "BY", "OR", "AN", "AM", "IS", "UP",
        "DOWN", "BUY", "SELL", "HOLD", "CASH", "EDIT", "TLDR", "IMO", "LOL", "WSB", "SEC", "FOMO", "NYSE", "OTC", "API", "PM", "AH",
        "GE", "KO", "HD", "PG", "GS", "DIS", "CAT",
    )

    private val cashtag = Regex("\\$([A-Z]{1,5})(?![A-Za-z])")
    private val bare = Regex("(?<![A-Za-z$])([A-Z]{2,5})(?![A-Za-z])")

    fun extractTickers(text: String, universe: Set<String>): Set<String> {
        val found = mutableSetOf<String>()
        cashtag.findAll(text).forEach { m -> m.groupValues[1].let { if (it in universe) found += it } }
        bare.findAll(text).forEach { m -> m.groupValues[1].let { if (it in universe && it !in AMBIGUOUS) found += it } }
        return found
    }

    private val bullish = setOf("calls", "moon", "buy", "buying", "bullish", "long", "undervalued", "beat", "beats", "rocket", "breakout", "squeeze", "upgrade", "rally")
    private val bearish = setOf("puts", "short", "shorting", "bearish", "sell", "selling", "overvalued", "crash", "dump", "bagholder", "bagholding", "miss", "downgrade", "fraud", "bankrupt")

    /** -1..1 lexicon sentiment (automated interpretation, clearly labelled in the UI). */
    fun sentiment(text: String): Double {
        val words = text.lowercase().split(Regex("[^a-z]+"))
        val b = words.count { it in bullish }
        val s = words.count { it in bearish }
        return if (b + s == 0) 0.0 else (b - s).toDouble() / (b + s)
    }

    fun stats(posts: List<RedditPost>, universe: Set<String>, now: Instant, window: Duration = Duration.ofHours(24)): List<RedditTickerStats> {
        val start = now.minus(window)
        val prevStart = start.minus(window)
        val tagged = posts.map { it to extractTickers(it.title + " " + it.body, universe) }
        return universe.mapNotNull { sym ->
            val cur = tagged.filter { (p, t) -> sym in t && p.createdAt.isAfter(start) && !p.createdAt.isAfter(now) }.map { it.first }
            val prev = tagged.filter { (p, t) -> sym in t && p.createdAt.isAfter(prevStart) && !p.createdAt.isAfter(start) }.map { it.first }
            if (cur.isEmpty() && prev.isEmpty()) return@mapNotNull null
            val authors = cur.groupingBy { it.author }.eachCount()
            RedditTickerStats(
                symbol = sym, windowStart = start, windowEnd = now, mentions = cur.size, previousMentions = prev.size,
                uniqueAuthors = authors.size, totalScore = cur.sumOf { it.score }, totalComments = cur.sumOf { it.comments },
                sentiment = cur.takeIf { it.isNotEmpty() }?.map { sentiment(it.title + " " + it.body) }?.average() ?: 0.0,
                previousSentiment = prev.takeIf { it.isNotEmpty() }?.map { sentiment(it.title + " " + it.body) }?.average(),
                topAuthorShare = if (cur.isEmpty()) 0.0 else authors.values.max().toDouble() / cur.size,
                subreddits = cur.map { it.subreddit }.distinct(), samplePermalinks = cur.sortedByDescending { it.score }.take(3).map { "https://www.reddit.com${it.permalink}" },
            )
        }
    }

    fun parseListing(json: String): List<RedditPost> =
        lenientJson.parseToJsonElement(json)["data"]["children"].arr.mapNotNull { c ->
            val d = c["data"]
            RedditPost(
                d["id"].str ?: return@mapNotNull null, d["subreddit"].str ?: "", d["author"].str ?: "[deleted]",
                d["title"].str ?: "", d["selftext"].str ?: "", d["score"].lng?.toInt() ?: 0, d["num_comments"].lng?.toInt() ?: 0,
                Instant.ofEpochSecond(d["created_utc"].lng ?: return@mapNotNull null), d["permalink"].str ?: "",
            )
        }
}

/**
 * Reddit via the official OAuth API using the "installed app" grant: the user creates a personal
 * app at reddit.com/prefs/apps and enters only its client id (installed apps have no secret).
 */
class RedditProvider(
    private val http: HttpFetcher,
    private val clientId: () -> String?,
    private val deviceId: () -> String,
    private val clock: AppClock = AppClock.SYSTEM,
    private val subreddits: List<String> = listOf("wallstreetbets", "stocks", "investing", "StockMarket"),
) : SocialSentimentProvider {
    override val descriptor = ProviderCatalog.REDDIT
    private var token: Pair<String, Instant>? = null
    private val ua = "android:com.marketpilot.ai:1.0 (personal research app)"

    private suspend fun accessToken(id: String): Any {
        val now = clock.now()
        token?.let { (t, exp) -> if (exp.isAfter(now.plusSeconds(60))) return t }
        val basic = Base64.getEncoder().encodeToString("$id:".toByteArray())
        return when (val r = http.postForm(
            "https://www.reddit.com/api/v1/access_token",
            mapOf("grant_type" to "https://oauth.reddit.com/grants/installed_client", "device_id" to deviceId()),
            mapOf("Authorization" to "Basic $basic", "User-Agent" to ua),
        )) {
            is FetchResult.Failed -> r.error
            is FetchResult.Ok -> {
                val j = runCatching { lenientJson.parseToJsonElement(r.response.body) }.getOrNull()
                val t = j["access_token"].str ?: return ProviderError(ProviderErrorKind.AUTH, "Token Reddit non ottenuto: ${j["error"].str ?: "risposta inattesa"}")
                token = t to now.plusSeconds(j["expires_in"].lng ?: 3600)
                t
            }
        }
    }

    override suspend fun tickerStats(universe: Set<String>): ProviderResult<List<RedditTickerStats>> {
        val now = clock.now()
        val src = "https://oauth.reddit.com/r/${subreddits.joinToString("+")}/new"
        val id = clientId()?.takeIf { it.isNotBlank() } ?: return fail(descriptor, src, now, notConfigured(descriptor, "Client ID Reddit"))
        val t = accessToken(id)
        if (t is ProviderError) return fail(descriptor, src, now, t)
        val posts = mutableListOf<RedditPost>()
        var err: ProviderError? = null
        for (sub in subreddits) {
            var after: String? = null
            repeat(2) { // up to 200 newest posts per subreddit
                val url = "https://oauth.reddit.com/r/$sub/new?limit=100&raw_json=1" + (after?.let { "&after=$it" } ?: "")
                when (val r = http.get(url, mapOf("Authorization" to "bearer $t", "User-Agent" to ua))) {
                    is FetchResult.Failed -> { err = r.error; return@repeat }
                    is FetchResult.Ok -> {
                        val page = runCatching { RedditAnalyzer.parseListing(r.response.body) }.getOrElse { err = parseError("Listing Reddit non valido"); emptyList() }
                        posts += page
                        after = runCatching { lenientJson.parseToJsonElement(r.response.body)["data"]["after"].str }.getOrNull()
                        if (after == null || page.isEmpty() || page.minOf { it.createdAt }.isBefore(now.minus(Duration.ofHours(48)))) return@repeat
                    }
                }
            }
        }
        if (posts.isEmpty() && err != null) return fail(descriptor, src, now, err!!)
        val stats = RedditAnalyzer.stats(posts.distinctBy { it.id }, universe, now)
        val newest = posts.maxOfOrNull { it.createdAt }
        return ok(descriptor, src, stats, newest, now, if (newest != null && Duration.between(newest, now) < Duration.ofHours(2)) Freshness.DELAYED else Freshness.STALE,
            quality = com.marketpilot.core.model.DataQuality(1.0, listOf("${posts.size} post analizzati da ${subreddits.size} subreddit (ultime 48 ore).") + listOfNotNull(err?.message)))
    }
}
