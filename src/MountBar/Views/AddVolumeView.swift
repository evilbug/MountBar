import SwiftUI

struct AddVolumeView: View {
    @ObservedObject var mountManager: SMBMountManager
    @Binding var isPresented: Bool
    
    @State private var name: String = ""
    @State private var serverAddress: String = ""
    @State private var shareName: String = ""
    @State private var username: String = ""
    @State private var password: String = ""
    @State private var mountPoint: String = ""
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
                    
                    VStack(alignment: .leading, spacing: 4) {
                        TextField("Mount Point", text: $mountPoint, prompt: Text("~/SMBMounts/\(shareName.isEmpty ? "sharename" : shareName)"))
                            .textFieldStyle(.roundedBorder)
                            .onChange(of: mountPoint) { _ in validateMountPoint() }
                        if let error = validationErrors["mountPoint"] {
                            Text(error).font(.caption).foregroundColor(.red)
                        }
                    }
                    
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
        InputValidator.validateMountPoint(mountPoint.isEmpty ? "~/SMBMounts/\(shareName)" : mountPoint) &&
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
    
    private func validateMountPoint() {
        let finalPath = mountPoint.isEmpty ? "~/SMBMounts/\(shareName)" : mountPoint
        if !InputValidator.validateMountPoint(finalPath) {
            validationErrors["mountPoint"] = "Mount point must be within home directory (~/...)"
        } else {
            validationErrors.removeValue(forKey: "mountPoint")
        }
    }
    
    private func addMount() {
        let finalMountPoint = InputValidator.sanitizeMountPoint(mountPoint, defaultShareName: shareName)
        
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
