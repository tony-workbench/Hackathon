import SwiftUI

struct CallSessionView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var viewModel: ProduceInspectionViewModel

    var body: some View {
        NavigationStack {
            VStack(spacing: 18) {
                VStack(spacing: 6) {
                    Image(systemName: "phone.connection.fill")
                        .font(.system(size: 34))
                        .foregroundStyle(.green)
                    Text("Bob Escalation")
                        .font(.title3.bold())
                    Text(viewModel.callStatusMessage.isEmpty ? "Ready to call" : viewModel.callStatusMessage)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                ScrollView {
                    VStack(alignment: .leading, spacing: 10) {
                        if viewModel.callTranscript.isEmpty {
                            Text("Transcript will appear here during demo calls.")
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        } else {
                            ForEach(viewModel.callTranscript) { line in
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(line.speaker)
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(.secondary)
                                    Text(line.text)
                                }
                                .padding(12)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color(.secondarySystemGroupedBackground))
                                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                            }
                        }
                    }
                }

                Button {
                    Task {
                        await viewModel.startEscalationCall()
                    }
                } label: {
                    Text(viewModel.isCallingBob ? "Calling…" : "Start Call")
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .padding()
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)
                .disabled(viewModel.isCallingBob)
            }
            .padding()
            .navigationTitle("Call")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
