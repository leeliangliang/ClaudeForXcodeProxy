//
//  ContentView.swift
//  XcodeClaudeEnvConfig
//
//  Created by Lee on 2026/2/11.
//

import SwiftUI

struct ContentView: View {
    @State private var baseURL: String = ""
    @State private var authToken: String = ""
    @State private var resultMessage: String = ""
    @State private var showingAlert: Bool = false
    @State private var isError: Bool = false

    private let manager = LaunchAgentManager.shared

    var body: some View {
        VStack(spacing: 20) {
            // 标题
            VStack(spacing: 8) {
                Image(systemName: "network")
                    .imageScale(.large)
                    .foregroundStyle(.tint)
                    .font(.system(size: 40))

                Text("app.title")
                    .font(.title)
                    .fontWeight(.bold)

                Text("app.subtitle")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.top)

            // 输入表单
            Form {
                Section(header: Text("form.section.config")) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Base URL")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        TextField("", text: $baseURL, prompt: Text("form.baseURL.placeholder"))
                            .textFieldStyle(.roundedBorder)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Auth Token")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        TextField("", text: $authToken, prompt: Text("form.authToken.placeholder"))
                            .textFieldStyle(.roundedBorder)
                    }
                }
            }
            .formStyle(.grouped)
            .frame(height: 200)

            // 按钮组
            VStack(spacing: 12) {
                Button(action: applyConfiguration) {
                    Label("button.apply", systemImage: "checkmark.circle.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)

                Button(action: removeConfiguration) {
                    Label("button.remove", systemImage: "trash")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .tint(.red)
                .controlSize(.large)
            }
            .padding(.horizontal)

            // 状态信息
            if manager.isConfigured() {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("status.configured")
                        .font(.caption)
                }
                .padding(.horizontal)
            }

            Spacer()
        }
        .padding()
        .alert("alert.title", isPresented: $showingAlert) {
            Button("alert.ok", role: .cancel) { }
        } message: {
            Text(resultMessage)
        }
        .onAppear {
            loadExistingConfiguration()
        }
    }

    // MARK: - Actions

    private func applyConfiguration() {
        guard !baseURL.trimmingCharacters(in: .whitespaces).isEmpty else {
            showError(String(localized: "error.baseURL.empty"))
            return
        }
        guard !authToken.trimmingCharacters(in: .whitespaces).isEmpty else {
            showError(String(localized: "error.authToken.empty"))
            return
        }

        let result = manager.setEnvironmentVariables(baseURL: baseURL, token: authToken)
        handleResult(result)
    }

    private func removeConfiguration() {
        let result = manager.removeConfiguration()
        handleResult(result)
        baseURL = ""
        authToken = ""
    }

    private func handleResult(_ result: Result<String, Error>) {
        switch result {
        case .success(let message):
            resultMessage = message
            isError = false
            showingAlert = true
        case .failure(let error):
            showError(error.localizedDescription)
        }
    }

    private func showError(_ message: String) {
        resultMessage = message
        isError = true
        showingAlert = true
    }

    private func loadExistingConfiguration() {
        if let config = manager.getExistingConfiguration() {
            baseURL = config.baseURL ?? ""
            authToken = config.token ?? ""
        }
    }
}

#Preview {
    ContentView()
}
