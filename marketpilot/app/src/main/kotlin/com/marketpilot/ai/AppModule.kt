package com.marketpilot.ai

import com.marketpilot.ai.work.WorkScheduler
import com.marketpilot.data.repositories.AlertNotifier
import com.marketpilot.feature.settings.ScheduleUpdater
import dagger.Binds
import dagger.Module
import dagger.hilt.InstallIn
import dagger.hilt.components.SingletonComponent

@Module
@InstallIn(SingletonComponent::class)
abstract class AppModule {
    @Binds abstract fun alertNotifier(impl: NotificationHelper): AlertNotifier
    @Binds abstract fun scheduleUpdater(impl: WorkScheduler): ScheduleUpdater
}
