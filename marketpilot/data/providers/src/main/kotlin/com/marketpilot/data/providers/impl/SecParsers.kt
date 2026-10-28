package com.marketpilot.data.providers.impl

import com.marketpilot.core.model.FundamentalsSnapshot
import com.marketpilot.core.model.InsiderTransaction
import com.marketpilot.core.model.InsiderTransactionType
import kotlinx.serialization.json.JsonElement
import kotlinx.serialization.json.JsonObject
import java.time.LocalDate
import java.time.temporal.ChronoUnit

/** Parser for SEC ownership documents (Forms 3/4/5 XML). Derivative transactions are not included. */
object Form4Parser {
    fun parse(xml: String, accession: String, filingDate: LocalDate, filingUrl: String): List<InsiderTransaction> {
        val doc = SafeXml.parse(xml).documentElement
        val issuer = doc.child("issuer")
        val issuerCik = issuer.valueOf("issuerCik")?.trimStart('0') ?: ""
        // Some filers write the exchange prefix ("NYSE:FLG"): keep the ticker only.
        val symbol = issuer.valueOf("issuerTradingSymbol")?.uppercase()?.substringAfterLast(':')?.trim() ?: ""
        val owners = doc.children("reportingOwner")
        val owner = owners.firstOrNull()
        val name = owners.mapNotNull { it.child("reportingOwnerId").valueOf("rptOwnerName") }.joinToString(" / ").ifBlank { "n/d" }
        val rel = owner?.child("reportingOwnerRelationship")
        fun flag(tag: String) = rel.valueOf(tag)?.let { it == "1" || it.equals("true", true) } ?: false
        val isDirector = flag("isDirector")
        val isOfficer = flag("isOfficer")
        val isTen = flag("isTenPercentOwner")
        val title = rel.valueOf("officerTitle")
        val role = buildList {
            if (isOfficer) add(title ?: "Officer")
            if (isDirector) add("Director")
            if (isTen) add("10% Owner")
            if (isEmpty()) add(rel.valueOf("otherText") ?: "Altro")
        }.joinToString(", ")
        val docLevelPlan = doc.valueOf("aff10b5One")?.let { it == "1" || it.equals("true", true) } ?: false
        val footnotes = doc.child("footnotes")?.children("footnote")?.associate { (it.getAttribute("id") ?: "") to (it.textContent ?: "") } ?: emptyMap()

        val table = doc.child("nonDerivativeTable") ?: return emptyList()
        return table.children("nonDerivativeTransaction").mapNotNull { t ->
            val code = t.child("transactionCoding").valueOf("transactionCode") ?: return@mapNotNull null
            val date = t.valueOf("transactionDate")?.let { runCatching { LocalDate.parse(it.take(10)) }.getOrNull() } ?: return@mapNotNull null
            val amounts = t.child("transactionAmounts")
            val shares = amounts.valueOf("transactionShares")?.toDoubleOrNull() ?: return@mapNotNull null
            val price = amounts.valueOf("transactionPricePerShare")?.toDoubleOrNull()
            val ad = amounts.valueOf("transactionAcquiredDisposedCode") ?: ""
            val after = t.child("postTransactionAmounts").valueOf("sharesOwnedFollowingTransaction")?.toDoubleOrNull()
            val ownership = t.child("ownershipNature").valueOf("directOrIndirectOwnership") ?: ""
            val referenced = t.getElementsByTagName("footnoteId").let { nl -> (0 until nl.length).map { (nl.item(it) as org.w3c.dom.Element).getAttribute("id") } }
            val planFootnote = referenced.any { footnotes[it]?.contains("10b5-1", ignoreCase = true) == true }
            InsiderTransaction(
                accessionNumber = accession, issuerCik = issuerCik, issuerSymbol = symbol, insiderName = name, insiderRole = role,
                isDirector = isDirector, isOfficer = isOfficer, isTenPercentOwner = isTen, filingDate = filingDate, transactionDate = date,
                transactionCode = code, type = InsiderTransactionType.fromCode(code), shares = shares, pricePerShare = price?.takeIf { it > 0 },
                acquiredDisposed = ad, ownershipType = ownership, sharesOwnedAfter = after, isRule10b51Plan = docLevelPlan || planFootnote,
                filingUrl = filingUrl,
            )
        }
    }
}

