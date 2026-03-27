package com.pillyliu.pinprofandroid

import android.os.Build
import android.os.SystemClock
import android.os.Trace
import android.util.Log
import java.util.Locale
import java.util.concurrent.atomic.AtomicInteger

internal object PinballPerformanceTrace {
    private const val TAG = "PinballPerf"
    private val nextAsyncCookie = AtomicInteger(1)

    fun <T> measure(
        name: String,
        detail: String? = null,
        block: () -> T,
    ): T {
        val sectionName = traceSectionName(name)
        val startedAtNs = SystemClock.elapsedRealtimeNanos()
        Trace.beginSection(sectionName)
        return try {
            block()
        } finally {
            Trace.endSection()
            logDuration(name, detail, startedAtNs)
        }
    }

    suspend fun <T> measureSuspend(
        name: String,
        detail: String? = null,
        block: suspend () -> T,
    ): T {
        val sectionName = traceSectionName(name)
        val cookie = nextAsyncCookie.getAndIncrement()
        val startedAtNs = SystemClock.elapsedRealtimeNanos()
        beginAsyncSection(sectionName, cookie)
        return try {
            block()
        } finally {
            endAsyncSection(sectionName, cookie)
            logDuration(name, detail, startedAtNs)
        }
    }

    private fun beginAsyncSection(name: String, cookie: Int) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            Trace.beginAsyncSection(name, cookie)
        }
    }

    private fun endAsyncSection(name: String, cookie: Int) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            Trace.endAsyncSection(name, cookie)
        }
    }

    private fun logDuration(
        name: String,
        detail: String?,
        startedAtNs: Long,
    ) {
        val durationMs = (SystemClock.elapsedRealtimeNanos() - startedAtNs) / 1_000_000.0
        val formattedDuration = String.format(Locale.US, "%.2f", durationMs)
        if (detail.isNullOrBlank()) {
            Log.i(TAG, "pinball_perf name=$name duration_ms=$formattedDuration")
        } else {
            Log.i(TAG, "pinball_perf name=$name duration_ms=$formattedDuration detail=$detail")
        }
    }

    private fun traceSectionName(name: String): String = name.take(120)
}
