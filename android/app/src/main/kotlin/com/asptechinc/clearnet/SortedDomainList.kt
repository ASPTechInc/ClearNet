// SPDX-FileCopyrightText: 2026 ASPTechnologies Incorporation
// SPDX-License-Identifier: MIT

package com.asptechinc.clearnet

/**
 * A large list of domains kept as one block of text, one domain per line,
 * sorted by byte value and searched with binary search. It needs the text
 * plus one Int per domain: a fraction of what a HashSet of Strings would take
 * for the bundled list's million domains.
 */
internal class SortedDomainList private constructor(
    private val bytes: ByteArray,
    private val starts: IntArray,
) {
    val size: Int get() = starts.size

    /** True if [name], a [DomainRules.normalise]d domain, is in the list. */
    operator fun contains(name: String): Boolean {
        var low = 0
        var high = starts.size - 1
        while (low <= high) {
            val mid = (low + high) ushr 1
            val cmp = compareLine(starts[mid], name)
            when {
                cmp < 0 -> low = mid + 1
                cmp > 0 -> high = mid - 1
                else -> return true
            }
        }
        return false
    }

    /** Compares the line starting at [start] with [name], byte by byte. */
    private fun compareLine(start: Int, name: String): Int {
        var pos = start
        for (char in name) {
            if (isLineEnd(bytes, pos)) return -1
            val diff = (bytes[pos].toInt() and 0xff) - char.code
            if (diff != 0) return diff
            pos++
        }
        return if (isLineEnd(bytes, pos)) 0 else 1
    }

    companion object {
        private const val NEWLINE = '\n'.code.toByte()
        private const val COMMENT = '#'.code.toByte()

        val EMPTY = SortedDomainList(ByteArray(0), IntArray(0))

        /**
         * Reads one domain per line, skipping blank lines and lines starting
         * with '#'. Returns null if the domains are out of order, since
         * binary search would then miss some of them.
         */
        fun parse(bytes: ByteArray): SortedDomainList? {
            var lines = 1
            for (b in bytes) if (b == NEWLINE) lines++

            val starts = IntArray(lines)
            var count = 0
            var start = 0
            while (start < bytes.size) {
                var end = start
                while (!isLineEnd(bytes, end)) end++
                if (end > start && bytes[start] != COMMENT) {
                    if (count > 0 && compareLines(bytes, starts[count - 1], start) > 0) return null
                    starts[count++] = start
                }
                start = end + 1
            }
            return SortedDomainList(bytes, starts.copyOf(count))
        }

        private fun isLineEnd(bytes: ByteArray, pos: Int) =
            pos >= bytes.size || bytes[pos] == NEWLINE

        private fun compareLines(bytes: ByteArray, a: Int, b: Int): Int {
            var i = a
            var j = b
            while (true) {
                val aEnd = isLineEnd(bytes, i)
                val bEnd = isLineEnd(bytes, j)
                if (aEnd || bEnd) return (if (aEnd) 0 else 1) - (if (bEnd) 0 else 1)
                val diff = (bytes[i].toInt() and 0xff) - (bytes[j].toInt() and 0xff)
                if (diff != 0) return diff
                i++
                j++
            }
        }
    }
}