data class InfoTableLine(val issuer: String, val cusip: String, val titleOfClass: String, val valueUsd: Double, val shares: Double, val putCall: String?)

object ThirteenFParser {
    /** Aggregates lines by CUSIP (+put/call); options lines are kept separate. */
    fun parse(xml: String): List<InfoTableLine> {
        val root = SafeXml.parse(xml).documentElement
        val lines = root.descendants("infoTable").mapNotNull { e ->
            val cusip = e.child("cusip").text() ?: return@mapNotNull null
            val type = e.child("shrsOrPrnAmt")?.child("sshPrnamtType").text()
            if (type != null && type != "SH") return@mapNotNull null
            InfoTableLine(
                e.child("nameOfIssuer").text() ?: "", cusip, e.child("titleOfClass").text() ?: "",
                e.child("value").text()?.toDoubleOrNull() ?: 0.0,
                e.child("shrsOrPrnAmt")?.child("sshPrnamt").text()?.toDoubleOrNull() ?: 0.0,
                e.child("putCall").text(),
            )
        }
        return lines.groupBy { it.cusip + "|" + (it.putCall ?: "") }.map { (_, g) ->
            g.first().copy(valueUsd = g.sumOf { it.valueUsd }, shares = g.sumOf { it.shares })
        }
    }
}

data class Filing(val accession: String, val form: String, val filingDate: LocalDate, val reportDate: LocalDate?, val primaryDocument: String)

object SubmissionsParser {
    fun parse(json: String): Pair<JsonObject, List<Filing>> {
        val root = lenientJson.parseToJsonElement(json) as JsonObject
        val r = root["filings"]["recent"]
        val acc = r["accessionNumber"].arr
        val form = r["form"].arr
        val fd = r["filingDate"].arr
        val rd = r["reportDate"].arr
        val pd = r["primaryDocument"].arr
        val filings = acc.indices.mapNotNull { i ->
            val date = fd.getOrNull(i).str?.let { runCatching { LocalDate.parse(it) }.getOrNull() } ?: return@mapNotNull null
            Filing(
                acc[i].str ?: return@mapNotNull null, form.getOrNull(i).str ?: "", date,
                rd.getOrNull(i).str?.takeIf { it.isNotBlank() }?.let { runCatching { LocalDate.parse(it) }.getOrNull() }, pd.getOrNull(i).str ?: "",
            )
        }
        return root to filings
    }
}

object TickerMapParser {
    data class Entry(val cik: String, val ticker: String, val title: String)

    fun parse(json: String): List<Entry> {
        val root = lenientJson.parseToJsonElement(json) as JsonObject
        return root.values.mapNotNull { v ->
            val cik = v["cik_str"].lng?.toString() ?: return@mapNotNull null
            Entry(cik, v["ticker"].str?.uppercase() ?: return@mapNotNull null, v["title"].str ?: "")
        }
    }

    private val noise = Regex("\\b(INC|CORP|CORPORATION|CO|COMPANY|LTD|PLC|HOLDINGS?|GROUP|THE|DEL|NEW|COM|CL [A-C]|CLASS [A-C]|N V|NV|SA|AG)\\b")

    fun normalizeName(name: String): String =
        name.uppercase().replace('&', ' ').replace(Regex("[^A-Z0-9 ]"), " ").replace(noise, " ").replace(Regex("\\s+"), " ").trim()

    /** Best-effort issuer name -> ticker resolution for 13F lines (13F reports CUSIPs, not tickers). */
    fun resolve(issuerName: String, entries: List<Entry>): String? {
        val target = normalizeName(issuerName)
        if (target.isBlank()) return null
        val exact = entries.filter { normalizeName(it.title) == target }
        if (exact.isNotEmpty()) return exact.minByOrNull { it.ticker.length }!!.ticker
        val prefix = entries.filter { val n = normalizeName(it.title); n.startsWith(target) || target.startsWith(n) && n.length >= 4 }
        return prefix.takeIf { it.size == 1 }?.first()?.ticker
    }
}

/** Extracts annual fundamentals from SEC XBRL companyfacts (latest 10-K fiscal year). */
object CompanyFactsParser {
    private data class Fact(val start: LocalDate?, val end: LocalDate, val value: Double, val form: String, val fp: String?, val filed: LocalDate?)

