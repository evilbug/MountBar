import Foundation
import Combine
import CFNetwork
import AppKit

class MountDaemon: ObservableObject {
    static let shared = MountDaemon()
    
    @Published var mountStatuses: [UUID: MountStatus] = [:]
    @Published var lastError: (mountId: UUID, message: String)?
    
    private var timer: Timer?
    private var mountManager: SMBMountManager?
    private let fileManager = FileManager.default

    private func resolveHostname(_ hostname: String) -> String {
        let host = CFHostCreateWithName(nil, hostname as CFString).takeRetainedValue()
        var resolved = DarwinBoolean(false)
        CFHostStartInfoResolution(host, .addresses, nil)
        guard let addresses = CFHostGetAddressing(host, &resolved)?.takeUnretainedValue() as? [Data], resolved.boolValue else {
            print("⚠️ DNS resolution failed for \(hostname), using original")
            return hostname
        }
        for addrData in addresses {
            let result = addrData.withUnsafeBytes { (ptr: UnsafeRawBufferPointer) -> String? in
                let sa = ptr.baseAddress!.assumingMemoryBound(to: sockaddr.self)
                if sa.pointee.sa_family == UInt8(AF_INET) {
                    var buf = [CChar](repeating: 0, count: Int(INET_ADDRSTRLEN))
                    var addr = ptr.load(as: sockaddr_in.self)
                    inet_ntop(AF_INET, &addr.sin_addr, &buf, socklen_t(INET_ADDRSTRLEN))
                    return String(cString: buf)
                } else if sa.pointee.sa_family == UInt8(AF_INET6) {
                    var buf = [CChar](repeating: 0, count: Int(INET6_ADDRSTRLEN))
                    var addr = ptr.load(as: sockaddr_in6.self)
                    inet_ntop(AF_INET6, &addr.sin6_addr, &buf, socklen_t(INET6_ADDRSTRLEN))
                    return String(cString: buf)
                }
                return nil
            }
            if let ip = result {
                print("🌐 Resolved \(hostname) -> \(ip)")
                return ip
            }
        }
        print("⚠️ DNS resolution returned no usable addresses for \(hostname), using original")
        return hostname
    }

    private func expandMountPoint(_ mountPoint: String) -> String {
        return NSString(string: mountPoint).expandingTildeInPath
    }
    
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
    
    private func volumePath(for mount: SMBMount) -> String {
        return "/Volumes/\(mount.shareName)"
    }

    private func checkIfMounted(_ mount: SMBMount) -> Bool {
        let mountPath = volumePath(for: mount)
        return fileManager.fileExists(atPath: mountPath)
    }
    
    private func performMount(_ mount: SMBMount, password: String) -> (Bool, String) {
        let resolvedServer = resolveHostname(mount.serverAddress)

        var userAllowed = CharacterSet.urlUserAllowed
        userAllowed.remove(charactersIn: "@:;")
        let encodedUsername = mount.username.addingPercentEncoding(withAllowedCharacters: userAllowed) ?? mount.username

        var passwordAllowed = CharacterSet.urlPasswordAllowed
        passwordAllowed.remove(charactersIn: "@:")
        let encodedPassword = password.addingPercentEncoding(withAllowedCharacters: passwordAllowed) ?? password
        let encodedShare = mount.shareName.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? mount.shareName

        let smbURLString = "smb://\(encodedUsername):\(encodedPassword)@\(resolvedServer)/\(encodedShare)"
        let smbURLRedacted = "smb://\(encodedUsername):***@\(resolvedServer)/\(encodedShare)"
        print("🔌 Opening \(smbURLRedacted) silently via Finder")

        guard let smbURL = URL(string: smbURLString) else {
            let errorMsg = "Invalid SMB URL"
            print("❌ \(errorMsg)")
            return (false, errorMsg)
        }

        let semaphore = DispatchSemaphore(value: 0)
        var openError: Error?

        DispatchQueue.main.async {
            let config = NSWorkspace.OpenConfiguration()
            config.activates = false
            config.hides = true
            config.addsToRecentItems = false

            NSWorkspace.shared.open([smbURL], withApplicationAt: URL(fileURLWithPath: "/System/Library/CoreServices/Finder.app"), configuration: config) { _, error in
                openError = error
                semaphore.signal()
            }
        }

        semaphore.wait()

        if let error = openError {
            let errorMsg = "Failed to open SMB URL: \(error.localizedDescription)"
            print("❌ \(errorMsg)")
            return (false, errorMsg)
        }

        print("📋 Finder open succeeded, waiting for mount to appear...")

        let volumesPath = "/Volumes/\(mount.shareName)"
        var mounted = false
        for i in 1...20 {
            Thread.sleep(forTimeInterval: 1.0)
            if fileManager.fileExists(atPath: volumesPath) {
                print("📋 Mount appeared at \(volumesPath) after \(i)s")
                mounted = true
                break
            }
        }

        if !mounted {
            let errorMsg = "Mount did not appear at \(volumesPath) within 20 seconds"
            print("❌ \(errorMsg) for \(mount.name)")
            return (false, errorMsg)
        }

        print("✅ Successfully mounted: \(mount.name) at \(volumesPath)")
        return (true, "")
    }
    
    private func performUnmount(_ mount: SMBMount) -> Bool {
        let path = volumePath(for: mount)

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/diskutil")
        process.arguments = ["unmount", path]

        let pipe = Pipe()
        process.standardError = pipe

        do {
            try process.run()
            process.waitUntilExit()

            if process.terminationStatus == 0 {
                print("✅ Successfully unmounted: \(mount.name)")
                return true
            }

            let errorData = pipe.fileHandleForReading.readDataToEndOfFile()
            if let errorOutput = String(data: errorData, encoding: .utf8) {
                print("❌ Unmount failed for \(mount.name): \(errorOutput)")
            }
            return false
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
