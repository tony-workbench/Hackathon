import Foundation
import Observation
import SwiftUI

@Observable
@MainActor
final class ProduceInspectionViewModel {
    struct HelpContact: Identifiable {
        let id = UUID()
        let name: String
        let role: String
        let phoneNumber: String
        let displayNumber: String
    }

    struct TranscriptLine: Identifiable {
        let id = UUID()
        let speaker: String
        let text: String
    }
    private struct InspectionRequest: Encodable {
        let mimeType: String
        let imageBase64: String
    }

    private struct InspectionResponse: Decodable {
        let summary: String
        let freshness: String?
        let damage: String?
        let status: String?
        let severity: String?
        let issues: [String]?
        let recommendations: [String]?
        let action: String?
    }

    private struct BackendErrorResponse: Decodable {
        let detail: String
    }

    private struct CallBobRequest: Encodable {
        let summary: String
        let freshness: String
        let damage: String
        let status: String
    }

    private struct CallBobResponse: Decodable {
        let callSid: String
        let message: String
    }

    private struct CallStatusResponse: Decodable {
        let status: String
        let answered: Bool
        let terminal: Bool
    }

    let image: UIImage

    var aiResponse: String = ""
    var freshness: String = "—"
    var damage: String = "—"
    var status: String = "—"
    var severity: String = "—"
    var issues: [String] = []
    var recommendations: [String] = []
    var action: String = ""
    var isLoading: Bool = false
    var scanProgress: Double = 0
    var showResultCard: Bool = false
    var showError: Bool = false
    var errorMessage: String = ""
    var isCallingBob: Bool = false
    var callStatusMessage: String = ""
    var callTranscript: [TranscriptLine] = []

    var shouldShowHelpContacts: Bool {
        switch status.lowercased() {
        case "review", "reject":
            return true
        default:
            return false
        }
    }

    let helpContacts: [HelpContact] = [
        HelpContact(
            name: "Bob",
            role: "Primary contact",
            phoneNumber: "+15550100100",
            displayNumber: "+1 (555) 010-0100"
        ),
        HelpContact(
            name: "Yolo County Agriculture",
            role: "Agricultural Commissioner",
            phoneNumber: "+15306668140",
            displayNumber: "+1 (530) 666-8140"
        ),
        HelpContact(
            name: "UC Master Gardeners",
            role: "Plant help desk",
            phoneNumber: "+15306668737",
            displayNumber: "+1 (530) 666-8737"
        ),
        HelpContact(
            name: "Aspen Pest Management",
            role: "Davis pest control",
            phoneNumber: "+15307537378",
            displayNumber: "+1 (530) 753-7378"
        ),
    ]

    private let configuration = AppConfiguration.shared
    private let diagnosisStore = DiagnosisStore.shared
    private let urlSession: URLSession

    init(image: UIImage) {
        self.image = image

        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 60
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        config.urlCache = nil
        self.urlSession = URLSession(configuration: config)
    }

