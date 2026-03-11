//
//  LaunchAgentManager.swift
//  XcodeClaudeEnvConfig
//
//  Created by Lee on 2026/2/11.
//

import Foundation

/// 管理 launchd 环境变量的设置和持久化
class LaunchAgentManager {
    static let shared = LaunchAgentManager()

    private let plistName = "com.xcodeClaudeEnvConfig.setenv"
    private var launchAgentsDir: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/LaunchAgents")
    }
    private var plistURL: URL {
        launchAgentsDir.appendingPathComponent("\(plistName).plist")
    }

    private init() {}

    // MARK: - Public

    /// 设置环境变量（立即生效 + 持久化）
    func setEnvironmentVariables(baseURL: String, token: String) -> Result<String, Error> {
        // 1. 立即设置环境变量
        let immediateResult = setImmediate(baseURL: baseURL, token: token)
        if case .failure(let error) = immediateResult {
            return .failure(error)
        }

        // 2. 持久化到 plist
        let persistResult = savePersistent(baseURL: baseURL, token: token)
        if case .failure(let error) = persistResult {
            return .failure(error)
        }

        let lines = [
            "✅ \(String(localized: "result.env.set"))",
            "✅ ANTHROPIC_BASE_URL: \(baseURL)",
            "✅ ANTHROPIC_AUTH_TOKEN: \(token)",
            "✅ \(String(localized: "result.persisted \(plistURL.path)"))",
            "",
            "⚠️ \(String(localized: "result.restart.xcode"))",
            "ℹ️ \(String(localized: "result.auto.set"))"
        ]
        return .success(lines.joined(separator: "\n"))
    }

    /// 移除配置
    func removeConfiguration() -> Result<String, Error> {
        var messages: [String] = []

        // 1. 卸载 LaunchAgent（优先使用 service label 格式，失败则用 plist 路径）
        if FileManager.default.fileExists(atPath: plistURL.path) {
            let bootoutResult = runLaunchctl(args: ["bootout", "gui/\(getuid())/\(plistName)"])
            if case .failure = bootoutResult {
                // 降级：尝试用 plist 路径方式卸载
                _ = runLaunchctl(args: ["bootout", "gui/\(getuid())", plistURL.path])
            }

            // 2. 删除 plist 文件
            do {
                try FileManager.default.removeItem(at: plistURL)
                messages.append("✅ \(String(localized: "result.deleted \(plistURL.lastPathComponent)"))")
            } catch {
                return .failure(error)
            }
        }

        // 3. 清除当前会话中的环境变量
        for key in ["ANTHROPIC_BASE_URL", "ANTHROPIC_AUTH_TOKEN"] {
            let result = runLaunchctl(args: ["unsetenv", key])
            if case .success = result {
                messages.append("✅ \(String(localized: "result.env.unset")) \(key)")
            }
        }

        if messages.isEmpty {
            return .success("ℹ️ \(String(localized: "result.no.config"))")
        } else {
            messages.append("\n⚠️ \(String(localized: "result.restart.xcode"))")
            return .success(messages.joined(separator: "\n"))
        }
    }

    /// 检查配置是否存在
    func isConfigured() -> Bool {
        FileManager.default.fileExists(atPath: plistURL.path)
    }

    /// 读取已保存的环境变量配置
    func getExistingConfiguration() -> (baseURL: String?, token: String?)? {
        let baseURL = readBaseURLFromPlist()
        let token = readTokenFromPlist()

        if baseURL == nil && token == nil { return nil }
        return (baseURL, token)
    }

    // MARK: - LaunchAgent

    private func setImmediate(baseURL: String, token: String) -> Result<Void, Error> {
        for (key, value) in [("ANTHROPIC_BASE_URL", baseURL), ("ANTHROPIC_AUTH_TOKEN", token)] {
            let result = runLaunchctl(args: ["setenv", key, value])
            if case .failure(let error) = result {
                return .failure(NSError(domain: "LaunchctlError", code: -1,
                    userInfo: [NSLocalizedDescriptionKey: String(localized: "error.setenv.failed \(key) \(error.localizedDescription)")]))            }
        }
        return .success(())
    }

    private func savePersistent(baseURL: String, token: String) -> Result<Void, Error> {
        do {
            if !FileManager.default.fileExists(atPath: launchAgentsDir.path) {
                try FileManager.default.createDirectory(at: launchAgentsDir, withIntermediateDirectories: true)
            }

            _ = runLaunchctl(args: ["bootout", "gui/\(getuid())", plistURL.path])

            let plistDict: [String: Any] = [
                "Label": plistName,
                "ProgramArguments": [
                    "/bin/bash", "-c",
                    "/bin/launchctl setenv ANTHROPIC_BASE_URL '\(baseURL)' && /bin/launchctl setenv ANTHROPIC_AUTH_TOKEN '\(token)'"
                ],
                "RunAtLoad": true
            ]

            let data = try PropertyListSerialization.data(fromPropertyList: plistDict, format: .xml, options: 0)
            try data.write(to: plistURL, options: .atomic)

            let loadResult = runLaunchctl(args: ["bootstrap", "gui/\(getuid())", plistURL.path])
            if case .failure = loadResult {
                _ = runLaunchctl(args: ["load", "-w", plistURL.path])
            }

            return .success(())
        } catch {
            return .failure(error)
        }
    }

    private func readBaseURLFromPlist() -> String? {
        guard let command = readPlistCommand() else { return nil }
        return extractValue(from: command, pattern: #"ANTHROPIC_BASE_URL '([^']+)'"#)
    }

    private func readTokenFromPlist() -> String? {
        guard let command = readPlistCommand() else { return nil }
        return extractValue(from: command, pattern: #"ANTHROPIC_AUTH_TOKEN '([^']+)'"#)
    }

    private func readPlistCommand() -> String? {
        guard FileManager.default.fileExists(atPath: plistURL.path),
              let data = FileManager.default.contents(atPath: plistURL.path),
              let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any],
              let args = plist["ProgramArguments"] as? [String],
              args.count == 3,
              let command = args.last else {
            return nil
        }
        return command
    }

    private func extractValue(from text: String, pattern: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              match.numberOfRanges > 1,
              let range = Range(match.range(at: 1), in: text) else {
            return nil
        }
        return String(text[range])
    }

    private func runLaunchctl(args: [String]) -> Result<String, Error> {
        let process = Process()
        let pipe = Pipe()
        let errorPipe = Pipe()

        process.executableURL = URL(fileURLWithPath: "/bin/launchctl")
        process.arguments = args
        process.standardOutput = pipe
        process.standardError = errorPipe

        do {
            try process.run()
            process.waitUntilExit()

            let output = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
            let errorOutput = String(data: errorPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""

            if process.terminationStatus == 0 {
                return .success(output)
            } else {
                return .failure(NSError(domain: "LaunchctlError", code: Int(process.terminationStatus),
                    userInfo: [NSLocalizedDescriptionKey: errorOutput.isEmpty ? String(localized: "error.launchctl.failed") : errorOutput]))
            }
        } catch {
            return .failure(error)
        }
    }
}
