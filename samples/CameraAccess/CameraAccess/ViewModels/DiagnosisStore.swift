import Foundation
import Observation

struct DiagnosisRecord: Identifiable {
    let id = UUID()
    let date: Date
    let summary: String
    let freshness: String
    let damage: String
    let status: String
    let severity: String
    let issues: [String]
    let recommendations: [String]
    let action: String
}

@Observable
@MainActor
final class DiagnosisStore {
    static let shared = DiagnosisStore()

    private(set) var recentDiagnoses: [DiagnosisRecord] = []

    private init() {}

    func add(_ diagnosis: DiagnosisRecord) {
        recentDiagnoses.insert(diagnosis, at: 0)
        recentDiagnoses = Array(recentDiagnoses.prefix(5))
    }
}
