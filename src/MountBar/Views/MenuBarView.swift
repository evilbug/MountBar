import SwiftUI

struct MenuBarView: View {
    @ObservedObject var mountManager: SMBMountManager
    @ObservedObject var mountDaemon: MountDaemon
    @State private var showingAddVolume = false
    @State private var showingEditVolume = false
    @State private var editingMountId: UUID?
    @State private var showingErrorAlert = false
    @State private var errorMessage = ""
    
    var body: some View {
        VStack(spacing: 0) {
            if mountManager.mounts.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "externaldrive.badge.questionmark")
                        .font(.system(size: 40))
                        .foregroundColor(.secondary)
                    Text("No SMB Mounts")
                        .font(.headline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding()
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(mountManager.mounts) { mount in
                            MountItemView(
                                mount: mount,
                                onDelete: {
                                    mountManager.deleteMount(mount)
                                },
                                onMount: {
                                    mountDaemon.mountVolume(mount)
                                },
                                onUnmount: {
                                    mountDaemon.unmountVolume(mount)
                                },
                                onEdit: {
                                    editingMountId = mount.id
                                    showingEditVolume = true
                                }
                            )
                        }
                    }
                    .padding()
                }
            }
            
            Divider()
            
            VStack(spacing: 8) {
                Button(action: {
                    showingAddVolume = true
                }) {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                        Text("Add Volume")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                
                Button(action: {
                    NSApplication.shared.terminate(nil)
                }) {
                    HStack {
                        Image(systemName: "power")
                        Text("Quit")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }
            .padding()
        }
        .frame(width: 300, height: 400)
        .sheet(isPresented: $showingAddVolume) {
            AddVolumeView(mountManager: mountManager, isPresented: $showingAddVolume)
        }
        .sheet(isPresented: $showingEditVolume) {
            if let mountId = editingMountId,
               let mount = mountManager.mounts.first(where: { $0.id == mountId }) {
                EditVolumeView(mountManager: mountManager, mount: mount, isPresented: $showingEditVolume)
            }
        }
        .alert("Mount Error", isPresented: $showingErrorAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
        .onDisappear {
            mountDaemon.stop()
        }
        .onReceive(mountDaemon.$lastError) { error in
            if let error = error {
                errorMessage = error.message
                showingErrorAlert = true
            }
        }
    }
}

struct MountItemView: View {
    let mount: SMBMount
    let onDelete: () -> Void
    let onMount: () -> Void
    let onUnmount: () -> Void
    let onEdit: () -> Void
    
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                statusIndicator
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(mount.name)
                        .font(.headline)
                    Text("smb://\(mount.serverAddress)/\(mount.shareName)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                
                Spacer()
                
                Button(action: onEdit) {
                    Image(systemName: "pencil")
                        .foregroundColor(.blue)
                }
                .buttonStyle(.plain)
            }
            
            HStack(spacing: 8) {
                if mount.status == .mounted {
                    Button("Open Folder") {
                        let path = "/Volumes/\(mount.shareName)"
                        NSWorkspace.shared.open(URL(fileURLWithPath: path))
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    
                    Button("Unmount") {
                        onUnmount()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                } else if mount.status == .mounting {
                    ProgressView()
                        .scaleEffect(0.7)
                        .frame(height: 20)
                } else {
                    Button("Mount") {
                        onMount()
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                }
                
                Spacer()
                
                Text(statusText)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(8)
        .background(backgroundColor)
        .cornerRadius(6)
    }
    
    private var statusIndicator: some View {
        Circle()
            .fill(statusColor)
            .frame(width: 8, height: 8)
    }
    
    private var statusColor: Color {
        switch mount.status {
        case .mounted:
            return .green
        case .mounting:
            return .orange
        case .unmounted:
            return .gray
        case .failed:
            return .red
        }
    }
    
    private var statusText: String {
        switch mount.status {
        case .mounted:
            return "Connected"
        case .mounting:
            return "Connecting..."
        case .unmounted:
            return "Not mounted"
        case .failed:
            return "Failed"
        }
    }
    
    private var backgroundColor: Color {
        switch mount.status {
        case .mounted:
            return Color.green.opacity(0.1)
        case .failed:
            return Color.red.opacity(0.1)
        default:
            return Color.secondary.opacity(0.1)
        }
    }
}
