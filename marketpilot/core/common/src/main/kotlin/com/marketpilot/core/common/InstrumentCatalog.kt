package com.marketpilot.core.common

import com.marketpilot.core.model.AssetClass
import com.marketpilot.core.model.DistributionPolicy
import com.marketpilot.core.model.Domicile
import com.marketpilot.core.model.Instrument
import com.marketpilot.core.model.InstrumentRole

/**
 * Canonical instrument catalog. Contains identity data only (tickers, ISIN, listing, currency);
 * prices always come from providers. TER values are left null unless verified from the KID/
 * factsheet: the UI shows "verifica sul KID" instead of guessing.
 *
 * Note for EU retail investors: US-domiciled ETFs (SPY, QQQ) are used only as market benchmarks.
 * They are generally not purchasable by EU retail investors (no PRIIPs KID) and are never offered
 * as ETF Radar purchase candidates.
 */
object InstrumentCatalog {
    const val YAHOO = "yahoo"
    const val ALPHA_VANTAGE = "alphavantage"
    const val FINNHUB = "finnhub"

    const val SPY = "SPY:NYSEARCA"
    const val QQQ = "QQQ:NASDAQ"
    const val VWCE = "VWCE:XETRA"
    const val SP500_INDEX = "SPX:INDEX_US"
    const val NDX_INDEX = "NDX:INDEX_US"

    private fun usEtf(symbol: String, name: String, exchange: String, isin: String?, index: String?, roles: Set<InstrumentRole>, family: String? = null) =
        Instrument(
            id = "$symbol:$exchange", symbol = symbol, name = name, assetClass = AssetClass.ETF, exchange = exchange,
            currency = "USD", isin = isin, trackedIndex = index, isUcits = false, domicile = Domicile.US,
            distribution = DistributionPolicy.DISTRIBUTING,
            providerSymbols = mapOf(YAHOO to symbol, ALPHA_VANTAGE to symbol, FINNHUB to symbol),
            roles = roles, exposureFamily = family,
        )

    private fun ucits(
        symbol: String, name: String, exchange: String, currency: String, isin: String, index: String,
        distribution: DistributionPolicy, yahoo: String, family: String, domicile: Domicile = Domicile.IE,
    ) = Instrument(
        id = "$symbol:$exchange", symbol = symbol, name = name, assetClass = AssetClass.ETF, exchange = exchange,
        currency = currency, isin = isin, trackedIndex = index, isUcits = true, domicile = domicile,
        distribution = distribution, providerSymbols = mapOf(YAHOO to yahoo), roles = setOf(InstrumentRole.ETF_RADAR),
        exposureFamily = family,
    )

    val benchmarks: List<Instrument> = listOf(
        usEtf("SPY", "SPDR S&P 500 ETF Trust", "NYSEARCA", "US78462F1030", "S&P 500", setOf(InstrumentRole.MARKET_BENCHMARK), "US_LARGE_CAP"),
        usEtf("QQQ", "Invesco QQQ Trust", "NASDAQ", "US46090E1038", "Nasdaq-100", setOf(InstrumentRole.MARKET_BENCHMARK), "US_LARGE_CAP_GROWTH"),
        Instrument(
            id = SP500_INDEX, symbol = "SPX", name = "S&P 500 Index", assetClass = AssetClass.INDEX, exchange = "INDEX_US",
            currency = "USD", providerSymbols = mapOf(YAHOO to "^GSPC"), roles = setOf(InstrumentRole.MARKET_BENCHMARK),
        ),
        Instrument(
            id = NDX_INDEX, symbol = "NDX", name = "Nasdaq-100 Index", assetClass = AssetClass.INDEX, exchange = "INDEX_US",
            currency = "USD", providerSymbols = mapOf(YAHOO to "^NDX"), roles = setOf(InstrumentRole.MARKET_BENCHMARK),
        ),
    )

    val ucitsEtfs: List<Instrument> = listOf(
        ucits("VWCE", "Vanguard FTSE All-World UCITS ETF (USD) Accumulating", "XETRA", "EUR", "IE00BK5BQT80", "FTSE All-World", DistributionPolicy.ACCUMULATING, "VWCE.DE", "GLOBAL_ALL_CAP"),
        ucits("VGWL", "Vanguard FTSE All-World UCITS ETF (USD) Distributing", "XETRA", "EUR", "IE00B3RBWM25", "FTSE All-World", DistributionPolicy.DISTRIBUTING, "VGWL.DE", "GLOBAL_ALL_CAP"),
        ucits("EUNL", "iShares Core MSCI World UCITS ETF USD (Acc)", "XETRA", "EUR", "IE00B4L5Y983", "MSCI World", DistributionPolicy.ACCUMULATING, "EUNL.DE", "GLOBAL_DEVELOPED"),
        ucits("SXR8", "iShares Core S&P 500 UCITS ETF USD (Acc)", "XETRA", "EUR", "IE00B5BMR087", "S&P 500", DistributionPolicy.ACCUMULATING, "SXR8.DE", "US_LARGE_CAP"),
        ucits("VUAA", "Vanguard S&P 500 UCITS ETF (USD) Accumulating", "XETRA", "EUR", "IE00BFMXXD54", "S&P 500", DistributionPolicy.ACCUMULATING, "VUAA.DE", "US_LARGE_CAP"),
        ucits("CSPX", "iShares Core S&P 500 UCITS ETF USD (Acc)", "LSE", "USD", "IE00B5BMR087", "S&P 500", DistributionPolicy.ACCUMULATING, "CSPX.L", "US_LARGE_CAP"),
        ucits("SXRV", "iShares Nasdaq 100 UCITS ETF (Acc)", "XETRA", "EUR", "IE00B53SZB19", "Nasdaq-100", DistributionPolicy.ACCUMULATING, "SXRV.DE", "US_LARGE_CAP_GROWTH"),
    )

