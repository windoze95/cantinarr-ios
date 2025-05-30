// File: RadarrRootFolder.swift
// Purpose: Defines RadarrRootFolder component for Cantinarr

import Foundation

struct RadarrRootFolder: Codable, Identifiable {
    let id: Int
    let path: String?
    let freeSpace: Int64?
    let totalSpace: Int64?
    let unmappedFolders: [RadarrUnmappedFolder]?
}
