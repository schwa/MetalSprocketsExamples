import simd

// Port of the skeleton pipeline from https://github.com/hugomarques13/TreeGenerator (plugin.py):
// scatter → grow_trunk → grow_branches → deduplicate_nodes → prune_short_branches
// → compute_depth_radii → generate_foliage. Works in the original Z-up space.

enum CrownShape: String, CaseIterable, Identifiable, Sendable {
    case sphere
    case cone

    var id: Self { self }
}

struct TreeParameters: Equatable, Sendable {
    var crownShape: CrownShape = .sphere
    var numPoints: Int = 300
    var trunkHeight: Float = 0.6
    var crownRadius: Float = 2.0
    var crownHeight: Float = 4.0

    var influenceRadius: Float = 2.0
    var killDistance: Float = 0.3
    var stepLength: Float = 0.25
    var branchBend: Float = 0.6
    var maxIterations: Int = 200

    var trunkRadius: Float = 0.21
    var branchRadius: Float = 0.04
    var tipRadius: Float = 0.01
    var baseFlare: Float = 0.5
    var branchRadiusExponent: Float = 1.2
    var trunkTaper: Float = 0.42
    var dedupThreshold: Float = 0.05

    var useFoliage = false
    var leafSize: Float = 0.2
    var leavesPerNode: Int = 7
    var leafSpacing: Float = 0.25
    var leafSpread: Float = 0.1
    var foliageDepth: Float = 0.9
    var leafTilt: Float = 0.7

    var barkColor: SIMD3<Float> = [0.25, 0.13, 0.05]
    var leafColor: SIMD3<Float> = [0.05, 0.25, 0.04]

    var seed: UInt64 = 1
}

enum TreePreset: String, CaseIterable, Identifiable, Sendable {
    case oak = "Oak"
    case pine = "Pine"
    case willow = "Willow"
    case dead = "Dead"

    var id: Self { self }

    // Values from TREE_PRESETS; anything not listed keeps the current value, as in the add-on.
    func apply(to parameters: inout TreeParameters) {
        switch self {
        case .oak:
            parameters.crownRadius = 3.0; parameters.crownHeight = 3.2; parameters.numPoints = 450
            parameters.trunkRadius = 0.26; parameters.branchRadius = 0.05; parameters.tipRadius = 0.012; parameters.baseFlare = 0.9
            parameters.trunkTaper = 0.7; parameters.branchRadiusExponent = 1.2; parameters.trunkHeight = 0.45; parameters.branchBend = 0.8
            parameters.influenceRadius = 2.6; parameters.killDistance = 0.45; parameters.stepLength = 0.28
            parameters.useFoliage = true; parameters.leafTilt = 0.7; parameters.leafSize = 0.22
            parameters.leafColor = [0.06, 0.24, 0.05]
        case .pine:
            parameters.crownShape = .cone; parameters.crownRadius = 2.0; parameters.crownHeight = 3.6; parameters.numPoints = 420
            parameters.maxIterations = 55; parameters.trunkRadius = 0.2; parameters.branchRadius = 0.035; parameters.tipRadius = 0.012
            parameters.baseFlare = 0.4; parameters.trunkTaper = 1.5; parameters.branchRadiusExponent = 1.4; parameters.trunkHeight = 0.78
            parameters.branchBend = 0.35; parameters.influenceRadius = 0.9; parameters.killDistance = 0.32; parameters.stepLength = 0.28
            parameters.useFoliage = true; parameters.leafTilt = 0.5; parameters.leafSize = 0.16
            parameters.leafColor = [0.04, 0.18, 0.06]
        case .willow:
            parameters.crownRadius = 3.2; parameters.crownHeight = 3.8; parameters.numPoints = 500
            parameters.trunkRadius = 0.22; parameters.branchRadius = 0.04; parameters.tipRadius = 0.01; parameters.baseFlare = 0.6
            parameters.trunkTaper = 0.55; parameters.branchRadiusExponent = 1.1; parameters.trunkHeight = 0.6; parameters.branchBend = 0.7
            parameters.influenceRadius = 2.4; parameters.killDistance = 0.35; parameters.stepLength = 0.25
            parameters.useFoliage = true; parameters.leafTilt = 1.0; parameters.leafSize = 0.18
            parameters.leafColor = [0.10, 0.28, 0.08]
        case .dead:
            parameters.crownRadius = 2.6; parameters.crownHeight = 3.2; parameters.numPoints = 420
            parameters.trunkRadius = 0.22; parameters.branchRadius = 0.045; parameters.tipRadius = 0.01; parameters.baseFlare = 0.7
            parameters.trunkTaper = 0.6; parameters.branchRadiusExponent = 1.3; parameters.trunkHeight = 0.5; parameters.branchBend = 0.9
            parameters.influenceRadius = 2.4; parameters.killDistance = 0.4; parameters.stepLength = 0.28
            parameters.useFoliage = false
        }
    }
}

