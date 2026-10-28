package com.marketpilot.data.repositories

import com.marketpilot.core.database.CandleEntity
import com.marketpilot.core.database.InsiderTransactionEntity
import com.marketpilot.core.database.InstitutionalHoldingEntity
import com.marketpilot.core.database.InstrumentEntity
import com.marketpilot.core.database.LedgerEntryEntity
import com.marketpilot.core.database.NewsEntity
import com.marketpilot.core.database.PaperFillEntity
import com.marketpilot.core.database.PaperOrderEntity
import com.marketpilot.core.database.QuoteEntity
import com.marketpilot.core.database.RedditObservationEntity
import com.marketpilot.core.model.AssetClass
import com.marketpilot.core.model.Candle
import com.marketpilot.core.model.DistributionPolicy
import com.marketpilot.core.model.Domicile
import com.marketpilot.core.model.Freshness
import com.marketpilot.core.model.InsiderTransaction
import com.marketpilot.core.model.InsiderTransactionType
import com.marketpilot.core.model.Instrument
import com.marketpilot.core.model.InstrumentRole
import com.marketpilot.core.model.InstitutionalHolding
import com.marketpilot.core.model.NewsCategory
import com.marketpilot.core.model.NewsItem
import com.marketpilot.core.model.Quote
import com.marketpilot.core.model.RedditTickerStats
import com.marketpilot.domain.papertrading.OrderRole
import com.marketpilot.domain.papertrading.OrderSide
import com.marketpilot.domain.papertrading.OrderStatus
import com.marketpilot.domain.papertrading.OrderType
import com.marketpilot.domain.papertrading.PaperFill
import com.marketpilot.domain.papertrading.PaperOrder
import com.marketpilot.domain.papertrading.TimeInForce
import com.marketpilot.domain.portfolio.AccountType
import com.marketpilot.domain.portfolio.LedgerEntry
import com.marketpilot.domain.portfolio.LedgerKind
import java.time.Instant
import java.time.LocalDate

internal fun LocalDate.day(): Long = toEpochDay()
internal fun Long.date(): LocalDate = LocalDate.ofEpochDay(this)
internal fun Instant.ms(): Long = toEpochMilli()
internal fun Long.instant(): Instant = Instant.ofEpochMilli(this)

fun Instrument.toEntity(userAdded: Boolean = false) = InstrumentEntity(
    id, symbol, name, assetClass.name, exchange, currency, isin, trackedIndex, isUcits, domicile.name, distribution.name, terPercent,
    dbJson.encodeToString(stringMapSerializer, providerSymbols), roles.joinToString(",") { it.name }, sector, cik, exposureFamily, userAdded,
)

fun InstrumentEntity.toModel() = Instrument(
    id = id, symbol = symbol, name = name, assetClass = AssetClass.valueOf(assetClass), exchange = exchange, currency = currency, isin = isin,
    trackedIndex = trackedIndex, isUcits = isUcits, domicile = Domicile.valueOf(domicile), distribution = DistributionPolicy.valueOf(distribution),
    terPercent = terPercent, providerSymbols = runCatching { dbJson.decodeFromString(stringMapSerializer, providerSymbolsJson) }.getOrDefault(emptyMap()),
    roles = rolesCsv.split(',').filter { it.isNotBlank() }.mapNotNull { runCatching { InstrumentRole.valueOf(it) }.getOrNull() }.toSet(),
    sector = sector, cik = cik, exposureFamily = exposureFamily,
)

fun Candle.toEntity(providerId: String, retrievedAt: Instant) =
    CandleEntity(instrumentId, date.day(), open, high, low, close, adjClose, volume, providerId, retrievedAt.ms())

fun CandleEntity.toModel() = Candle(instrumentId, epochDay.date(), open, high, low, close, adjClose, volume)

fun Quote.toEntity(providerId: String, sourceUrl: String, retrievedAt: Instant, freshness: Freshness) = QuoteEntity(
    instrumentId, price, currency, observedAt.ms(), previousClose, changePercent, dayHigh, dayLow, volume, fiftyTwoWeekHigh, fiftyTwoWeekLow,
    providerId, sourceUrl, retrievedAt.ms(), freshness.name,
)

data class StoredQuote(val quote: Quote, val providerId: String, val sourceUrl: String, val retrievedAt: Instant, val freshnessAtRetrieval: Freshness)

fun QuoteEntity.toModel() = StoredQuote(
    Quote(instrumentId, price, currency, observedAtMs.instant(), previousClose, changePercent, dayHigh, dayLow, volume, high52, low52),
    providerId, sourceUrl, retrievedAtMs.instant(), runCatching { Freshness.valueOf(freshness) }.getOrDefault(Freshness.UNKNOWN),
)

fun NewsItem.toEntity(retrievedAt: Instant) = NewsEntity(id, headline, publisher, publishedAt.ms(), url, relatedSymbols.joinToString(","), category.name, description, providerId, relevance, retrievedAt.ms())

fun NewsEntity.toModel() = NewsItem(
    id, headline, publisher, publishedAtMs.instant(), url, relatedCsv.split(',').filter { it.isNotBlank() },
    runCatching { NewsCategory.valueOf(category) }.getOrDefault(NewsCategory.OTHER), description, providerId, relevance,
)

