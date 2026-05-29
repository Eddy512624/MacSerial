import SwiftUI

private struct FocusedSerialStoreKey: FocusedValueKey {
    typealias Value = SerialStore
}

extension FocusedValues {
    var serialStore: SerialStore? {
        get { self[FocusedSerialStoreKey.self] }
        set { self[FocusedSerialStoreKey.self] = newValue }
    }
}