    func startInspectionIfNeeded() async {
        guard aiResponse.isEmpty, !isLoading else { return }
        guard let imageData = image.jpegData(compressionQuality: 0.85) else {
            showError("Unable to prepare the captured image for inspection.")
            return
        }

        isLoading = true
        scanProgress = 0
        showResultCard = false

        async let progressAnimation: Void = animateProgress()

        do {
            let requestBody = InspectionRequest(
                mimeType: "image/jpeg",
                imageBase64: imageData.base64EncodedString()
            )

            guard let backendBaseURL = configuration.backendURL else {
                throw ProduceInspectionError.invalidBackendURL
            }
            var request = URLRequest(url: backendBaseURL.appendingPathComponent("inspect-produce"))
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONEncoder().encode(requestBody)

            let (data, response) = try await urlSession.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                throw ProduceInspectionError.invalidServerResponse
            }

            if httpResponse.statusCode == 503 {
                // The backend has no Twilio settings: show the call as a demo instead of failing.
                isCallingBob = false
                await runDemoCall(note: "Twilio isn't set up on the backend, so this is a demo call.")
                return
            }

            guard 200..<300 ~= httpResponse.statusCode else {
                if let backendError = try? JSONDecoder().decode(BackendErrorResponse.self, from: data) {
                    throw ProduceInspectionError.backendError(
                        statusCode: httpResponse.statusCode,
                        message: backendError.detail
                    )
                }

                let responseBody = String(data: data, encoding: .utf8) ?? "Unknown server response"
                throw ProduceInspectionError.backendError(
                    statusCode: httpResponse.statusCode,
                    message: responseBody
                )
            }

            let inspectionResponse: InspectionResponse
            do {
                inspectionResponse = try JSONDecoder().decode(InspectionResponse.self, from: data)
            } catch {
                let responseBody = String(data: data, encoding: .utf8) ?? "Unreadable response body"
                throw ProduceInspectionError.invalidPayload(message: responseBody)
            }
            await progressAnimation

            freshness = inspectionResponse.freshness ?? inferredFreshness(from: inspectionResponse.summary)
            damage = inspectionResponse.damage ?? inferredDamage(from: inspectionResponse.summary)
            status = inspectionResponse.status ?? inferredStatus(from: inspectionResponse.summary)
            severity = inspectionResponse.severity ?? inferredSeverity(from: inspectionResponse.summary)
            issues = inspectionResponse.issues ?? inferredIssues(from: inspectionResponse.summary)
            recommendations = inspectionResponse.recommendations ?? inferredRecommendations(from: inspectionResponse.summary)
            action = inspectionResponse.action ?? inferredAction(from: status)

            diagnosisStore.add(
                DiagnosisRecord(
                    date: Date(),
                    summary: inspectionResponse.summary,
                    freshness: freshness,
                    damage: damage,
                    status: status,
                    severity: severity,
                    issues: issues,
                    recommendations: recommendations,
                    action: action
                )
            )

            withAnimation(.spring(duration: 0.7)) {
                isLoading = false
                showResultCard = true
            }

            await typeText(inspectionResponse.summary)
        } catch {
            await progressAnimation
            isLoading = false
            showError("Inspection request failed: \(error.localizedDescription)")
        }
    }

    func startEscalationCall() async {
        if configuration.useDemoCalls {
            await runDemoCall()
        } else {
            await callBobWithAISummary()
        }
    }

    private func callBobWithAISummary() async {
        guard shouldShowHelpContacts, !isCallingBob else { return }

        isCallingBob = true
        callStatusMessage = "Calling Bob…"

        do {
            let requestBody = CallBobRequest(
                summary: aiResponse,
                freshness: freshness,
                damage: damage,
                status: status
            )

            guard let backendBaseURL = configuration.backendURL else {
                throw ProduceInspectionError.invalidBackendURL
            }
            var request = URLRequest(url: backendBaseURL.appendingPathComponent("call-bob"))
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONEncoder().encode(requestBody)

            let (data, response) = try await urlSession.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                throw ProduceInspectionError.invalidServerResponse
            }

            guard 200..<300 ~= httpResponse.statusCode else {
                if let backendError = try? JSONDecoder().decode(BackendErrorResponse.self, from: data) {
                    throw ProduceInspectionError.backendError(
                        statusCode: httpResponse.statusCode,
                        message: backendError.detail
                    )
                }
                throw ProduceInspectionError.backendError(
                    statusCode: httpResponse.statusCode,
                    message: String(data: data, encoding: .utf8) ?? "Unknown server response"
                )
            }

            let callResponse = try JSONDecoder().decode(CallBobResponse.self, from: data)
            callStatusMessage = "Calling Bob…"
            await monitorCallStatus(callSid: callResponse.callSid)
        } catch {
            showError("Call request failed: \(error.localizedDescription)")
            callStatusMessage = ""
        }

        isCallingBob = false
    }

    private func runDemoCall(note: String? = nil) async {
        guard shouldShowHelpContacts, !isCallingBob else { return }
        isCallingBob = true
        callStatusMessage = note ?? "Demo call in progress…"
        callTranscript = []

        let script = [
            TranscriptLine(speaker: "Agent", text: "Hi Bob, this is an automated field inspection alert."),
            TranscriptLine(speaker: "Agent", text: "The current lot is marked \(status). Severity is \(severity)."),
            TranscriptLine(speaker: "Bob", text: "Understood. What should the team do next?"),
            TranscriptLine(speaker: "Agent", text: action),
        ]

        for line in script {
            try? await Task.sleep(for: .milliseconds(700))
            callTranscript.append(line)
        }

        callStatusMessage = note.map { "\($0) Demo call completed." } ?? "Demo call completed."
        isCallingBob = false
    }

    func dismissError() {
        showError = false
        errorMessage = ""
    }

    private func monitorCallStatus(callSid: String) async {
        for _ in 0..<12 {
            do {
                try await Task.sleep(for: .seconds(3))
                guard let backendBaseURL = configuration.backendURL else { continue }
                let url = backendBaseURL.appendingPathComponent("call-status").appendingPathComponent(callSid)
                let (data, response) = try await urlSession.data(from: url)
                guard let httpResponse = response as? HTTPURLResponse, 200..<300 ~= httpResponse.statusCode else {
                    continue
                }

                let callStatus = try JSONDecoder().decode(CallStatusResponse.self, from: data)
                switch callStatus.status {
                case "queued", "initiated":
                    callStatusMessage = "Calling Bob…"
                case "ringing":
                    callStatusMessage = "Bob's phone is ringing…"
                case "in-progress":
                    callStatusMessage = "Bob answered."
                case "completed":
                    callStatusMessage = callStatus.answered ? "Bob answered; alert delivered." : "Call ended before Bob answered."
                    return
                case "busy":
                    callStatusMessage = "Bob's line is busy."
                    return
                case "no-answer":
                    callStatusMessage = "Bob did not answer."
                    return
                case "failed", "canceled":
                    callStatusMessage = "Call could not be completed."
                    return
                default:
                    break
                }

                if callStatus.terminal {
                    return
                }
            } catch {
                continue
            }
        }

        callStatusMessage = "Call status unavailable. Please try again or call manually."
    }

    private func animateProgress() async {
        for step in 1...100 {
            try? await Task.sleep(for: .milliseconds(18))
            scanProgress = Double(step) / 100
        }
    }

    private func typeText(_ fullText: String) async {
        aiResponse = ""

        for character in fullText {
            aiResponse.append(character)
            try? await Task.sleep(for: .milliseconds(18))
        }
    }

    private func inferredFreshness(from summary: String) -> String {
        let text = summary.lowercased()
        if text.contains("peak freshness") || text.contains("fresh") || text.contains("healthy") {
            return "High"
        }
        if text.contains("wilted") || text.contains("not be at peak freshness") || text.contains("discoloration") {
            return "Medium"
        }
        if text.contains("spoilage") || text.contains("rotten") || text.contains("mold") {
            return "Low"
        }
        return "Unclear"
    }

    private func inferredDamage(from summary: String) -> String {
        let text = summary.lowercased()
        if text.contains("no obvious signs of bruising") || text.contains("no visible damage") {
            return "None"
        }
        if text.contains("minor") || text.contains("slight bruising") {
            return "Low"
        }
        if text.contains("bruising") || text.contains("damage") || text.contains("compressed") {
            return "Moderate"
        }
        return "Unclear"
    }

    private func inferredSeverity(from summary: String) -> String {
        let text = summary.lowercased()
        if text.contains("spoilage") || text.contains("rotten") || text.contains("mold") {
            return "High"
        }
        if text.contains("wilted") || text.contains("bruising") || text.contains("damage") {
            return "Medium"
        }
        return "Low"
    }

    private func inferredIssues(from summary: String) -> [String] {
        [summary]
    }

    private func inferredRecommendations(from summary: String) -> [String] {
        switch inferredStatus(from: summary) {
        case "Reject":
            return ["Remove the affected produce from sale.", "Escalate to a supervisor for follow-up."]
        case "Review":
            return ["Perform a secondary manual inspection.", "Separate questionable items before packing."]
        default:
            return ["Continue standard handling and monitoring."]
        }
    }

    private func inferredAction(from status: String) -> String {
        switch status.lowercased() {
        case "reject":
            return "Remove from shipment and escalate immediately."
        case "review":
            return "Hold for secondary inspection."
        default:
            return "Proceed with normal handling."
        }
    }

    private func inferredStatus(from summary: String) -> String {
        let text = summary.lowercased()
        if text.contains("cannot be confidently assessed") {
            return "Unclear"
        }
        if text.contains("spoilage") || text.contains("rotten") || text.contains("mold") {
            return "Reject"
        }
        if text.contains("review") || text.contains("not be at peak freshness") || text.contains("wilted") || text.contains("bruising") {
            return "Review"
        }
        return "Pass"
    }

    private func showError(_ message: String) {
        errorMessage = message
        showError = true
    }
}

private enum ProduceInspectionError: LocalizedError {
    case invalidBackendURL
    case invalidServerResponse
    case invalidPayload(message: String)
    case backendError(statusCode: Int, message: String)

    var errorDescription: String? {
        switch self {
        case .invalidBackendURL:
            return "The backend URL is invalid. Update it in Settings."
        case .invalidServerResponse:
            return "The inspection server returned an invalid response."
        case let .invalidPayload(message):
            return "Inspection response did not match the app format: \(message)"
        case let .backendError(statusCode, message):
            return "Backend returned HTTP \(statusCode): \(message)"
        }
    }
}