struct TreeSkeleton {
    var positions: [SIMD3<Float>]
    /// `parents[0] == -1` for the root.
    var parents: [Int]
    var radii: [Float]
    var trunkNodeCount: Int
}

struct Leaf {
    var stem: SIMD3<Float>
    var tip: SIMD3<Float>
    var widthDirection: SIMD3<Float>
    var halfWidth: Float
}

struct SplitMix64: RandomNumberGenerator {
    var state: UInt64

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }

    mutating func uniform(_ low: Float, _ high: Float) -> Float {
        low + (high - low) * Float(Double(next() >> 11) / Double(1 << 53))
    }
}

/// Safety cap from `_MAX_SKELETON_NODES`.
private let maximumSkeletonNodes = 4_500

enum SpaceColonization {
    static func generate(_ parameters: TreeParameters) -> (skeleton: TreeSkeleton, leaves: [Leaf]) {
        var rng = SplitMix64(state: parameters.seed)

        let attractionPoints: [SIMD3<Float>]
        let crownCenter: SIMD3<Float>
        let crownZMin: Float
        let crownZMax: Float
        switch parameters.crownShape {
        case .sphere:
            crownCenter = [0, 0, parameters.crownHeight]
            attractionPoints = scatterInSphere(count: parameters.numPoints, radius: parameters.crownRadius, center: crownCenter, rng: &rng)
            crownZMin = parameters.crownHeight - parameters.crownRadius
            crownZMax = parameters.crownHeight + parameters.crownRadius
        case .cone:
            let baseZ = parameters.crownHeight - parameters.crownRadius
            let height = parameters.crownRadius * 3.2
            attractionPoints = scatterInCone(count: parameters.numPoints, baseRadius: parameters.crownRadius, height: height, baseCenter: [0, 0, baseZ], rng: &rng)
            crownZMin = baseZ
            crownZMax = baseZ + height
            crownCenter = [0, 0, baseZ + height * 0.85]
        }

        // The add-on raycasts down from the crown; with only a ground plane that lands at z = 0.
        var positions: [SIMD3<Float>] = [[crownCenter.x, crownCenter.y, 0]]
        var parents: [Int] = [-1]

        let stopZ = crownZMin + parameters.trunkHeight * (crownZMax - crownZMin)
        var trunkNodeCount = growTrunk(positions: &positions, parents: &parents, crownCenter: crownCenter, influenceRadius: parameters.influenceRadius, stepLength: parameters.stepLength, stopZ: stopZ)
        let trunkDepth = Float(trunkNodeCount) * parameters.stepLength
        growBranches(
            positions: &positions,
            parents: &parents,
            attractionPoints: attractionPoints,
            influenceRadius: parameters.influenceRadius,
            killDistance: parameters.killDistance,
            stepLength: parameters.stepLength,
            maxIterations: parameters.maxIterations,
            inertia: 1 - parameters.branchBend,
            trunkNodeCount: trunkNodeCount
        )
        (positions, parents) = deduplicateNodes(positions: positions, parents: parents, threshold: parameters.dedupThreshold)
        (positions, parents) = pruneShortBranches(positions: positions, parents: parents, trunkNodeCount: trunkNodeCount)
        trunkNodeCount = min(trunkNodeCount, positions.count - 1)

        let radii = computeDepthRadii(positions: positions, parents: parents, parameters: parameters, trunkDepth: trunkDepth, trunkNodeCount: trunkNodeCount)
        let skeleton = TreeSkeleton(positions: positions, parents: parents, radii: radii, trunkNodeCount: trunkNodeCount)
        let leaves = parameters.useFoliage ? generateFoliage(skeleton: skeleton, parameters: parameters, rng: &rng) : []
        return (skeleton, leaves)
    }

