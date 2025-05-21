//  Encapsulates generic paging counters + guard logic.

import SwiftUI

@MainActor
/// Utility that tracks paging state for infinite‑scroll style lists.
struct PagedLoader {
    private(set) var page = 1
    private(set) var totalPages = 1
    private(set) var isLoading = false

    /// Reset counters for a brand‑new query or refresh.
    mutating func reset() {
        page = 1
        totalPages = 1
        isLoading = false // Ensure loading state is reset too
    }

    /// Returns `true` if we can request the next page; flips `isLoading` to `true`.
    mutating func beginLoading() -> Bool {
        guard !isLoading, page <= totalPages else { return false }
        isLoading = true
        return true
    }

    /// Call after a page returns to update counters. Increments page number for next load.
    mutating func endLoading(next total: Int) {
        totalPages = total
        page += 1 // Increment page number *after* successful load
        isLoading = false
    }

    /// Call on error or cancellation.
    mutating func cancelLoading() {
        isLoading = false
        // Optionally, decide whether to decrement page number if load failed?
        // Current implementation keeps page number, assuming retry will use the same page.
    }
}
