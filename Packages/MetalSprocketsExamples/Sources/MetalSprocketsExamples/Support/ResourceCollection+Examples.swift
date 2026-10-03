import Metal
import MetalSprockets

extension ResourceCollection {
    func register(_ allocations: [(any MTLAllocation)?]) throws {
        for allocation in allocations.compactMap(\.self) {
            try register(allocation)
        }
    }

    func unregister(_ allocations: [(any MTLAllocation)?]) {
        for allocation in allocations.compactMap(\.self) {
            unregister(allocation)
        }
    }

    // Removal is deferred by the collection until in-flight submissions that use the old allocations complete.
    func replace(_ old: [(any MTLAllocation)?], with new: [(any MTLAllocation)?]) throws {
        unregister(old)
        try register(new)
    }
}

/// Keeps a `ResourceCollection` in step with a view's current long-lived resources.
///
/// Call `collection(for:device:)` every frame with the resources the frame uses. Resources that appear are
/// registered, and resources that are gone are unregistered.
final class ResidencyTracker {
    private var collection: ResourceCollection?
    private var registered: [ObjectIdentifier: any MTLAllocation] = [:]

    func collection(for allocations: [(any MTLAllocation)?], device: any MTLDevice) throws -> ResourceCollection {
        let collection = try self.collection ?? ResourceCollection(device: device)
        self.collection = collection
        var current: [ObjectIdentifier: any MTLAllocation] = [:]
        for allocation in allocations.compactMap(\.self) {
            current[ObjectIdentifier(allocation)] = allocation
        }
        for (identifier, allocation) in registered where current[identifier] == nil {
            collection.unregister(allocation)
        }
        for (identifier, allocation) in current where registered[identifier] == nil {
            try collection.register(allocation)
        }
        registered = current
        return collection
    }
}