    // MARK: - Scatter

    static func scatterInSphere(count: Int, radius: Float, center: SIMD3<Float>, rng: inout SplitMix64) -> [SIMD3<Float>] {
        var points: [SIMD3<Float>] = []
        points.reserveCapacity(count)
        while points.count < count {
            let candidate = SIMD3<Float>(rng.uniform(-radius, radius), rng.uniform(-radius, radius), rng.uniform(-radius, radius))
            if length(candidate) <= radius {
                points.append(candidate + center)
            }
        }
        return points
    }

    static func scatterInCone(count: Int, baseRadius: Float, height: Float, baseCenter: SIMD3<Float>, rng: inout SplitMix64) -> [SIMD3<Float>] {
        (0..<count).map { _ in
            // Density ~ (1 - t)^2 matches the cone cross-section.
            let t = 1 - cbrt(rng.uniform(0, 1))
            let r = baseRadius * (1 - t) * sqrt(rng.uniform(0, 1))
            let angle = rng.uniform(0, 2 * .pi)
            return baseCenter + SIMD3<Float>(r * cos(angle), r * sin(angle), t * height)
        }
    }

    // MARK: - Growth

    static func growTrunk(positions: inout [SIMD3<Float>], parents: inout [Int], crownCenter: SIMD3<Float>, influenceRadius: Float, stepLength: Float, stopZ: Float) -> Int {
        let trunkStart = positions.count
        var target = crownCenter
        target.z = stopZ
        for _ in 0..<10_000 {
            // swiftlint:disable:next force_unwrapping
            let tip = positions.last!
            let difference = target - tip
            let distance = length(difference)
            if tip.z >= stopZ || distance == 0 {
                break
            }
            parents.append(positions.count - 1)
            positions.append(tip + difference / distance * stepLength)
        }

        // One more step aimed at the crown centre.
        // swiftlint:disable:next force_unwrapping
        let tip = positions.last!
        let difference = crownCenter - tip
        let distance = length(difference)
        let direction = distance > 0 ? difference / distance : SIMD3<Float>(0, 0, 1)
        parents.append(positions.count - 1)
        positions.append(tip + direction * stepLength)
        return positions.count - trunkStart
    }

