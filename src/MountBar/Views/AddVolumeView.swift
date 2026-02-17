import SwiftUI

struct AddVolumeView: View {
    @ObservedObject var mountManager: SMBMountManager
    @Binding var isPresented: Bool
    
    @State private var name: String = ""
    @State private var serverAddress: String = ""
    @State private var shareName: String = ""
    @State private var username: String = ""
    @State private var password: String = ""
    @State private var autoMount: Bool = false

    
    @State private var validationErrors: [String: String] = [:]
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Add SMB Volume")
                .font(.title2)
                .fontWeight(.bold)
            
            Form {
                Section {
                    VStack(alignment: .leading, spacing: 4) {
                        TextField("Volume Name", text: $name)
                            .textFieldStyle(.roundedBorder)
                            .onChange(of: name) { _ in validateName() }
                        if let error = validationErrors["name"] {
                            Text(error).font(.caption).foregroundColor(.red)
                        }
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        TextField("Server Address", text: $serverAddress)
                            .textFieldStyle(.roundedBorder)
                            .onChange(of: serverAddress) { _ in validateServerAddress() }
                        if let error = validationErrors["serverAddress"] {
                            Text(error).font(.caption).foregroundColor(.red)
                        }
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        TextField("Share Name", text: $shareName)
                            .textFieldStyle(.roundedBorder)
                            .onChange(of: shareName) { _ in validateShareName() }
                        if let error = validationErrors["shareName"] {
                            Text(error).font(.caption).foregroundColor(.red)
                        }
                    }
                    
                    TextField("Username", text: $username)
                        .textFieldStyle(.roundedBorder)
                    
                    SecureField("Password", text: $password)
                        .textFieldStyle(.roundedBorder)

                    Toggle("Auto-mount", isOn: $autoMount)
                }
            }
            .formStyle(.grouped)
            
            HStack(spacing: 12) {
                Button("Cancel") {
                    isPresented = false
                }
                .keyboardShortcut(.cancelAction)
                
                Button("Add") {
                    addMount()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(!isFormValid)
            }
        }
        .padding()
        .frame(width: 400, height: 500)
    }
    
    private var isFormValid: Bool {
        !name.isEmpty && !serverAddress.isEmpty && !shareName.isEmpty && !username.isEmpty && !password.isEmpty &&
        InputValidator.validateServerAddress(serverAddress) &&
        InputValidator.validateShareName(shareName) &&
        validationErrors.isEmpty
    }
    
    private func validateName() {
        if name.isEmpty {
            validationErrors["name"] = "Name is required"
        } else {
            validationErrors.removeValue(forKey: "name")
        }
    }
    
    private func validateServerAddress() {
        if !InputValidator.validateServerAddress(serverAddress) {
            validationErrors["serverAddress"] = "Invalid server address (use hostname or IP only)"
        } else {
            validationErrors.removeValue(forKey: "serverAddress")
        }
    }
    
    private func validateShareName() {
        if !InputValidator.validateShareName(shareName) {
            validationErrors["shareName"] = "Invalid share name (no /, \\, or special characters)"
        } else {
            validationErrors.removeValue(forKey: "shareName")
        }
    }
    
    private func addMount() {
        let finalMountPoint = "~/\(shareName)"
        
        let mount = SMBMount(
            name: name,
            serverAddress: serverAddress,
            shareName: shareName,
            username: username,
            mountPoint: finalMountPoint,
            autoMount: autoMount,
            encryptedPassword: PasswordManager.shared.encryptPassword(password)
        )
        mountManager.addMount(mount)
        isPresented = false
    }

}
