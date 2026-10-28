package com.marketpilot.data.providers.impl

import com.marketpilot.core.common.AppClock
import com.marketpilot.core.model.Freshness
import com.marketpilot.core.model.FxRate
import com.marketpilot.core.model.MacroObservation
import com.marketpilot.core.model.ProviderError
import com.marketpilot.core.model.ProviderErrorKind
import com.marketpilot.core.model.ProviderResult
import com.marketpilot.core.network.FetchResult
import com.marketpilot.core.network.HttpFetcher
import com.marketpilot.data.providers.FxDataProvider
import com.marketpilot.data.providers.MacroDataProvider
import com.marketpilot.data.providers.ProviderCatalog
import java.time.LocalDate
import java.time.format.DateTimeFormatter
import java.time.ZoneOffset

object MacroParsers {
    /** FRED fredgraph.csv: "observation_date,SERIES" with "." for missing values. */
    fun fredCsv(csv: String, seriesId: String): List<MacroObservation> = csv.lineSequence().drop(1).mapNotNull { line ->
        val p = line.split(',')
        if (p.size < 2) return@mapNotNull null
        val d = runCatching { LocalDate.parse(p[0].trim()) }.getOrNull() ?: return@mapNotNull null
        val v = p[1].trim().toDoubleOrNull() ?: return@mapNotNull null
        MacroObservation(seriesId, d, v)
    }.toList()

    private val mdy = DateTimeFormatter.ofPattern("MM/dd/yyyy")

    /** Cboe VIX_History.csv: DATE (MM/DD/YYYY),OPEN,HIGH,LOW,CLOSE */
    fun cboeVix(csv: String): List<MacroObservation> = csv.lineSequence().drop(1).mapNotNull { line ->
        val p = line.split(',')
        if (p.size < 5) return@mapNotNull null
        val d = runCatching { LocalDate.parse(p[0].trim(), mdy) }.getOrNull() ?: return@mapNotNull null
        MacroObservation("VIX", d, p[4].trim().toDoubleOrNull() ?: return@mapNotNull null)
    }.toList()

    /** ECB eurofxref XML (daily or 90-day history). */
    fun ecbXml(xml: String, currencies: Set<String>): List<FxRate> {
        val root = SafeXml.parse(xml).documentElement
        return root.descendants("Cube").filter { it.hasAttribute("time") }.flatMap { day ->
            val date = LocalDate.parse(day.getAttribute("time"))
            day.children("Cube").mapNotNull { c ->
                val ccy = c.getAttribute("currency")
                if (ccy !in currencies) null else FxRate("EUR", ccy, date, c.getAttribute("rate").toDoubleOrNull() ?: return@mapNotNull null)
            }
        }
    }

    /** ECB full history CSV (from eurofxref-hist.zip): "Date,USD,JPY,...". */
    fun ecbHistCsv(csv: String, currencies: Set<String>, from: LocalDate): List<FxRate> {
        val lines = csv.lineSequence().filter { it.isNotBlank() }.toList()
        if (lines.isEmpty()) return emptyList()
        val header = lines.first().split(',').map { it.trim() }
        val idx = currencies.associateWith { header.indexOf(it) }.filterValues { it > 0 }
        return lines.drop(1).flatMap { line ->
            val p = line.split(',')
            val d = runCatching { LocalDate.parse(p[0].trim()) }.getOrNull() ?: return@flatMap emptyList()
            if (d.isBefore(from)) return@flatMap emptyList()
            idx.mapNotNull { (ccy, i) -> p.getOrNull(i)?.trim()?.toDoubleOrNull()?.let { FxRate("EUR", ccy, d, it) } }
        }
    }
}

class FredProvider(private val http: HttpFetcher, private val clock: AppClock = AppClock.SYSTEM) : MacroDataProvider {
    override val descriptor = ProviderCatalog.FRED

    override suspend fun series(seriesId: String, from: LocalDate): ProviderResult<List<MacroObservation>> {
        val now = clock.now()
        val url = "https://fred.stlouisfed.org/graph/fredgraph.csv?id=$seriesId&cosd=$from"
        return when (val r = http.get(url)) {
            is FetchResult.Failed -> fromFetchFailure(descriptor, url, now, r)
            is FetchResult.Ok -> {
                val obs = MacroParsers.fredCsv(r.response.body, seriesId).filter { !it.date.isBefore(from) }
                if (obs.isEmpty()) fail(descriptor, url, now, ProviderError(ProviderErrorKind.EMPTY, "Serie $seriesId vuota"))
                else ok(descriptor, url, obs, obs.last().date.atStartOfDay(ZoneOffset.UTC).toInstant(), now, Freshness.END_OF_DAY)
            }
        }
    }
}