    static func growBranches(positions: inout [SIMD3<Float>], parents: inout [Int], attractionPoints: [SIMD3<Float>], influenceRadius: Float, killDistance: Float, stepLength: Float, maxIterations: Int, inertia: Float, trunkNodeCount: Int) {
        var alive = [Bool](repeating: true, count: attractionPoints.count)

        if trunkNodeCount > 0 {
            let trunk = positions[0...min(trunkNodeCount, positions.count - 1)]
            let limit = killDistance * 2
            for index in attractionPoints.indices where trunk.contains(where: { distance(attractionPoints[index], $0) <= limit }) {
                alive[index] = false
            }
        }

        // Stands in for the KD-tree: nearest node within the influence radius.
        var grid = SpatialGrid(cellSize: influenceRadius)
        for (index, position) in positions.enumerated() {
            grid.insert(position, index: index)
        }
        var nodeDirections = [SIMD3<Float>](repeating: [0, 0, 1], count: positions.count)

        for _ in 0..<maxIterations {
            let aliveIndices = attractionPoints.indices.filter { alive[$0] }
            if aliveIndices.isEmpty || positions.count >= maximumSkeletonNodes {
                break
            }

            // Insertion-ordered, like the Python dict.
            var growthOrder: [Int] = []
            var growthDirections: [Int: [SIMD3<Float>]] = [:]
            for pointIndex in aliveIndices {
                let point = attractionPoints[pointIndex]
                guard let nodeIndex = grid.nearest(to: point, within: influenceRadius, positions: positions) else {
                    continue
                }
                // The trunk tip never sprouts a branch.
                if trunkNodeCount > 0, nodeIndex == trunkNodeCount {
                    continue
                }
                var direction = point - positions[nodeIndex]
                let norm = length(direction)
                if norm > 0 {
                    direction /= norm
                }
                if growthDirections[nodeIndex] == nil {
                    growthOrder.append(nodeIndex)
                    growthDirections[nodeIndex] = []
                }
                growthDirections[nodeIndex]?.append(direction)
            }
            if growthOrder.isEmpty {
                break
            }

            var newPositions: [SIMD3<Float>] = []
            for nodeIndex in growthOrder {
                if positions.count >= maximumSkeletonNodes {
                    break
                }
                // swiftlint:disable:next force_unwrapping
                let directions = growthDirections[nodeIndex]!
                var attraction = directions.reduce(.zero, +) / Float(directions.count)
                if length(attraction) > 0 {
                    attraction = normalize(attraction)
                }
                var blended = (1 - inertia) * attraction + inertia * nodeDirections[nodeIndex]
                if length(blended) > 0 {
                    blended = normalize(blended)
                }
                let newPosition = positions[nodeIndex] + blended * stepLength
                parents.append(nodeIndex)
                grid.insert(newPosition, index: positions.count)
                positions.append(newPosition)
                nodeDirections.append(blended)
                newPositions.append(newPosition)
            }

            let killSquared = killDistance * killDistance
            for pointIndex in aliveIndices {
                let point = attractionPoints[pointIndex]
                if newPositions.contains(where: { distance_squared(point, $0) <= killSquared }) {
                    alive[pointIndex] = false
                }
            }
        }
    }

    // MARK: - Cleanup

    static func deduplicateNodes(positions: [SIMD3<Float>], parents: [Int], threshold: Float) -> ([SIMD3<Float>], [Int]) {
        guard threshold > 0 else {
            return (positions, parents)
        }
        var remap = Array(positions.indices)
        for index in positions.indices.dropFirst() {
            let parentIndex = remap[parents[index]]
            if distance(positions[index], positions[parentIndex]) < threshold {
                remap[index] = parentIndex
            }
        }

        var newIndex: [Int: Int] = [:]
        var newPositions: [SIMD3<Float>] = []
        for (oldIndex, canonical) in remap.enumerated() where canonical == oldIndex {
            newIndex[oldIndex] = newPositions.count
            newPositions.append(positions[oldIndex])
        }

        var parentOf: [Int: Int] = [:]
        for index in positions.indices.dropFirst() {
            // swiftlint:disable:next force_unwrapping
            let child = newIndex[remap[index]]!
            // swiftlint:disable:next force_unwrapping
            let parent = newIndex[remap[parents[index]]]!
            if child != parent, parentOf[child] == nil {
                parentOf[child] = parent
            }
        }
        let newParents = [-1] + (1..<max(newPositions.count, 1)).map { parentOf[$0] ?? 0 }
        return (newPositions, newParents)
    }

    static func pruneShortBranches(positions: [SIMD3<Float>], parents: [Int], trunkNodeCount: Int, minimumNodes: Int = 3) -> ([SIMD3<Float>], [Int]) {
        let nodeCount = positions.count
        if trunkNodeCount + 1 >= nodeCount {
            return (positions, parents)
        }
        let children = childLists(parents: parents)
        var keep = [Bool](repeating: true, count: nodeCount)
        for trunkNode in 0...trunkNodeCount {
            for branchRoot in children[trunkNode] {
                var subtree: [Int] = []
                var stack = [branchRoot]
                while let node = stack.popLast() {
                    subtree.append(node)
                    stack.append(contentsOf: children[node])
                }
                if subtree.count < minimumNodes {
                    for node in subtree {
                        keep[node] = false
                    }
                }
            }
        }
        return compact(positions: positions, parents: parents, keep: keep)
    }

    // MARK: - Radii

