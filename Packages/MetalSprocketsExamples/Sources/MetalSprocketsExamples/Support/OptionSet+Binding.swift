import SwiftUI

extension Binding where Value: OptionSet, Value.Element == Value {
    func bound(_ option: Value) -> Binding<Bool> {
        Binding<Bool>(
            get: { wrappedValue.contains(option) },
            set: { isOn in
                if isOn {
                    wrappedValue.insert(option)
                } else {
                    wrappedValue.remove(option)
                }
            }
        )
    }
}
