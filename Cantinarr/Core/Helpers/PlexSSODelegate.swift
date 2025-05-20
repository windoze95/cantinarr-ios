@MainActor
protocol PlexSSODelegate: AnyObject {
    func didReceivePlexToken(_ token: String)
}