    static func computeDepthRadii(positions: [SIMD3<Float>], parents: [Int], parameters: TreeParameters, trunkDepth: Float, trunkNodeCount: Int) -> [Float] {
        let nodeCount = positions.count
        var pathLength = [Float](repeating: 0, count: nodeCount)
        for index in 1..<max(nodeCount, 1) {
            let parent = parents[index]
            pathLength[index] = pathLength[parent] + distance(positions[index], positions[parent])
        }

        var radii = [Float](repeating: 0, count: nodeCount)
        let trunkEnd = trunkNodeCount
        if trunkDepth > 0 {
            for index in 0...trunkEnd {
                let normalized = simd_clamp(pathLength[index] / trunkDepth, 0, 1)
                let trunkWeight = pow(1 - normalized, parameters.trunkTaper)
                let flareExtra = parameters.trunkRadius * parameters.baseFlare * pow(1 - normalized, 4)
                radii[index] = parameters.trunkRadius * trunkWeight + parameters.branchRadius * (1 - trunkWeight) + flareExtra
            }
        } else {
            radii[0] = parameters.trunkRadius * (1 + parameters.baseFlare)
        }

        guard trunkEnd + 1 < nodeCount else {
            return radii
        }
        var localDepth = [Float](repeating: 0, count: nodeCount)
        var attachRadius = [Float](repeating: 0, count: nodeCount)
        var attachNode = [Int](repeating: 0, count: nodeCount)
        for index in (trunkEnd + 1)..<nodeCount {
            let parent = parents[index]
            let step = distance(positions[index], positions[parent])
            if parent <= trunkEnd {
                localDepth[index] = step
                attachRadius[index] = parameters.branchRadius
                attachNode[index] = parent
            } else {
                localDepth[index] = localDepth[parent] + step
                attachRadius[index] = attachRadius[parent]
                attachNode[index] = attachNode[parent]
            }
        }
        var attachMaximum: [Int: Float] = [:]
        for index in (trunkEnd + 1)..<nodeCount where localDepth[index] > attachMaximum[attachNode[index], default: 0] {
            attachMaximum[attachNode[index]] = localDepth[index]
        }
        for index in (trunkEnd + 1)..<nodeCount {
            let perNodeMaximum = max(attachMaximum[attachNode[index], default: 1], 1e-6)
            let normalized = simd_clamp(localDepth[index] / perNodeMaximum, 0, 1)
            let t = pow(normalized, parameters.branchRadiusExponent)
            let start = attachRadius[index]
            radii[index] = start + (parameters.tipRadius - start) * t
        }
        return radii
    }

    // MARK: - Foliage