    private fun facts(root: JsonElement, taxonomy: String, tag: String, unit: String): List<Fact> =
        root["facts"][taxonomy][tag]["units"][unit].arr.mapNotNull { f ->
            val end = f["end"].str?.let { runCatching { LocalDate.parse(it) }.getOrNull() } ?: return@mapNotNull null
            Fact(
                f["start"].str?.let { runCatching { LocalDate.parse(it) }.getOrNull() }, end, f["val"].dbl ?: return@mapNotNull null,
                f["form"].str ?: "", f["fp"].str, f["filed"].str?.let { runCatching { LocalDate.parse(it) }.getOrNull() },
            )
        }

    private fun annual(list: List<Fact>): List<Fact> = list.filter {
        (it.form == "10-K" || it.form == "20-F" || it.form == "10-K/A") &&
            (it.start == null || ChronoUnit.DAYS.between(it.start, it.end) in 340..380)
    }.groupBy { it.end }.map { (_, g) -> g.maxByOrNull { it.filed ?: LocalDate.MIN }!! }.sortedBy { it.end }

    private fun latestAnnual(root: JsonElement, tags: List<String>, unit: String = "USD"): List<Fact> {
        val all = tags.flatMap { annual(facts(root, "us-gaap", it, unit)) }
        return all.groupBy { it.end }.map { it.value.first() }.sortedBy { it.end }
    }

    fun parse(json: String, symbol: String, cik: String, sicDescription: String?, sourceUrl: String): FundamentalsSnapshot? {
        val root = lenientJson.parseToJsonElement(json)
        val revenue = latestAnnual(root, listOf("RevenueFromContractWithCustomerExcludingAssessedTax", "Revenues", "SalesRevenueNet", "RevenueFromContractWithCustomerIncludingAssessedTax"))
        val net = latestAnnual(root, listOf("NetIncomeLoss"))
        val anchor = (revenue.lastOrNull() ?: net.lastOrNull())?.end ?: return null
        fun at(list: List<Fact>, end: LocalDate) = list.firstOrNull { kotlin.math.abs(ChronoUnit.DAYS.between(it.end, end)) <= 10 }?.value
        val prevEnd = anchor.minusYears(1)
        val shares = facts(root, "dei", "EntityCommonStockSharesOutstanding", "shares").maxByOrNull { it.end }?.value
        return FundamentalsSnapshot(
            symbol = symbol, cik = cik, currency = "USD", fiscalPeriodEnd = anchor,
            revenue = at(revenue, anchor), revenuePrevious = at(revenue, prevEnd),
            netIncome = at(net, anchor),
            operatingIncome = at(latestAnnual(root, listOf("OperatingIncomeLoss")), anchor),
            operatingCashFlow = at(latestAnnual(root, listOf("NetCashProvidedByUsedInOperatingActivities")), anchor),
            capitalExpenditure = at(latestAnnual(root, listOf("PaymentsToAcquirePropertyPlantAndEquipment")), anchor),
            totalDebt = at(latestAnnual(root, listOf("LongTermDebt", "LongTermDebtNoncurrent")), anchor),
            stockholdersEquity = at(latestAnnual(root, listOf("StockholdersEquity")), anchor),
            sharesOutstanding = shares,
            epsDiluted = at(latestAnnual(root, listOf("EarningsPerShareDiluted"), "USD/shares"), anchor),
            sicDescription = sicDescription, sourceUrl = sourceUrl,
        )
    }
}

/** Entries of the SEC "current filings" Atom feed. */
object SecAtomParser {
    data class Entry(val title: String, val indexUrl: String, val accession: String, val filed: LocalDate?, val role: String)

    fun parse(xml: String): List<Entry> {
        val root = SafeXml.parse(xml).documentElement
        return root.children("entry").mapNotNull { e ->
            val title = e.child("title").text() ?: return@mapNotNull null
            val link = e.child("link")?.getAttribute("href") ?: return@mapNotNull null
            val acc = e.child("id").text()?.substringAfter("accession-number=") ?: return@mapNotNull null
            val filed = Regex("Filed:</b> (\\d{4}-\\d{2}-\\d{2})").find(e.child("summary")?.textContent ?: "")?.groupValues?.get(1)?.let(LocalDate::parse)
            Entry(title, link, acc, filed, if (title.endsWith("(Issuer)")) "Issuer" else "Reporting")
        }
    }
}