    val sectorEtfs: List<Instrument> = listOf(
        "XLK" to "Technology", "XLF" to "Financials", "XLE" to "Energy", "XLV" to "Health Care",
        "XLY" to "Consumer Discretionary", "XLP" to "Consumer Staples", "XLI" to "Industrials",
        "XLU" to "Utilities", "XLB" to "Materials", "XLRE" to "Real Estate", "XLC" to "Communication Services",
    ).map { (s, sector) ->
        usEtf(s, "Select Sector SPDR - $sector", "NYSEARCA", null, "S&P 500 $sector", setOf(InstrumentRole.SECTOR)).copy(sector = sector)
    }

    /** Liquid US large caps ranked by Top Trade USA (users can add more from the watchlist). */
    val stockUniverse: List<Instrument> = listOf(
        "AAPL" to "Apple Inc.", "MSFT" to "Microsoft Corp.", "NVDA" to "NVIDIA Corp.", "AMZN" to "Amazon.com Inc.",
        "GOOGL" to "Alphabet Inc. (Class A)", "META" to "Meta Platforms Inc.", "TSLA" to "Tesla Inc.",
        "AVGO" to "Broadcom Inc.", "JPM" to "JPMorgan Chase & Co.", "V" to "Visa Inc.", "MA" to "Mastercard Inc.",
        "UNH" to "UnitedHealth Group Inc.", "LLY" to "Eli Lilly and Co.", "XOM" to "Exxon Mobil Corp.",
        "JNJ" to "Johnson & Johnson", "PG" to "Procter & Gamble Co.", "HD" to "Home Depot Inc.",
        "COST" to "Costco Wholesale Corp.", "NFLX" to "Netflix Inc.", "AMD" to "Advanced Micro Devices Inc.",
        "ORCL" to "Oracle Corp.", "CRM" to "Salesforce Inc.", "ADBE" to "Adobe Inc.", "PEP" to "PepsiCo Inc.",
        "KO" to "Coca-Cola Co.", "WMT" to "Walmart Inc.", "BAC" to "Bank of America Corp.", "MRK" to "Merck & Co. Inc.",
        "ABBV" to "AbbVie Inc.", "CVX" to "Chevron Corp.", "TMO" to "Thermo Fisher Scientific Inc.",
        "CSCO" to "Cisco Systems Inc.", "INTC" to "Intel Corp.", "QCOM" to "Qualcomm Inc.", "TXN" to "Texas Instruments Inc.",
        "AMAT" to "Applied Materials Inc.", "MU" to "Micron Technology Inc.", "PLTR" to "Palantir Technologies Inc.",
        "UBER" to "Uber Technologies Inc.", "DIS" to "Walt Disney Co.", "NKE" to "Nike Inc.", "CAT" to "Caterpillar Inc.",
        "GE" to "GE Aerospace", "IBM" to "International Business Machines Corp.", "GS" to "Goldman Sachs Group Inc.",
        "PYPL" to "PayPal Holdings Inc.", "SBUX" to "Starbucks Corp.",
    ).map { (s, name) -> stock(s, name) }

    /** US-listed common stock (NYSE or Nasdaq; both follow the NYSE calendar). */
    fun stock(symbol: String, name: String): Instrument {
        val clean = symbol.trim().uppercase()
        return Instrument(
            id = stockId(clean), symbol = clean, name = name, assetClass = AssetClass.STOCK, exchange = "US",
            currency = "USD", providerSymbols = mapOf(YAHOO to clean.replace('.', '-'), ALPHA_VANTAGE to clean, FINNHUB to clean),
            roles = setOf(InstrumentRole.STOCK_UNIVERSE),
        )
    }

    val all: List<Instrument> by lazy { benchmarks + ucitsEtfs + sectorEtfs + stockUniverse }

    fun byId(id: String): Instrument? = all.firstOrNull { it.id == id }

    fun stockId(symbol: String) = "${symbol.trim().uppercase()}:US"
}