fun InsiderTransaction.toEntity(index: Int, retrievedAt: Instant) = InsiderTransactionEntity(
    "$accessionNumber#$index", accessionNumber, issuerCik, issuerSymbol, insiderName, insiderRole, isDirector, isOfficer, isTenPercentOwner,
    filingDate.day(), transactionDate.day(), transactionCode, type.name, shares, pricePerShare, acquiredDisposed, ownershipType, sharesOwnedAfter,
    isRule10b51Plan, filingUrl, retrievedAt.ms(),
)

fun InsiderTransactionEntity.toModel() = InsiderTransaction(
    accessionNumber, issuerCik, issuerSymbol, insiderName, insiderRole, isDirector, isOfficer, isTenPercentOwner, filingEpochDay.date(),
    transactionEpochDay.date(), transactionCode, runCatching { InsiderTransactionType.valueOf(type) }.getOrDefault(InsiderTransactionType.OTHER),
    shares, pricePerShare, acquiredDisposed, ownershipType, sharesOwnedAfter, isRule10b51Plan, filingUrl,
)

fun InstitutionalHolding.toEntity(retrievedAt: Instant) = InstitutionalHoldingEntity(
    managerCik, managerName, accessionNumber, periodOfReport.day(), filingDate.day(), issuerName, cusip, symbol, valueUsd, shares, previousShares,
    putCall ?: "", filingUrl, retrievedAt.ms(),
)

fun InstitutionalHoldingEntity.toModel() = InstitutionalHolding(
    managerCik, managerName, accessionNumber, periodEpochDay.date(), filingEpochDay.date(), issuerName, cusip, symbol, valueUsd, shares, previousShares,
    putCall.ifBlank { null }, filingUrl,
)

fun RedditTickerStats.toEntity(retrievedAt: Instant) = RedditObservationEntity(
    symbol, windowStart.ms(), windowEnd.ms(), mentions, previousMentions, uniqueAuthors, totalScore, totalComments, sentiment, previousSentiment,
    topAuthorShare, subreddits.joinToString(","), samplePermalinks.joinToString(","), retrievedAt.ms(),
)

fun RedditObservationEntity.toModel() = RedditTickerStats(
    symbol, windowStartMs.instant(), windowEndMs.instant(), mentions, previousMentions, uniqueAuthors, totalScore, totalComments, sentiment,
    previousSentiment, topAuthorShare, subredditsCsv.split(',').filter { it.isNotBlank() }, permalinksCsv.split(',').filter { it.isNotBlank() },
)

fun LedgerEntry.toEntity() = LedgerEntryEntity(
    id, account.name, kind.name, amountEur, sessionDate.day(), createdAt.ms(), instrumentId, quantity, priceCcy, currency, fxRate, referenceId, transferId, note,
)

fun LedgerEntryEntity.toModel() = LedgerEntry(
    id, AccountType.valueOf(account), LedgerKind.valueOf(kind), amountEur, sessionEpochDay.date(), createdAtMs.instant(), instrumentId, quantity,
    priceCcy, currency, fxRate, referenceId, transferId, note,
)

fun PaperOrder.toEntity(now: Instant) = PaperOrderEntity(
    id, account.name, instrumentId, exchange, currency, side.name, type.name, quantity, filledQuantity, limitPrice, stopPrice, timeInForce.name,
    expiresOn?.day(), createdAt.ms(), firstEligibleSession.day(), status.name, role.name, parentId, ocoGroupId, bracketStopLoss, bracketTakeProfit,
    triggered, lastEvaluatedSession?.day(), statusReason, reservedCashEur, note, now.ms(),
)

fun PaperOrderEntity.toModel() = PaperOrder(
    id = id, account = AccountType.valueOf(account), instrumentId = instrumentId, exchange = exchange, currency = currency,
    side = OrderSide.valueOf(side), type = OrderType.valueOf(type), quantity = quantity, filledQuantity = filledQuantity,
    limitPrice = limitPrice, stopPrice = stopPrice, timeInForce = TimeInForce.valueOf(timeInForce), expiresOn = expiresOnEpochDay?.date(),
    createdAt = createdAtMs.instant(), firstEligibleSession = firstEligibleEpochDay.date(), status = OrderStatus.valueOf(status),
    role = OrderRole.valueOf(role), parentId = parentId, ocoGroupId = ocoGroupId, bracketStopLoss = bracketStopLoss, bracketTakeProfit = bracketTakeProfit,
    triggered = triggered, lastEvaluatedSession = lastEvaluatedEpochDay?.date(), statusReason = statusReason, reservedCashEur = reservedCashEur, note = note,
)

fun PaperFill.toEntity() = PaperFillEntity(
    id, orderId, account.name, instrumentId, side.name, session.day(), quantity, priceCcy, currency, eurToCcy, grossEur, commissionEur, fxCostEur, basis, ambiguous,
)

fun PaperFillEntity.toModel() = PaperFill(
    id, orderId, AccountType.valueOf(account), instrumentId, OrderSide.valueOf(side), sessionEpochDay.date(), quantity, priceCcy, currency, eurToCcy,
    grossEur, commissionEur, fxCostEur, basis, ambiguous,
)