    static func generateFoliage(skeleton: TreeSkeleton, parameters: TreeParameters, rng: inout SplitMix64) -> [Leaf] {
        let positions = skeleton.positions
        let parents = skeleton.parents
        let nodeCount = positions.count
        let trunkNodeCount = skeleton.trunkNodeCount
        let branchStart = trunkNodeCount + 1
        guard branchStart < nodeCount else {
            return []
        }
        let children = childLists(parents: parents)

        // Path distance from where each node's branch meets the trunk.
        var distanceFromAttach = [Float](repeating: 0, count: nodeCount)
        for index in branchStart..<nodeCount {
            let parent = parents[index]
            let step = distance(positions[index], positions[parent])
            distanceFromAttach[index] = parent <= trunkNodeCount ? step : distanceFromAttach[parent] + step
        }

        // Shortest path distance to a tip descendant.
        var depthFromTip = [Float](repeating: .infinity, count: nodeCount)
        for index in branchStart..<nodeCount where children[index].isEmpty {
            depthFromTip[index] = 0
        }
        for index in stride(from: nodeCount - 1, through: branchStart, by: -1) {
            let parent = parents[index]
            if parent >= branchStart {
                let candidate = depthFromTip[index] + distance(positions[index], positions[parent])
                if candidate < depthFromTip[parent] {
                    depthFromTip[parent] = candidate
                }
            }
        }
        guard let deepest = depthFromTip[branchStart...].filter(\.isFinite).max() else {
            return []
        }
        let depthCutoff = parameters.foliageDepth * deepest

        var placementNodes: [Int] = []
        for index in branchStart..<nodeCount where depthFromTip[index] <= depthCutoff {
            let parent = parents[index]
            if parent <= trunkNodeCount {
                placementNodes.append(index)
            } else if Int(distanceFromAttach[index] / parameters.leafSpacing) > Int(distanceFromAttach[parent] / parameters.leafSpacing) {
                placementNodes.append(index)
            }
        }

        // One placement per grid cell of size leafSpacing.
        var placedCells: Set<SIMD3<Int32>> = []
        placementNodes = placementNodes.filter { node in
            let cell = SIMD3<Int32>(floor(positions[node] / parameters.leafSpacing))
            return placedCells.insert(cell).inserted
        }

        let zUp = SIMD3<Float>(0, 0, 1)
        let xReference = SIMD3<Float>(1, 0, 0)
        var leaves: [Leaf] = []
        for node in placementNodes {
            let nodePosition = positions[node]
            for _ in 0..<parameters.leavesPerNode {
                let theta = rng.uniform(0, parameters.leafTilt * .pi)
                let phi = rng.uniform(0, 2 * .pi)
                let outward = SIMD3<Float>(sin(theta) * cos(phi), sin(theta) * sin(phi), cos(theta))

                let reference = abs(outward.z) > 0.9 ? xReference : zUp
                var widthDirection = normalize(cross(reference, outward))
                let roll = rng.uniform(0, 2 * .pi)
                let rollAxis = cross(outward, widthDirection)
                widthDirection = cos(roll) * widthDirection + sin(roll) * rollAxis

                let halfWidth = parameters.leafSize * rng.uniform(0.75, 1.25)
                let stemOffset = rng.uniform(0, parameters.leafSpread)
                let stem = nodePosition + outward * stemOffset
                leaves.append(Leaf(stem: stem, tip: stem + outward * (2 * halfWidth), widthDirection: widthDirection, halfWidth: halfWidth))
            }
        }
        return leaves
    }

    // MARK: - Helpers

    static func childLists(parents: [Int]) -> [[Int]] {
        var children = [[Int]](repeating: [], count: parents.count)
        for index in parents.indices.dropFirst() {
            children[parents[index]].append(index)
        }
        return children
    }

    private static func compact(positions: [SIMD3<Float>], parents: [Int], keep: [Bool]) -> ([SIMD3<Float>], [Int]) {
        var oldToNew = [Int](repeating: -1, count: positions.count)
        var newPositions: [SIMD3<Float>] = []
        var newParents: [Int] = []
        for index in positions.indices where keep[index] {
            oldToNew[index] = newPositions.count
            newPositions.append(positions[index])
            newParents.append(index == 0 ? -1 : oldToNew[parents[index]])
        }
        return (newPositions, newParents)
    }
}

private struct SpatialGrid {
    let cellSize: Float
    var cells: [SIMD3<Int32>: [Int]] = [:]

    init(cellSize: Float) {
        self.cellSize = cellSize
    }

    func cell(for position: SIMD3<Float>) -> SIMD3<Int32> {
        SIMD3<Int32>(floor(position / cellSize))
    }

    mutating func insert(_ position: SIMD3<Float>, index: Int) {
        cells[cell(for: position), default: []].append(index)
    }

    func nearest(to point: SIMD3<Float>, within radius: Float, positions: [SIMD3<Float>]) -> Int? {
        let center = cell(for: point)
        let radiusSquared = radius * radius
        var best: Int?
        var bestDistance = Float.infinity
        for dz in Int32(-1)...1 {
            for dy in Int32(-1)...1 {
                for dx in Int32(-1)...1 {
                    guard let indices = cells[center &+ SIMD3(dx, dy, dz)] else {
                        continue
                    }
                    for index in indices {
                        let d = distance_squared(point, positions[index])
                        if d <= radiusSquared, d < bestDistance || (d == bestDistance && index < (best ?? .max)) {
                            bestDistance = d
                            best = index
                        }
                    }
                }
            }
        }
        return best
    }
}
