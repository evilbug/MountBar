import Foundation
import Combine

class SMBMountManager: ObservableObject {
    @Published var mounts: [SMBMount] = []
    
    private let userDefaults = UserDefaults.standard
    private let mountsKey = "savedSMBMounts"
    
    init() {
        loadMounts()
    }
    
    func addMount(_ mount: SMBMount) {
        mounts.append(mount)
        saveMounts()
    }
    
    func deleteMount(at offsets: IndexSet) {
        mounts.remove(atOffsets: offsets)
        saveMounts()
    }
    
    func deleteMount(_ mount: SMBMount) {
        mounts.removeAll { $0.id == mount.id }
        saveMounts()
    }
    
    func updateMount(_ mount: SMBMount) {
        if let index = mounts.firstIndex(where: { $0.id == mount.id }) {
            mounts[index] = mount
            saveMounts()
        }
    }
    
    private func saveMounts() {
        if let encoded = try? JSONEncoder().encode(mounts) {
            userDefaults.set(encoded, forKey: mountsKey)
        }
    }
    
    private func loadMounts() {
        if let data = userDefaults.data(forKey: mountsKey),
           let decoded = try? JSONDecoder().decode([SMBMount].self, from: data) {
            mounts = decoded
        }
    }
}
