import SwiftUI

struct ServerSetupView: View {
    @Bindable var viewModel: ServerViewModel
    var onConnect: (ServerConfig) -> Void

    @FocusState private var focusedField: Field?

    enum Field {
        case ip, port, connect, production
    }

    var body: some View {
        VStack(spacing: 40) {
            Text("BROADCASTER")
                .font(.system(size: 72, weight: .bold))
                .foregroundStyle(Color.broadcasterGreen)
                .shadow(color: .broadcasterGreen.opacity(0.8), radius: 20)

            Text("Server Setup")
                .font(.system(size: 36))
                .foregroundStyle(.secondary)

            VStack(spacing: 30) {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Server IP Address")
                        .font(.headline)
                        .foregroundStyle(.secondary)

                    TextField("192.168.1.100", text: $viewModel.ipAddress)
                        .textFieldStyle(.plain)
                        .padding()
                        .background(Color.white.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .focused($focusedField, equals: .ip)
                }

                VStack(alignment: .leading, spacing: 10) {
                    Text("Port")
                        .font(.headline)
                        .foregroundStyle(.secondary)

                    TextField("12121", text: $viewModel.port)
                        .textFieldStyle(.plain)
                        .keyboardType(.numberPad)
                        .padding()
                        .background(Color.white.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .focused($focusedField, equals: .port)
                }
            }
            .frame(maxWidth: 600)

            if let error = viewModel.errorMessage {
                Text(error)
                    .foregroundStyle(.red)
                    .font(.headline)
            }

            HStack(spacing: 40) {
                Button {
                    Task {
                        if let config = await viewModel.connect() {
                            onConnect(config)
                        }
                    }
                } label: {
                    HStack {
                        if viewModel.isConnecting {
                            ProgressView()
                                .progressViewStyle(.circular)
                        }
                        Text("Connect")
                    }
                    .frame(width: 200)
                }
                .buttonStyle(BroadcasterButtonStyle())
                .disabled(viewModel.isConnecting)
                .focused($focusedField, equals: .connect)

                Button {
                    Task {
                        if let config = await viewModel.useProductionServer() {
                            onConnect(config)
                        }
                    }
                } label: {
                    Text("Use Demo Server")
                        .frame(width: 200)
                }
                .buttonStyle(BroadcasterButtonStyle(isPrimary: false))
                .disabled(viewModel.isConnecting)
                .focused($focusedField, equals: .production)
            }
        }
        .padding(60)
        .background(Color.black)
        .onAppear {
            focusedField = .ip
        }
    }
}

struct BroadcasterButtonStyle: ButtonStyle {
    var isPrimary: Bool = true

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .padding(.horizontal, 40)
            .padding(.vertical, 16)
            .background(
                isPrimary
                    ? Color.broadcasterGreen.opacity(configuration.isPressed ? 0.6 : 0.8)
                    : Color.white.opacity(configuration.isPressed ? 0.2 : 0.1)
            )
            .foregroundStyle(isPrimary ? .black : .white)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
    }
}

extension Color {
    static let broadcasterGreen = Color(red: 0, green: 1, blue: 0)
    static let broadcasterRed = Color(red: 1, green: 0, blue: 0)
    static let guideBackground = Color(red: 0.1, green: 0.1, blue: 0.1).opacity(0.95)
    static let currentProgramHighlight = Color(red: 0, green: 0.27, blue: 0)
}
