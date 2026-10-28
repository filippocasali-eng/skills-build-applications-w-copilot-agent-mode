package com.marketpilot.data.providers.impl

import com.marketpilot.core.common.AppClock
import com.marketpilot.core.model.Freshness
import com.marketpilot.core.model.FundamentalsSnapshot
import com.marketpilot.core.model.InsiderTransaction
import com.marketpilot.core.model.Instrument
import com.marketpilot.core.model.InstitutionalHolding
import com.marketpilot.core.model.ProviderError
import com.marketpilot.core.model.ProviderErrorKind
import com.marketpilot.core.model.ProviderResult
import com.marketpilot.core.network.FetchResult
import com.marketpilot.core.network.HttpFetcher
import com.marketpilot.data.providers.FundamentalsProvider
import com.marketpilot.data.providers.InsiderDataProvider
import com.marketpilot.data.providers.InstitutionalDataProvider
import com.marketpilot.data.providers.ProviderCatalog
import kotlinx.coroutines.CancellationException
import java.time.LocalDate

/** Well-known 13F filers tracked by default (CIKs verified against SEC submissions on 2026-10-28). */
object TrackedManagers {
    val DEFAULT: Map<String, String> = linkedMapOf(
        "1067983" to "Berkshire Hathaway",
        "1336528" to "Pershing Square Capital Management",
        "1649339" to "Scion Asset Management",
        "1656456" to "Appaloosa LP",
        "1040273" to "Third Point LLC",
        "1079114" to "Greenlight Capital",
        "1061768" to "Baupost Group",
        "1536411" to "Duquesne Family Office",
    )
    fun dataromaUrl(name: String) = "https://www.dataroma.com/m/home.php"
}

/**
 * SEC EDGAR (official, free). Follows the SEC fair-access policy: declared User-Agent and request
 * spacing enforced by [HttpFetcher]'s host limiter.
 */
