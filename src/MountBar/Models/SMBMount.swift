import Foundation

enum MountStatus: String, Codable {
    case unmounted
    case mounting
    case mounted
    case failed
}

struct SMBMount: Identifiable, Codable {
    var id = UUID()
    var name: String
    var serverAddress: String
    var shareName: String
    var username: String
    var mountPoint: String
    var autoMount: Bool
    var createdAt: Date
    var status: MountStatus = .unmounted
    var encryptedPassword: Data?
    
    init(name: String, serverAddress: String, shareName: String, username: String, mountPoint: String, autoMount: Bool = false, encryptedPassword: Data? = nil) {
        self.name = name
        self.serverAddress = serverAddress
        self.shareName = shareName
        self.username = username
        self.mountPoint = mountPoint
        self.autoMount = autoMount
        self.createdAt = Date()
        self.status = .unmounted
        self.encryptedPassword = encryptedPassword
    }
    
    var smbURL: String {
        "smb://\(username)@\(serverAddress)/\(shareName)"
    }
}

struct InputValidator {
    
    static func validateServerAddress(_ address: String) -> Bool {
        // Allow hostnames (alphanumeric, hyphens, dots) or IP addresses
        // Reject any characters that could be used for command injection
        let allowedCharacters = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789.-")
        
        // Check for command injection patterns
        let forbiddenPatterns = [";", "&", "|", "`", "$", "(", ")", "{", "}", "<", ">", "\\", "'", "\"", " ", "\t", "\n"]
        for pattern in forbiddenPatterns {
            if address.contains(pattern) {
                return false
            }
        }
        
        // Verify all characters are allowed
        if address.rangeOfCharacter(from: allowedCharacters.inverted) != nil {
            return false
        }
        
        // Must not be empty and reasonable length
        guard !address.isEmpty, address.count <= 253 else {
            return false
        }
        
        // Must not start or end with hyphen or dot
        if address.hasPrefix("-") || address.hasSuffix("-") || 
           address.hasPrefix(".") || address.hasSuffix(".") {
            return false
        }
        
        return true
    }
    
    static func validateShareName(_ name: String) -> Bool {
        // SMB share names: alphanumeric, spaces, and limited special chars
        // Reject path traversal and command injection patterns
        let forbiddenPatterns = ["..", "/", "\\", ";", "&", "|", "`", "$", "<", ">", "'", "\"", "\t", "\n"]
        for pattern in forbiddenPatterns {
            if name.contains(pattern) {
                return false
            }
        }
        
        // Must not be empty and reasonable length
        guard !name.isEmpty, name.count <= 255 else {
            return false
        }
        
        return true
    }
    
    static func validateMountPoint(_ path: String) -> Bool {
        // Must start with ~ (home directory)
        guard path.hasPrefix("~") else {
            return false
        }
        
        // Reject path traversal patterns
        let expandedPath = NSString(string: path).expandingTildeInPath
        let resolvedPath = (expandedPath as NSString).resolvingSymlinksInPath
        
        // Reject hidden files/dirs in path (starting with .)
        let pathComponents = resolvedPath.components(separatedBy: "/")
        for component in pathComponents {
            if component.hasPrefix(".") && component != "." && component != ".." {
                if component.hasPrefix(".") {
                    return false
                }
            }
        }
        
        return true
    }
    
    static func sanitizeMountPoint(_ path: String, defaultShareName: String) -> String {
        var sanitizedPath = path
        
        // If empty, use default
        if sanitizedPath.isEmpty {
            sanitizedPath = "~/SMBMounts/\(defaultShareName)"
        }
        
        // Normalize path separators
        sanitizedPath = sanitizedPath.replacingOccurrences(of: "\\", with: "/")
        
        // Remove any null bytes
        sanitizedPath = sanitizedPath.replacingOccurrences(of: "\0", with: "")
        
        return sanitizedPath
    }
}
