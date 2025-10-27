#if os(iOS)
import ARKit
import MetalSprocketsUI
import SwiftUI

struct ARCoachingOverlayAdaptor: View {
    let session: ARSession

    var body: some View {
        ViewAdaptor {
            ARCoachingOverlayView()
        }
        update: { (coachingOverlay: ARCoachingOverlayView) in
            coachingOverlay.session = session
        }
    }
}

#endif
