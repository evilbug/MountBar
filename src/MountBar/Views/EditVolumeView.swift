import SwiftUI

struct EditVolumeView: View {
    @ObservedObject var mountManager: SMBMountManager
    let mount: SMBMount
    @Binding var isPresented: Bool
    
    @State private var name: String
    @State private var serverAddress: String
    @State private var shareName: String
    @State private var username: String
    @State private var password: String
    @State private var autoMount: Bool
    @State private var showingDeleteAlert = false
    @State private var isLoaded = false
    @State private var validationErrors: [String: String] = [:]
    
    init(mountManager: SMBMountManager, mount: SMBMount, isPresented: Binding<Bool>) {
        self.mountManager = mountManager
        self.mount = mount
        self._isPresented = isPresented
        
        _name = State(initialValue: mount.name)
        _serverAddress = State(initialValue: mount.serverAddress)
        _shareName = State(initialValue: mount.shareName)
        _username = State(initialValue: mount.username)
        _autoMount = State(initialValue: mount.autoMount)

        
        let savedPassword = PasswordManager.shared.getPassword(from: mount) ?? ""
        _password = State(initialValue: savedPassword)
    }
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Edit SMB Volume")
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
                Button("Delete", role: .destructive) {
                    showingDeleteAlert = true
                }
                .buttonStyle(.bordered)
                
                Spacer()
                
                Button("Cancel") {
                    isPresented = false
                }
                .keyboardShortcut(.cancelAction)
                
                Button("Save") {
                    saveChanges()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(!isFormValid)
            }
        }
        .padding()
        .frame(width: 400, height: 500)
        .alert("Delete Mount", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                deleteMount()
            }
        } message: {
            Text("Are you sure you want to delete '\(mount.name)'? This action cannot be undone.")
        }
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
    
    private func saveChanges() {
        let finalMountPoint = "~/\(shareName)"
        
        var updatedMount = mount
        updatedMount.name = name
        updatedMount.serverAddress = serverAddress
        updatedMount.shareName = shareName
        updatedMount.username = username
        updatedMount.mountPoint = finalMountPoint
        updatedMount.autoMount = autoMount
        updatedMount.encryptedPassword = PasswordManager.shared.encryptPassword(password)
        
        mountManager.updateMount(updatedMount)
        isPresented = false
    }
    
    private func deleteMount() {
        mountManager.deleteMount(mount)
        isPresented = false
    }

}
