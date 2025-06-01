// File: ImagePipelineConfig.swift
// Purpose: Defines ImagePipelineConfig component for Cantinarr

#if canImport(Nuke)
import Nuke

/// Centralised configuration for the shared ``ImagePipeline`` instance.
enum ImagePipelineConfig {
    /// Configure ``ImagePipeline.shared`` with disk and memory caching.
    static func configureShared() {
        // Disk cache stored in Application Support
        let dataCache = try? DataCache(name: "CantinarrImages")
        dataCache?.sizeLimit = 200 * 1024 * 1024 // 200 MB

        // In‑memory image cache
        let imageCache = ImageCache()
        imageCache.costLimit = 50 * 1024 * 1024 // ~50 MB

        var config = ImagePipeline.Configuration()
        config.dataCache = dataCache
        config.imageCache = imageCache
        config.isProgressiveDecodingEnabled = true

        ImagePipeline.shared = ImagePipeline(configuration: config)
    }
}
#endif
