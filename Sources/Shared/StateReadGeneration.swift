/// Orders refresh results and invalidates outstanding reads when a write starts.
/// Confined to the same actor as the state it protects.
struct StateReadGeneration {
    private var generation = 0

    mutating func beginRead() -> Int {
        invalidate()
        return generation
    }

    mutating func invalidate() {
        generation += 1
    }

    func isCurrent(_ token: Int) -> Bool {
        token == generation
    }
}
