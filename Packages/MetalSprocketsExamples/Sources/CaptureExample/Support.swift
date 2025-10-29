import Foundation
import os

internal let logger: Logger? = {
    guard ProcessInfo.processInfo.environment["LOGGING"] != nil else {
        return nil
    }
    // TODO: Customize subsystem and category as needed
    return Logger()
}()
