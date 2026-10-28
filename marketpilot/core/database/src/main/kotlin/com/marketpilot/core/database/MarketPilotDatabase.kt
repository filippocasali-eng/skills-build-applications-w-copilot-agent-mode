package com.marketpilot.core.database

import android.content.Context
import androidx.room.Database
import androidx.room.Room
import androidx.room.RoomDatabase

@Database(
    entities = [
        InstrumentEntity::class, CandleEntity::class, QuoteEntity::class, ProviderStatusEntity::class,
        IndicatorSnapshotEntity::class, MarketAssessmentEntity::class, EtfScoreEntity::class, StockScoreEntity::class,
        NewsEntity::class, InsiderTransactionEntity::class, InstitutionalHoldingEntity::class, RedditObservationEntity::class,
        WatchlistEntity::class, LedgerEntryEntity::class, PaperOrderEntity::class, PaperFillEntity::class,
        OpenPositionEntity::class, ClosedPositionEntity::class, AlertEntity::class, JournalEntryEntity::class,
        DecisionSnapshotEntity::class, EvaluationResultEntity::class, FxRateEntity::class, MacroObservationEntity::class,
        EarningsEventEntity::class, SecTickerEntity::class, RefreshLogEntity::class,
    ],
    version = 1,
    exportSchema = true,
)
abstract class MarketPilotDatabase : RoomDatabase() {
    abstract fun instrumentDao(): InstrumentDao
    abstract fun candleDao(): CandleDao
    abstract fun quoteDao(): QuoteDao
    abstract fun providerStatusDao(): ProviderStatusDao
    abstract fun analysisDao(): AnalysisDao
    abstract fun newsDao(): NewsDao
    abstract fun alternativeDataDao(): AlternativeDataDao
    abstract fun macroDao(): MacroDao
    abstract fun watchlistDao(): WatchlistDao
    abstract fun ledgerDao(): LedgerDao
    abstract fun paperTradingDao(): PaperTradingDao
    abstract fun alertDao(): AlertDao
    abstract fun journalDao(): JournalDao
    abstract fun decisionDao(): DecisionDao
    abstract fun refreshLogDao(): RefreshLogDao

    companion object {
        const val NAME = "marketpilot.db"

        fun build(context: Context): MarketPilotDatabase =
            Room.databaseBuilder(context, MarketPilotDatabase::class.java, NAME)
                .addMigrations(*Migrations.ALL)
                .build()
    }
}

object Migrations {
    /** Ordered list of schema migrations. Destructive fallback is intentionally NOT enabled: user data must survive upgrades. */
    val ALL: Array<androidx.room.migration.Migration> = arrayOf()
}
