import Foundation
import simd
import SwiftUI

#if os(macOS)
import AppKit
#endif

// MARK: - float4x4 Extensions (Slug-specific, no overlap with Support.swift)

extension float4x4 {
    static func rotation(angle: Float, axis: SIMD3<Float>) -> float4x4 {
        let c = cos(angle)
        let s = sin(angle)
        let t = 1 - c

        let x = axis.x, y = axis.y, z = axis.z

        return float4x4(columns: (
            SIMD4<Float>(t * x * x + c, t * x * y + s * z, t * x * z - s * y, 0),
            SIMD4<Float>(t * x * y - s * z, t * y * y + c, t * y * z + s * x, 0),
            SIMD4<Float>(t * x * z + s * y, t * y * z - s * x, t * z * z + c, 0),
            SIMD4<Float>(0, 0, 0, 1)
        ))
    }

    static func orthographic(
        left: Float,
        right: Float,
        bottom: Float,
        top: Float,
        near: Float,
        far: Float
    ) -> float4x4 {
        let sx = 2.0 / (right - left)
        let sy = 2.0 / (top - bottom)
        let sz = 1.0 / (far - near)
        let tx = -(right + left) / (right - left)
        let ty = -(top + bottom) / (top - bottom)
        let tz = -near / (far - near)

        return float4x4(columns: (
            SIMD4<Float>(sx, 0, 0, 0),
            SIMD4<Float>(0, sy, 0, 0),
            SIMD4<Float>(0, 0, sz, 0),
            SIMD4<Float>(tx, ty, tz, 1)
        ))
    }

    static func perspectiveReverseZInfinite(fovY: Float, aspect: Float, near: Float) -> float4x4 {
        let tanHalfFovY = tan(fovY / 2)
        let xs = 1 / (aspect * tanHalfFovY)
        let ys = 1 / tanHalfFovY

        return float4x4(columns: (
            SIMD4<Float>(xs, 0, 0, 0),
            SIMD4<Float>(0, ys, 0, 0),
            SIMD4<Float>(0, 0, 0, -1),
            SIMD4<Float>(0, 0, near, 0)
        ))
    }
}

// MARK: - Camera

/// A 3D orbit camera with truck, rotate, and scroll controls.
final class SlugCamera {
    var center: SIMD3<Float> = .zero
    var distance: Float = 4.0
    var yaw: Float = 0.0
    var pitch: Float = 0.0
    var fovY: Float = .pi / 4

    var eyePosition: SIMD3<Float> {
        let cosP = cos(pitch)
        let sinP = sin(pitch)
        let cosY = cos(yaw)
        let sinY = sin(yaw)
        let dir = SIMD3<Float>(cosP * sinY, sinP, cosP * cosY)
        return center + dir * distance
    }

    func viewMatrix() -> float4x4 {
        lookAt(eye: eyePosition, center: center, up: SIMD3<Float>(0, 1, 0))
    }

    func projectionMatrix(aspectRatio: Float) -> float4x4 {
        .perspectiveReverseZInfinite(fovY: fovY, aspect: aspectRatio, near: 0.01)
    }

    func frameBounds(size: CGSize, aspectRatio: Float) {
        let tanHalfFov = tan(fovY * 0.5)
        let distForHeight = Float(size.height * 0.5) / tanHalfFov
        let distForWidth = Float(size.width * 0.5) / (tanHalfFov * aspectRatio)
        distance = max(distForHeight, distForWidth) * 1.1
    }

    func scroll(delta: CGFloat) {
        distance = max(0.1, distance * Float(1.0 - delta * 0.01))
    }

    func truck(delta: CGVector) {
        let cosP = cos(pitch)
        let sinP = sin(pitch)
        let cosY = cos(yaw)
        let sinY = sin(yaw)

        let fwd = SIMD3<Float>(-cosP * sinY, -sinP, -cosP * cosY)
        let worldUp = SIMD3<Float>(0, 1, 0)
        let right = simd_normalize(simd_cross(fwd, worldUp))
        let up = simd_cross(right, fwd)

        let scale = distance * 0.002
        center = center - right * Float(delta.dx) * scale - up * Float(delta.dy) * scale
    }

