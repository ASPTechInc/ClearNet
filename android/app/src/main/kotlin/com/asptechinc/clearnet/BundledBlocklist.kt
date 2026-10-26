// SPDX-FileCopyrightText: 2026 ASPTechnologies Incorporation
// SPDX-License-Identifier: MIT

package com.asptechinc.clearnet

import android.content.Context
import android.os.SystemClock
import android.util.Log
import java.util.concurrent.atomic.AtomicBoolean
import kotlin.concurrent.thread

/**
 * The adult domain list bundled with the app, from The Block List Project
 * (regenerate it with scripts/update_adult_blocklist.sh). The VPN and the
 * accessibility service share one copy, loaded on a background thread the
 * first time either starts. Until then, or if loading fails, it is empty and
 * the user's own lists still apply.
 */
internal object BundledBlocklist {
    private const val TAG = "BundledBlocklist"
    private const val ASSET = "blocklists/adult.txt"

    @Volatile
    var domains: SortedDomainList = SortedDomainList.EMPTY
        private set

    private val started = AtomicBoolean(false)

    // Set when a load attempt ends, whether or not it worked
    private val lock = Object()
    private var finished = false

    /** Starts loading the list unless it is loaded or loading already. */
    fun load(context: Context) {
        if (!started.compareAndSet(false, true)) return
        synchronized(lock) { finished = false }
        val assets = context.applicationContext.assets
        thread(name = TAG, isDaemon = true) {
            val begin = SystemClock.elapsedRealtime()
            try {
                val list = SortedDomainList.parse(assets.open(ASSET).use { it.readBytes() })
                if (list == null) {
                    Log.e(TAG, "$ASSET is not sorted; run scripts/update_adult_blocklist.sh")
                    return@thread
                }
                domains = list
                Log.i(TAG, "Loaded ${list.size} domains in ${SystemClock.elapsedRealtime() - begin} ms")
            } catch (e: Exception) {
                Log.e(TAG, "Could not load $ASSET", e)
                started.set(false)
            } catch (e: OutOfMemoryError) {
                Log.e(TAG, "Not enough memory to load $ASSET", e)
                started.set(false)
            } finally {
                synchronized(lock) {
                    finished = true
                    lock.notifyAll()
                }
            }
        }
    }

    /**
     * Loads the list if needed and waits for it. Empty if loading failed.
     * Blocks, so call it off the main thread.
     */
    fun await(context: Context): SortedDomainList {
        load(context)
        synchronized(lock) {
            while (!finished) lock.wait()
        }
        return domains
    }
}