class CboeVixProvider(private val http: HttpFetcher, private val clock: AppClock = AppClock.SYSTEM) : MacroDataProvider {
    override val descriptor = ProviderCatalog.CBOE

    override suspend fun series(seriesId: String, from: LocalDate): ProviderResult<List<MacroObservation>> {
        val now = clock.now()
        val url = "https://cdn.cboe.com/api/global/us_indices/daily_prices/VIX_History.csv"
        if (seriesId != "VIX") return fail(descriptor, url, now, ProviderError(ProviderErrorKind.UNSUPPORTED, "Solo VIX"))
        return when (val r = http.get(url)) {
            is FetchResult.Failed -> fromFetchFailure(descriptor, url, now, r)
            is FetchResult.Ok -> {
                val obs = MacroParsers.cboeVix(r.response.body).filter { !it.date.isBefore(from) }
                if (obs.isEmpty()) fail(descriptor, url, now, ProviderError(ProviderErrorKind.EMPTY, "Storico VIX vuoto"))
                else ok(descriptor, url, obs, obs.last().date.atStartOfDay(ZoneOffset.UTC).toInstant(), now, Freshness.END_OF_DAY)
            }
        }
    }
}

class EcbFxProvider(private val http: HttpFetcher, private val clock: AppClock = AppClock.SYSTEM) : FxDataProvider {
    override val descriptor = ProviderCatalog.ECB

    override suspend fun eurRates(currencies: Set<String>, from: LocalDate): ProviderResult<List<FxRate>> {
        val now = clock.now()
        val today = now.atZone(ZoneOffset.UTC).toLocalDate()
        val url = if (from.isBefore(today.minusDays(85))) "https://www.ecb.europa.eu/stats/eurofxref/eurofxref-hist.zip"
        else "https://www.ecb.europa.eu/stats/eurofxref/eurofxref-hist-90d.xml"
        if (url.endsWith(".zip")) return fullHistory(url, currencies, from)
        return when (val r = http.get(url)) {
            is FetchResult.Failed -> fromFetchFailure(descriptor, url, now, r)
            is FetchResult.Ok -> {
                val rates = runCatching { MacroParsers.ecbXml(r.response.body, currencies) }.getOrElse { return fail(descriptor, url, now, parseError("XML BCE non valido")) }
                    .filter { !it.date.isBefore(from) }
                if (rates.isEmpty()) fail(descriptor, url, now, ProviderError(ProviderErrorKind.EMPTY, "Nessun tasso BCE"))
                else ok(descriptor, url, rates, rates.maxOf { it.date }.atTime(14, 0).toInstant(ZoneOffset.UTC), now, Freshness.END_OF_DAY)
            }
        }
    }

    /** The full history is published as a zipped CSV; the zip is downloaded as bytes via a dedicated call. */
    private suspend fun fullHistory(url: String, currencies: Set<String>, from: LocalDate): ProviderResult<List<FxRate>> {
        val now = clock.now()
        val bytes = when (val r = http.getBytes(url)) {
            is HttpFetcher.BytesResult.Ok -> r.bytes
            is HttpFetcher.BytesResult.Failed -> return fail(descriptor, url, now, r.error)
        }
        val csv = runCatching {
            java.util.zip.ZipInputStream(bytes.inputStream()).use { z ->
                var entry = z.nextEntry
                var text: String? = null
                while (entry != null && text == null) {
                    if (entry.name.endsWith(".csv")) text = z.readBytes().toString(Charsets.UTF_8)
                    entry = z.nextEntry
                }
                text
            }
        }.getOrNull() ?: return fail(descriptor, url, now, parseError("Archivio BCE non leggibile"))
        val rates = MacroParsers.ecbHistCsv(csv, currencies, from)
        return if (rates.isEmpty()) fail(descriptor, url, now, ProviderError(ProviderErrorKind.EMPTY, "Nessun tasso BCE"))
        else ok(descriptor, url, rates, rates.maxOf { it.date }.atTime(14, 0).toInstant(ZoneOffset.UTC), now, Freshness.END_OF_DAY)
    }
}
