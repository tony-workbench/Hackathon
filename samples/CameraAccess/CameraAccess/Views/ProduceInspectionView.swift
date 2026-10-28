import SwiftUI

struct ProduceInspectionView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @State private var viewModel: ProduceInspectionViewModel
    @State private var animateGradient = false
    @State private var showCallSession = false

    init(image: UIImage) {
        self._viewModel = State(wrappedValue: ProduceInspectionViewModel(image: image))
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color.black,
                    Color(red: 0.05, green: 0.08, blue: 0.15),
                    Color(red: 0.0, green: 0.35, blue: 0.25),
                ],
                startPoint: animateGradient ? .topLeading : .bottomTrailing,
                endPoint: animateGradient ? .bottomTrailing : .topLeading
            )
            .ignoresSafeArea()
            .animation(
                .easeInOut(duration: 8).repeatForever(autoreverses: true),
                value: animateGradient
            )

            ScrollView(showsIndicators: false) {
                VStack(spacing: 28) {
                    header
                    imageCard

                    if viewModel.isLoading {
                        loadingCard
                    }

                    if !viewModel.aiResponse.isEmpty && !viewModel.isLoading {
                        resultCard
                    }

                    Spacer(minLength: 40)
                }
                .padding()
            }
        }
        .overlay(alignment: .topTrailing) {
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(.white)
                    .frame(width: 42, height: 42)
                    .background(.black.opacity(0.45))
                    .clipShape(Circle())
            }
            .padding()
        }
        .onAppear {
            animateGradient = true
            Task {
                await viewModel.startInspectionIfNeeded()
            }
        }
        .sheet(isPresented: $showCallSession) {
            CallSessionView(viewModel: viewModel)
        }
        .alert("Inspection Error", isPresented: $viewModel.showError) {
            Button("OK") {
                viewModel.dismissError()
            }
        } message: {
            Text(viewModel.errorMessage)
        }
    }

    private var header: some View {
        VStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(.ultraThinMaterial)
                    .frame(width: 95, height: 95)

                Image(systemName: "sparkles.rectangle.stack.fill")
                    .font(.system(size: 42))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.green, .mint, .cyan],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
            .shadow(color: .green.opacity(0.4), radius: 25)

            Text("AI Quality Check")
                .font(.system(size: 34, weight: .bold))

            Text("Glasses Capture Inspection")
                .foregroundStyle(.white.opacity(0.7))
                .font(.headline)
        }
        .foregroundStyle(.white)
        .padding(.top, 30)
    }

    private var imageCard: some View {
        VStack(spacing: 22) {
            ZStack(alignment: .topTrailing) {
                Image(uiImage: viewModel.image)
                    .resizable()
                    .scaledToFill()
                    .frame(height: 280)
                    .frame(maxWidth: .infinity)
                    .clipped()
                    .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))

                HStack(spacing: 8) {
                    Circle()
                        .fill(.green)
                        .frame(width: 10, height: 10)

                    Text("GLASSES CAPTURE")
                        .font(.caption.bold())
                        .foregroundStyle(.white)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(.black.opacity(0.7))
                .clipShape(Capsule())
                .padding(16)
            }
        }
        .padding(22)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .stroke(.white.opacity(0.08), lineWidth: 1)
        }
    }

    private var loadingCard: some View {
        VStack(spacing: 24) {
            ZStack {
                Circle()
                    .stroke(.white.opacity(0.08), lineWidth: 12)

                Circle()
                    .trim(from: 0, to: viewModel.scanProgress)
                    .stroke(
                        LinearGradient(
                            colors: [.green, .mint, .cyan],
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                        style: StrokeStyle(lineWidth: 12, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut, value: viewModel.scanProgress)

                VStack(spacing: 6) {
                    Text("\(Int(viewModel.scanProgress * 100))%")
                        .font(.system(size: 34, weight: .bold))
                        .foregroundStyle(.white)

                    Text("Analyzing")
                        .foregroundStyle(.white.opacity(0.7))
                }
            }
            .frame(width: 150, height: 150)

            VStack(spacing: 10) {
                Text("Running AI Inspection")
                    .font(.title3.bold())
                    .foregroundStyle(.white)

                Text("Evaluating freshness, bruising, spoilage, and packaging integrity.")
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.white.opacity(0.7))
            }
        }
        .padding(30)
        .frame(maxWidth: .infinity)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
    }

    private var resultCard: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Label("Inspection Result", systemImage: "checkmark.seal.fill")
                    .font(.title3.bold())
                    .foregroundStyle(.green)

                Spacer()

                Text("AI VERIFIED")
                    .font(.caption.bold())
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(.green.opacity(0.2))
                    .foregroundStyle(.green)
                    .clipShape(Capsule())
            }

            Text(viewModel.aiResponse)
                .font(.headline)
                .foregroundStyle(.white.opacity(0.92))
                .lineSpacing(7)

            Divider()
                .overlay(.white.opacity(0.15))

            HStack {
                metricCard(title: "Freshness", value: viewModel.freshness, color: color(for: viewModel.freshness))
                metricCard(title: "Damage", value: viewModel.damage, color: color(for: viewModel.damage))
                metricCard(title: "Status", value: viewModel.status, color: color(for: viewModel.status))
            }

            VStack(alignment: .leading, spacing: 10) {
                Label("Severity: \(viewModel.severity)", systemImage: "exclamationmark.triangle")
                    .font(.subheadline.weight(.semibold))
                Text(viewModel.action)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.85))

                if !viewModel.issues.isEmpty {
                    Text("Issues")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.7))
                    ForEach(viewModel.issues, id: \.self) { issue in
                        Text("• \(issue)")
                            .font(.caption)
                    }
                }

                if !viewModel.recommendations.isEmpty {
                    Text("Recommendations")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.7))
                    ForEach(viewModel.recommendations, id: \.self) { recommendation in
                        Text("• \(recommendation)")
                            .font(.caption)
                    }
                }
            }
            .foregroundStyle(.white)

            if viewModel.shouldShowHelpContacts {
                Divider()
                    .overlay(.white.opacity(0.15))

                VStack(alignment: .leading, spacing: 12) {
                    Text("Escalation")
                        .font(.headline)
                        .foregroundStyle(.white)

                    Button {
                        showCallSession = true
                    } label: {
                        HStack {
                            Image(systemName: "waveform.and.phone.fill")
                            Text("Open Call Session")
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.green)
                    .disabled(viewModel.isCallingBob)

                    if !viewModel.callStatusMessage.isEmpty {
                        Text(viewModel.callStatusMessage)
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.7))
                    }

                    Text("Manual contacts")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.7))

                    ForEach(viewModel.helpContacts) { contact in
                        Button {
                            call(contact)
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: "phone.fill")
                                    .font(.headline)
                                    .foregroundStyle(.black)
                                    .frame(width: 36, height: 36)
                                    .background(.green)
                                    .clipShape(Circle())

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(contact.name)
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(.white)

                                    Text(contact.role)
                                        .font(.caption)
                                        .foregroundStyle(.white.opacity(0.7))
                                }

                                Spacer()

                                Text(contact.displayNumber)
                                    .font(.caption.weight(.medium))
                                    .foregroundStyle(.white.opacity(0.85))
                            }
                            .padding(12)
                            .background(.white.opacity(0.06))
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .padding(24)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }

    private func call(_ contact: ProduceInspectionViewModel.HelpContact) {
        guard let url = URL(string: "tel://\(contact.phoneNumber)") else { return }
        openURL(url)
    }

    private func color(for value: String) -> Color {
        switch value.lowercased() {
        case "high", "pass", "none":
            return .green
        case "medium", "moderate", "review":
            return .orange
        case "low":
            return .mint
        case "reject":
            return .red
        default:
            return .gray
        }
    }

    private func metricCard(title: String, value: String, color: Color) -> some View {
        VStack(spacing: 10) {
            Text(value)
                .font(.title2.bold())
                .foregroundStyle(color)

            Text(title)
                .font(.caption)
                .foregroundStyle(.white.opacity(0.7))
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}
