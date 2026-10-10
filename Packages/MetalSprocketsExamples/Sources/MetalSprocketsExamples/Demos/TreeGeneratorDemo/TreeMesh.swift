import MetalSprocketsExampleShaders
import simd

/// Triangle soup for the tree, in Y-up world space.
/// Replaces the add-on's Blender Skin + Subdivision modifiers with tapered tubes.
struct TreeMesh: Sendable {
    var vertices: [TreeVertex] = []
    var nodeCount = 0
    var leafCount = 0

    static func build(skeleton: TreeSkeleton, leaves: [Leaf], parameters: TreeParameters, sides: Int = 8) -> Self {
        var mesh = Self()
        mesh.nodeCount = skeleton.positions.count
        mesh.leafCount = leaves.count
        mesh.addBark(skeleton: skeleton, color: parameters.barkColor, sides: sides)
        mesh.addLeaves(leaves, color: parameters.leafColor, seed: parameters.seed)
        return mesh
    }

    /// Z-up (Blender) to Y-up (Metal world).
    private static func yUp(_ v: SIMD3<Float>) -> SIMD3<Float> {
        [v.x, v.z, -v.y]
    }

    private struct Ring {
        var center: SIMD3<Float>
        var tangent: SIMD3<Float>
        var axis: SIMD3<Float>
        var radius: Float
    }

    private mutating func addBark(skeleton: TreeSkeleton, color: SIMD3<Float>, sides: Int) {
        let positions = skeleton.positions
        let parents = skeleton.parents
        let count = positions.count
        guard count > 1 else {
            return
        }
        let children = SpaceColonization.childLists(parents: parents)

        // The continuation child is the one carrying the largest subtree.
        var subtreeSize = [Int](repeating: 1, count: count)
        for index in stride(from: count - 1, to: 0, by: -1) where parents[index] < index {
            subtreeSize[parents[index]] += subtreeSize[index]
        }
        let primaryChild: [Int?] = children.map { $0.max { subtreeSize[$0] < subtreeSize[$1] } }

        func direction(_ from: Int, _ to: Int) -> SIMD3<Float> {
            let d = positions[to] - positions[from]
            return length(d) > 0 ? normalize(d) : [0, 0, 1]
        }

        // Smooth tangents and parallel-transported ring axes, so rings don't twist.
        var rings: [Ring] = []
        rings.reserveCapacity(count)
        for index in 0..<count {
            let parent = parents[index]
            var tangent: SIMD3<Float>
            switch (parent >= 0 ? parent : nil, primaryChild[index]) {
            case let (parent?, child?):
                tangent = direction(parent, index) + direction(index, child)
            case let (parent?, nil):
                tangent = direction(parent, index)
            case let (nil, child?):
                tangent = direction(index, child)
            case (nil, nil):
                tangent = [0, 0, 1]
            }
            tangent = length(tangent) > 0 ? normalize(tangent) : [0, 0, 1]
            let previousAxis = (parent >= 0 && parent < index) ? rings[parent].axis : (abs(tangent.x) > 0.9 ? SIMD3<Float>(0, 1, 0) : SIMD3<Float>(1, 0, 0))
            rings.append(Ring(center: positions[index], tangent: tangent, axis: Self.transport(previousAxis, onto: tangent), radius: skeleton.radii[index]))
        }

        for index in 1..<count {
            let parent = parents[index]
            let end = rings[index]
            let start: Ring
            if primaryChild[parent] == index {
                start = rings[parent]
            } else {
                // Side branch: start a fresh ring inside the parent tube, aimed along the branch.
                let tangent = direction(parent, index)
                start = Ring(center: positions[parent], tangent: tangent, axis: Self.transport(rings[parent].axis, onto: tangent), radius: end.radius)
            }
            addTube(from: start, to: end, sides: sides, color: color)
        }
    }

    private static func transport(_ axis: SIMD3<Float>, onto tangent: SIMD3<Float>) -> SIMD3<Float> {
        let projected = axis - dot(axis, tangent) * tangent
        if length(projected) > 1e-4 {
            return normalize(projected)
        }
        let fallback: SIMD3<Float> = abs(tangent.x) > 0.9 ? [0, 1, 0] : [1, 0, 0]
        return normalize(fallback - dot(fallback, tangent) * tangent)
    }

    private mutating func addTube(from start: Ring, to end: Ring, sides: Int, color: SIMD3<Float>) {
        // Re-align the end ring's axis with the start ring to avoid a twisted segment.
        let endAxis = Self.transport(start.axis, onto: end.tangent)
        func ringVertex(_ ring: Ring, axis: SIMD3<Float>, _ k: Int) -> TreeVertex {
            let angle = Float(k) / Float(sides) * 2 * .pi
            let bitangent = cross(ring.tangent, axis)
            let normal = cos(angle) * axis + sin(angle) * bitangent
            return TreeVertex(position: Self.yUp(ring.center + normal * ring.radius), normal: Self.yUp(normal), color: color)
        }
        for k in 0..<sides {
            let a0 = ringVertex(start, axis: start.axis, k)
            let a1 = ringVertex(start, axis: start.axis, k + 1)
            let b0 = ringVertex(end, axis: endAxis, k)
            let b1 = ringVertex(end, axis: endAxis, k + 1)
            vertices += [a0, b0, a1, a1, b0, b1]
        }
    }

    private mutating func addLeaves(_ leaves: [Leaf], color: SIMD3<Float>, seed: UInt64) {
        // Separate stream so tinting doesn't disturb the growth RNG.
        var rng = SplitMix64(state: seed ^ 0xA5A5_A5A5)
        for leaf in leaves {
            let outward = normalize(leaf.tip - leaf.stem)
            let normal = Self.yUp(cross(outward, leaf.widthDirection))
            let tint = color * rng.uniform(0.75, 1.3)
            let width = leaf.widthDirection * leaf.halfWidth
            let corners = [leaf.stem - width, leaf.tip - width, leaf.tip + width, leaf.stem + width].map { corner in
                TreeVertex(position: Self.yUp(corner), normal: normal, color: tint)
            }
            vertices += [corners[0], corners[1], corners[2], corners[0], corners[2], corners[3]]
        }
    }
}
