import Foundation

@MainActor
protocol RadarrServiceType {
    func getMovies() async throws -> [RadarrMovie]
    func getMovie(id: Int) async throws -> RadarrMovie
    func getQualityProfiles() async throws -> [RadarrQualityProfile]
    func getSystemStatus() async throws -> RadarrSystemStatus
    func searchForMovie(_ movieId: Int) async throws -> RadarrCommandResponse
    func updateMovie(_ movie: RadarrMovie, moveFiles: Bool) async throws -> RadarrMovie
    func deleteMovie(_ movieId: Int, deleteFiles: Bool, addImportExclusion: Bool) async throws
}
