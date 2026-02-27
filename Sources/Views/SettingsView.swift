import Models
import Storage
import SwiftUI

public struct SettingsView: View {
    @State private var apiKey: String = ""
    @State private var selectedPartTypes: Set<PartType> = [.tenor]
    @State private var showingAPIKey = false
    @State private var saveStatus: String?

    private let settings = SettingsStorage()

    public init() {}

    public var body: some View {
        Form {
            apiKeySection
            partSelectionSection
            aboutSection
        }
        .formStyle(.grouped)
        .navigationTitle("Settings")
        .task { await loadSettings() }
    }

    private var apiKeySection: some View {
        Section {
            HStack {
                if showingAPIKey {
                    TextField("OpenRouter API Key", text: $apiKey)
                        .textFieldStyle(.roundedBorder)
                } else {
                    SecureField("OpenRouter API Key", text: $apiKey)
                        .textFieldStyle(.roundedBorder)
                }
                Button {
                    showingAPIKey.toggle()
                } label: {
                    Image(
                        systemName: showingAPIKey
                            ? "eye.slash" : "eye"
                    )
                }
                .buttonStyle(.plain)
            }

            Button("Save API Key") {
                Task { await saveAPIKey() }
            }
            .disabled(apiKey.isEmpty)

            if let status = saveStatus {
                Text(status)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        } header: {
            Text("OpenRouter API Key")
        } footer: {
            Text(
                "Get your API key at openrouter.ai. "
                    + "Your key is stored securely in the system Keychain."
            )
        }
    }

    private var partSelectionSection: some View {
        Section {
            let vocalTypes: [PartType] = [
                .soprano, .alto, .tenor, .bass,
                .soprano1, .soprano2, .alto1, .alto2,
                .tenor1, .tenor2, .bass1, .bass2,
                .descant,
            ]
            ForEach(vocalTypes, id: \.self) { partType in
                Toggle(
                    partType.displayName,
                    isOn: Binding(
                        get: { selectedPartTypes.contains(partType) },
                        set: { isOn in
                            if isOn {
                                selectedPartTypes.insert(partType)
                            } else {
                                selectedPartTypes.remove(partType)
                            }
                            Task { await savePartTypes() }
                        }
                    )
                )
            }
        } header: {
            Text("I Sing")
        } footer: {
            Text(
                "Select the part(s) you sing. "
                    + "Selected parts are highlighted and played louder."
            )
        }
    }

    private var aboutSection: some View {
        Section("About") {
            LabeledContent("Version", value: "0.1.0")
            LabeledContent("License", value: "MIT")
        }
    }

    private func loadSettings() async {
        if let key = try? await settings.getAPIKey(), !key.isEmpty {
            apiKey = key
        }
        let types = await settings.getUserPartTypes()
        selectedPartTypes = Set(types)
    }

    private func saveAPIKey() async {
        do {
            try await settings.setAPIKey(apiKey)
            saveStatus = "API key saved"
        } catch {
            saveStatus = "Failed to save: \(error.localizedDescription)"
        }
    }

    private func savePartTypes() async {
        await settings.setUserPartTypes(Array(selectedPartTypes))
    }
}
