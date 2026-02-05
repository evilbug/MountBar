import Foundation
import Combine

class MountDaemon: ObservableObject {
    static let shared = MountDaemon()
    
    @Published var mountStatuses: [UUID: MountStatus] = [:]
    @Published var lastError: (mountId: UUID, message: String)?
    
    private var timer: Timer?
    private var mountManager: SMBMountManager?
    private let fileManager = FileManager.default
    
    private init() {}
    
    func start(with mountManager: SMBMountManager) {
        self.mountManager = mountManager
        
        timer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            self?.checkAndMountVolumes()
        }
        
        checkAndMountVolumes()
    }
    
    func stop() {
        timer?.invalidate()
        timer = nil
    }
    
    func mountVolume(_ mount: SMBMount, isAutoMount: Bool = false) {
        guard let password = PasswordManager.shared.getPassword(from: mount) else {
            let errorMsg = "No password found for mount: \(mount.name)"
            print("❌ \(errorMsg)")
            updateMountStatus(mount.id, status: .failed)
            if !isAutoMount {
                DispatchQueue.main.async {
                    self.lastError = (mount.id, errorMsg)
                }
            }
            return
        }
        
        updateMountStatus(mount.id, status: .mounting)
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            if !isAutoMount {
                Thread.sleep(forTimeInterval: 2.0)
            }
            
            var (success, errorMessage) = self?.performMount(mount, password: password) ?? (false, "Unknown error")
            
            if !success && (errorMessage.contains("No route to host") || errorMessage.contains("Operation not permitted")) {
                if !isAutoMount {
                    print("⏳ Retrying mount after permission delay...")
                }
                Thread.sleep(forTimeInterval: 3.0)
                (success, errorMessage) = self?.performMount(mount, password: password) ?? (false, "Unknown error")
            }
            
            DispatchQueue.main.async {
                self?.updateMountStatus(mount.id, status: success ? .mounted : .failed)
                self?.updateMountManagerStatus(mount.id, status: success ? .mounted : .failed)
                if !success && !isAutoMount {
                    self?.lastError = (mount.id, errorMessage)
                }
            }
        }
    }
    
    func unmountVolume(_ mount: SMBMount) {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let success = self?.performUnmount(mount) ?? false
            
            DispatchQueue.main.async {
                self?.updateMountStatus(mount.id, status: success ? .unmounted : .mounted)
                self?.updateMountManagerStatus(mount.id, status: success ? .unmounted : .mounted)
            }
        }
    }
    
    private func checkAndMountVolumes() {
        guard let mountManager = mountManager else { return }
        
        for mount in mountManager.mounts {
            let isMounted = checkIfMounted(mount)
            let currentStatus = mountStatuses[mount.id] ?? .unmounted
            
            if isMounted {
                if currentStatus != .mounted {
                    updateMountStatus(mount.id, status: .mounted)
                    updateMountManagerStatus(mount.id, status: .mounted)
                }
            } else {
                if currentStatus == .mounted {
                    updateMountStatus(mount.id, status: .unmounted)
                    updateMountManagerStatus(mount.id, status: .unmounted)
                }
                
                if mount.autoMount && (currentStatus == .unmounted || currentStatus == .failed) {
                    if currentStatus == .unmounted {
                        print("🔄 Auto-mounting: \(mount.name)")
                    }
                    mountVolume(mount, isAutoMount: true)
                }
            }
        }
    }
    
    private func checkIfMounted(_ mount: SMBMount) -> Bool {
        let expandedPath = NSString(string: mount.mountPoint).expandingTildeInPath
        
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/sbin/mount")
        
        let pipe = Pipe()
        process.standardOutput = pipe
        
        do {
            try process.run()
            process.waitUntilExit()
            
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let output = String(data: data, encoding: .utf8) {
                for line in output.components(separatedBy: "\n") {
                    if line.contains(expandedPath) && line.contains("smbfs") {
                        return true
                    }
                }
            }
        } catch {
            print("❌ Error checking mount status: \(error)")
        }
        
        return false
    }
    
    private func performMount(_ mount: SMBMount, password: String) -> (Bool, String) {
        let expandedPath = NSString(string: mount.mountPoint).expandingTildeInPath
        
        guard let homeDir = fileManager.homeDirectoryForCurrentUser.path as String? else {
            let errorMsg = "Could not determine user home directory"
            print("❌ \(errorMsg)")
            return (false, errorMsg)
        }
        
        if !expandedPath.hasPrefix(homeDir) {
            let errorMsg = "Mount point must be within user home directory (\(homeDir)). Current path: \(expandedPath)"
            print("❌ \(errorMsg)")
            return (false, errorMsg)
        }
        
        // Canonicalize path to prevent traversal
        let resolvedPath = (expandedPath as NSString).resolvingSymlinksInPath
        let resolvedHome = (homeDir as NSString).resolvingSymlinksInPath
        if !resolvedPath.hasPrefix(resolvedHome) {
            let errorMsg = "Mount point resolved outside home directory"
            print("❌ \(errorMsg): \(resolvedPath)")
            return (false, errorMsg)
        }
        
        if fileManager.fileExists(atPath: expandedPath) {
            print("⚠️ Mount point already exists at \(expandedPath), attempting to unmount and clean up")
            _ = performUnmount(mount)
            Thread.sleep(forTimeInterval: 0.5)
            
            do {
                try fileManager.removeItem(atPath: expandedPath)
                print("🗑️ Removed existing mount point directory")
            } catch {
                print("⚠️ Could not remove existing directory: \(error.localizedDescription)")
            }
        }
        
        let parentPath = (expandedPath as NSString).deletingLastPathComponent
        if !fileManager.fileExists(atPath: parentPath) {
            do {
                try fileManager.createDirectory(atPath: parentPath, withIntermediateDirectories: true, attributes: nil)
                print("📁 Created parent directory: \(parentPath)")
            } catch {
                let errorMsg = "Failed to create parent directory \(parentPath): \(error.localizedDescription)"
                print("❌ \(errorMsg)")
                return (false, errorMsg)
            }
        }
        
        do {
            try fileManager.createDirectory(atPath: expandedPath, withIntermediateDirectories: false, attributes: nil)
            print("📁 Created mount point: \(expandedPath)")
        } catch {
            let errorMsg = "Failed to create mount point \(expandedPath): \(error.localizedDescription)"
            print("❌ \(errorMsg)")
            return (false, errorMsg)
        }
        
        let smbURL = "//\(mount.username)@\(mount.serverAddress)/\(mount.shareName)"
        
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/sbin/mount_smbfs")
        process.arguments = ["-N", smbURL, expandedPath]
        
        // Pass password via stdin using echo pipe (avoids command-line exposure)
        let inputPipe = Pipe()
        process.standardInput = inputPipe
        if let passwordData = (password + "\n").data(using: .utf8) {
            inputPipe.fileHandleForWriting.write(passwordData)
            try? inputPipe.fileHandleForWriting.close()
        }
        
        let errorPipe = Pipe()
        let outputPipe = Pipe()
        process.standardError = errorPipe
        process.standardOutput = outputPipe
        
        do {
            try process.run()
            process.waitUntilExit()
            
            let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
            
            if process.terminationStatus != 0 {
                var errorMessage = "Unknown error"
                if let errorOutput = String(data: errorData, encoding: .utf8), !errorOutput.isEmpty {
                    errorMessage = errorOutput.trimmingCharacters(in: .whitespacesAndNewlines)
                }
                print("❌ Mount failed for \(mount.name): \(errorMessage)")
                return (false, errorMessage)
            }
            
            Thread.sleep(forTimeInterval: 1.0)
            
            let volumeExists = fileManager.fileExists(atPath: expandedPath)
            
            if volumeExists {
                print("✅ Successfully mounted: \(mount.name) at \(expandedPath)")
                return (true, "")
            } else {
                let errorMsg = "Mount command succeeded but volume not found at \(expandedPath)"
                print("❌ \(errorMsg) for \(mount.name)")
                return (false, errorMsg)
            }
        } catch {
            let errorMsg = "Error mounting \(mount.name): \(error.localizedDescription)"
            print("❌ \(errorMsg)")
            return (false, errorMsg)
        }
    }
    
    private func performUnmount(_ mount: SMBMount) -> Bool {
        let volumePath = NSString(string: mount.mountPoint).expandingTildeInPath
        
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/diskutil")
        process.arguments = ["unmount", volumePath]
        
        let pipe = Pipe()
        process.standardError = pipe
        
        do {
            try process.run()
            process.waitUntilExit()
            
            if process.terminationStatus == 0 {
                print("✅ Successfully unmounted: \(mount.name)")
                return true
            } else {
                let errorData = pipe.fileHandleForReading.readDataToEndOfFile()
                if let errorOutput = String(data: errorData, encoding: .utf8) {
                    print("❌ Unmount failed for \(mount.name): \(errorOutput)")
                }
                return false
            }
        } catch {
            print("❌ Error unmounting \(mount.name): \(error)")
            return false
        }
    }
    
    private func updateMountStatus(_ mountID: UUID, status: MountStatus) {
        DispatchQueue.main.async { [weak self] in
            self?.mountStatuses[mountID] = status
        }
    }
    
    private func updateMountManagerStatus(_ mountID: UUID, status: MountStatus) {
        guard let mountManager = mountManager else { return }
        
        if let index = mountManager.mounts.firstIndex(where: { $0.id == mountID }) {
            mountManager.mounts[index].status = status
        }
    }
}
