// Graphviz.swift
// Export shader graphs to Graphviz DOT format

import ShaderGraph

extension Kind {
    /// Exports the graph rooted at this node to Graphviz DOT format.
    ///
    /// Usage:
    /// ```swift
    /// let dot = node.kind.graphviz()
    /// try dot.write(toFile: "graph.dot", atomically: true, encoding: .utf8)
    /// // Then run: dot -Tpng graph.dot -o graph.png
    /// ```
    public func graphviz(name: String = "ShaderGraph") -> String {
        var nodeID = 0
        var lines: [String] = []

        func nextID() -> String {
            let id = "n\(nodeID)"
            nodeID += 1
            return id
        }

        func visit(_ kind: Kind) -> String {
            let id = nextID()

            switch kind {
            case let .input(name, index):
                lines.append("    \(id) [label=\"input[\(index)]\\n\(name)\" shape=ellipse style=filled fillcolor=lightblue]")

            case let .function(name, inputs):
                // Shorten the name for display
                let shortName = name.replacingOccurrences(of: "shadergraph::", with: "")
                lines.append("    \(id) [label=\"\(shortName)\" shape=box style=filled fillcolor=lightyellow]")

                for input in inputs {
                    let inputID = visit(input)
                    lines.append("    \(inputID) -> \(id)")
                }
            }

            return id
        }

        let rootID = visit(self)

        var result = "digraph \(name) {\n"
        result += "    rankdir=BT\n"  // Bottom to top - inputs at bottom, output at top
        result += "    node [fontname=\"Helvetica\"]\n"
        result += "    \(rootID) [style=filled fillcolor=lightgreen]  // output\n"
        result += lines.joined(separator: "\n")
        result += "\n}\n"

        return result
    }
}

extension Node {
    /// Exports this node's graph to Graphviz DOT format.
    public func graphviz(name: String = "ShaderGraph") -> String {
        kind.graphviz(name: name)
    }
}