    func rotate(delta: CGVector) {
        let eye = eyePosition
        let cosP = cos(pitch)
        let sinP = sin(pitch)
        let cosY = cos(yaw)
        let sinY = sin(yaw)
        let dir = SIMD3<Float>(cosP * sinY, sinP, cosP * cosY)

        var pivot = center
        var pivotDist = distance
        if abs(dir.z) > 1e-6 {
            let t = eye.z / dir.z
            if t > 0.0 {
                pivot = eye - dir * t
                pivotDist = t
            }
        }

        yaw += Float(delta.dx) * -0.005
        pitch = max(-.pi / 2 + 0.01, min(.pi / 2 - 0.01, pitch - Float(delta.dy) * 0.005))

        let cosP2 = cos(pitch)
        let sinP2 = sin(pitch)
        let cosY2 = cos(yaw)
        let sinY2 = sin(yaw)
        let newDir = SIMD3<Float>(cosP2 * sinY2, sinP2, cosP2 * cosY2)
        let newEye = pivot + newDir * pivotDist

        if abs(newDir.z) > 0.01 {
            let d = newEye.z / newDir.z
            if d > 0.1 {
                distance = d
                center = newEye - newDir * d
            }
        }
    }

    private func lookAt(eye: SIMD3<Float>, center: SIMD3<Float>, up: SIMD3<Float>) -> float4x4 {
        let f = simd_normalize(center - eye)
        let r = simd_normalize(simd_cross(f, up))
        let u = simd_cross(r, f)
        return float4x4(columns: (
            SIMD4<Float>(r.x, u.x, -f.x, 0),
            SIMD4<Float>(r.y, u.y, -f.y, 0),
            SIMD4<Float>(r.z, u.z, -f.z, 0),
            SIMD4<Float>(-simd_dot(r, eye), -simd_dot(u, eye), simd_dot(f, eye), 1)
        ))
    }
}

// MARK: - Scroll Wheel Capture (macOS)

#if os(macOS)
struct ScrollWheelCaptureView: NSViewRepresentable {
    let onScroll: (CGFloat) -> Void

    func makeNSView(context _: Context) -> ScrollWheelNSView {
        let view = ScrollWheelNSView()
        view.onScroll = onScroll
        return view
    }

    func updateNSView(_ nsView: ScrollWheelNSView, context _: Context) {
        nsView.onScroll = onScroll
    }

    class ScrollWheelNSView: NSView {
        var onScroll: ((CGFloat) -> Void)?

        override func scrollWheel(with event: NSEvent) {
            onScroll?(event.scrollingDeltaY)
        }
    }
}
#endif

// MARK: - Camera Drag Gesture Modifier

struct SlugCameraDragGestureModifier: ViewModifier {
    @Binding var camera: SlugCamera
    @State private var lastDragLocation: CGPoint?

    func body(content: Content) -> some View {
        content
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        if let last = lastDragLocation {
                            let delta = CGVector(
                                dx: value.location.x - last.x,
                                dy: value.location.y - last.y
                            )
                            #if os(macOS)
                            if NSEvent.modifierFlags.contains(.control) {
                                camera.rotate(delta: delta)
                            } else {
                                camera.truck(delta: delta)
                            }
                            #else
                            camera.truck(delta: delta)
                            #endif
                        }
                        lastDragLocation = value.location
                    }
                    .onEnded { _ in
                        lastDragLocation = nil
                    }
            )
    }
}

func rgbFromHue(_ hue: Float) -> SIMD3<Float> {
    let h = hue.truncatingRemainder(dividingBy: 1.0)
    let r = max(0.0, min(abs(h * 6 - 3) - 1, 1.0))
    let g = max(0.0, min(2 - abs(h * 6 - 2), 1.0))
    let b = max(0.0, min(2 - abs(h * 6 - 4), 1.0))
    return SIMD3(r, g, b)
}

extension View {
    func slugCameraDragGesture(camera: Binding<SlugCamera>) -> some View {
        modifier(SlugCameraDragGestureModifier(camera: camera))
    }
}
