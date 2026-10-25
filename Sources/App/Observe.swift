import Observation

/// Calls `onChange` with the new value each time `value` changes.
/// A stand-in for `Observations`, which needs macOS 26.
@MainActor
func observe<T>(_ value: @escaping @MainActor () -> T, onChange: @escaping @MainActor (T) -> Void) {
    withObservationTracking {
        _ = value()
    } onChange: {
        // Fires before the property is set; read the new value on the next turn.
        Task { @MainActor in
            onChange(value())
            observe(value, onChange: onChange)
        }
    }
}