class SecEdgarProvider(
    private val http: HttpFetcher,
    private val contact: () -> String?,
    private val clock: AppClock = AppClock.SYSTEM,
    private val tickerEntries: suspend () -> List<TickerMapParser.Entry> = { emptyList() },
) : InsiderDataProvider, InstitutionalDataProvider, FundamentalsProvider {
    override val descriptor = ProviderCatalog.SEC

    private fun headers(): Map<String, String> {
        val c = contact()?.takeIf { it.isNotBlank() } ?: "contatto non fornito"
        return mapOf("User-Agent" to "MarketPilotAI/1.0 (app Android personale; $c)", "Accept-Encoding" to "gzip, deflate")
    }

    private suspend fun text(url: String): Pair<String?, ProviderError?> = when (val r = http.get(url, headers())) {
        is FetchResult.Ok -> r.response.body to null
        is FetchResult.Failed -> null to r.error
    }

    suspend fun tickerMap(): ProviderResult<List<TickerMapParser.Entry>> {
        val url = "https://www.sec.gov/files/company_tickers.json"
        val now = clock.now()
        val (body, err) = text(url)
        if (body == null) return fail(descriptor, url, now, err!!)
        val entries = runCatching { TickerMapParser.parse(body) }.getOrElse { return fail(descriptor, url, now, parseError("company_tickers.json non valido")) }
        return ok(descriptor, url, entries, now, now, Freshness.END_OF_DAY)
    }

    private suspend fun cikFor(instrument: Instrument): String? =
        instrument.cik ?: tickerEntries().firstOrNull { it.ticker == instrument.symbol.uppercase() || it.ticker == instrument.symbol.replace('.', '-').uppercase() }?.cik

    private fun archive(cik: String, accession: String, file: String) =
        "https://www.sec.gov/Archives/edgar/data/${cik.trimStart('0')}/${accession.replace("-", "")}/$file"

    override suspend fun insiderTransactions(instrument: Instrument, since: LocalDate): ProviderResult<List<InsiderTransaction>> =
        insiderTransactions(instrument, since, emptySet(), maxFilings = 20)

    /** Fetches Form 4 filings filed since [since], skipping accessions already stored locally. */
    suspend fun insiderTransactions(instrument: Instrument, since: LocalDate, knownAccessions: Set<String>, maxFilings: Int): ProviderResult<List<InsiderTransaction>> {
        val now = clock.now()
        val cik = cikFor(instrument) ?: return fail(descriptor, "sec:cik:${instrument.symbol}", now, ProviderError(ProviderErrorKind.UNSUPPORTED, "CIK SEC non trovato per ${instrument.symbol}"), instrument.id)
        val subUrl = "https://data.sec.gov/submissions/CIK${cik.padStart(10, '0')}.json"
        val (body, err) = text(subUrl)
        if (body == null) return fail(descriptor, subUrl, now, err!!, instrument.id)
        val filings = runCatching { SubmissionsParser.parse(body).second }.getOrElse { return fail(descriptor, subUrl, now, parseError("Submissions SEC non valide"), instrument.id) }
            .filter { it.form == "4" && !it.filingDate.isBefore(since) && it.accession !in knownAccessions }
            .take(maxFilings)
        val out = mutableListOf<InsiderTransaction>()
        var failures = 0
        for (f in filings) {
            val raw = f.primaryDocument.substringAfterLast('/')
            val url = archive(cik, f.accession, raw)
            val (xml, e) = text(url)
            if (xml == null) { failures++; continue }
            try {
                out += Form4Parser.parse(xml, f.accession, f.filingDate, url)
            } catch (c: CancellationException) {
                throw c
            } catch (_: Exception) {
                failures++
            }
        }
        val warnings = buildList {
            add("I Form 4 vengono depositati fino a 2 giorni lavorativi dopo l'operazione.")
            if (failures > 0) add("$failures filing non leggibili")
        }
        return ok(descriptor, subUrl, out.toList(), out.maxOfOrNull { it.filingDate }?.atStartOfDay(java.time.ZoneOffset.UTC)?.toInstant(), now,
            Freshness.END_OF_DAY, instrumentId = instrument.id,
            quality = com.marketpilot.core.model.DataQuality(if (filings.isEmpty()) 1.0 else 1.0 - failures.toDouble() / filings.size, warnings))
    }

    /** Market-wide: most recent Form 4 filings from the SEC current-filings feed. */
    suspend fun latestForm4(maxFilings: Int, knownAccessions: Set<String>): ProviderResult<List<InsiderTransaction>> {
        val now = clock.now()
        val feed = "https://www.sec.gov/cgi-bin/browse-edgar?action=getcurrent&type=4&count=100&output=atom"
        val (body, err) = text(feed)
        if (body == null) return fail(descriptor, feed, now, err!!)
        val entries = runCatching { SecAtomParser.parse(body) }.getOrElse { return fail(descriptor, feed, now, parseError("Feed Atom SEC non valido")) }
            .filter { it.role == "Issuer" && it.accession !in knownAccessions }
            .distinctBy { it.accession }
            .take(maxFilings)
        val out = mutableListOf<InsiderTransaction>()
        for (e in entries) {
            val folder = e.indexUrl.substringBeforeLast('/')
            val (idx, _) = text("$folder/index.json")
            val xmlName = idx?.let { j ->
                runCatching { lenientJson.parseToJsonElement(j)["directory"]["item"].arr.mapNotNull { it["name"].str } }.getOrNull()
                    ?.firstOrNull { it.endsWith(".xml", true) }
            } ?: continue
            val url = "$folder/$xmlName"
            val (xml, _) = text(url)
            xml ?: continue
            runCatching { Form4Parser.parse(xml, e.accession, e.filed ?: now.atZone(java.time.ZoneOffset.UTC).toLocalDate(), url) }
                .onSuccess { out += it }
        }
        return ok(descriptor, feed, out.toList(), now, now, Freshness.END_OF_DAY)
    }

    override suspend fun holdings(managerCik: String): ProviderResult<List<InstitutionalHolding>> {
        val now = clock.now()
        val cik = managerCik.trimStart('0')
        val subUrl = "https://data.sec.gov/submissions/CIK${cik.padStart(10, '0')}.json"
        val (body, err) = text(subUrl)
        if (body == null) return fail(descriptor, subUrl, now, err!!)
        val (root, filings) = runCatching { SubmissionsParser.parse(body) }.getOrElse { return fail(descriptor, subUrl, now, parseError("Submissions non valide")) }
        val managerName = root["name"].str ?: cik
        val thirteenF = filings.filter { it.form == "13F-HR" }.sortedByDescending { it.reportDate ?: it.filingDate }.distinctBy { it.reportDate }.take(2)
        if (thirteenF.isEmpty()) return fail(descriptor, subUrl, now, ProviderError(ProviderErrorKind.EMPTY, "Nessun 13F-HR per $managerName"))
        suspend fun table(f: Filing): List<InfoTableLine>? {
            val (idx, _) = text(archive(cik, f.accession, "index.json"))
            val name = idx?.let { j ->
                runCatching { lenientJson.parseToJsonElement(j)["directory"]["item"].arr.mapNotNull { it["name"].str } }.getOrNull()
                    ?.firstOrNull { it.endsWith(".xml", true) && !it.equals("primary_doc.xml", true) }
            } ?: return null
            val (xml, _) = text(archive(cik, f.accession, name))
            return xml?.let { runCatching { ThirteenFParser.parse(it) }.getOrNull() }
        }
        val latest = table(thirteenF[0]) ?: return fail(descriptor, subUrl, now, parseError("Tabella 13F non leggibile"))
        val previous = thirteenF.getOrNull(1)?.let { table(it) }
        val prevByCusip = previous?.associateBy { it.cusip + "|" + (it.putCall ?: "") }
        val entries = tickerEntries()
        val f0 = thirteenF[0]
        val filingUrl = archive(cik, f0.accession, "")
        val current = latest.map { l ->
            InstitutionalHolding(
                managerCik = cik, managerName = managerName, accessionNumber = f0.accession,
                periodOfReport = f0.reportDate ?: f0.filingDate, filingDate = f0.filingDate, issuerName = l.issuer, cusip = l.cusip,
                symbol = TickerMapParser.resolve(l.issuer, entries), valueUsd = l.valueUsd, shares = l.shares,
                previousShares = prevByCusip?.let { it[l.cusip + "|" + (l.putCall ?: "")]?.shares ?: 0.0 }, putCall = l.putCall, filingUrl = filingUrl,
            )
        }
        val soldOut = prevByCusip?.values?.filter { p -> latest.none { it.cusip == p.cusip && it.putCall == p.putCall } }?.map { p ->
            InstitutionalHolding(cik, managerName, f0.accession, f0.reportDate ?: f0.filingDate, f0.filingDate, p.issuer, p.cusip,
                TickerMapParser.resolve(p.issuer, entries), 0.0, 0.0, p.shares, p.putCall, filingUrl)
        } ?: emptyList()
        return ok(
            descriptor, subUrl, current + soldOut, (f0.reportDate ?: f0.filingDate).atStartOfDay(java.time.ZoneOffset.UTC).toInstant(), now, Freshness.STALE,
            quality = com.marketpilot.core.model.DataQuality(
                1.0,
                listOf("Dati 13F trimestrali: riferiti al ${f0.reportDate}, depositati il ${f0.filingDate} (fino a 45 giorni dopo la fine del trimestre). Non sono operazioni in tempo reale.") +
                    if (previous == null) listOf("Filing precedente non disponibile: variazioni non calcolabili.") else emptyList(),
            ),
        )
    }

    override suspend fun fundamentals(instrument: Instrument): ProviderResult<FundamentalsSnapshot> {
        val now = clock.now()
        val cik = cikFor(instrument) ?: return fail(descriptor, "sec:cik:${instrument.symbol}", now, ProviderError(ProviderErrorKind.UNSUPPORTED, "CIK SEC non trovato per ${instrument.symbol}"), instrument.id)
        val padded = cik.padStart(10, '0')
        val subUrl = "https://data.sec.gov/submissions/CIK$padded.json"
        val sic = text(subUrl).first?.let { runCatching { SubmissionsParser.parse(it).first["sicDescription"].str }.getOrNull() }
        val url = "https://data.sec.gov/api/xbrl/companyfacts/CIK$padded.json"
        val (body, err) = text(url)
        if (body == null) return fail(descriptor, url, now, err!!, instrument.id)
        val snap = runCatching { CompanyFactsParser.parse(body, instrument.symbol, cik, sic, url) }.getOrNull()
            ?: return fail(descriptor, url, now, parseError("Dati XBRL annuali non trovati"), instrument.id)
        return ok(descriptor, url, snap, snap.fiscalPeriodEnd?.atStartOfDay(java.time.ZoneOffset.UTC)?.toInstant(), now, Freshness.STALE, "USD", instrument.id,
            com.marketpilot.core.model.DataQuality(1.0, listOf("Fondamentali dall'ultimo bilancio annuale 10-K depositato alla SEC.")))
    }
}
