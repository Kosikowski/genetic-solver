//  ElitistReplacement.swift
//  genetic-solver
//
//  A replacement operator that never loses the fittest individuals.

public extension GeneticSolver {
    /// Returns a replacement operator that carries the `eliteCount` fittest
    /// individuals of the current population into the next one.
    ///
    /// The next population keeps the size of the new individuals: the elite
    /// come first, followed by the first `new.count - eliteCount` new
    /// individuals. Because the fittest individuals are always kept, the best
    /// fitness never gets worse from one generation to the next, and
    /// `bestElement` is the best individual found so far.
    ///
    /// It uses the fitness the solver already evaluated. On a tie, the
    /// individual that comes first in the current population is kept. An
    /// `eliteCount` of 0 gives plain generational replacement, and one larger
    /// than either population keeps as many as fit.
    ///
    /// ```swift
    /// solver.replacementOperator = GeneticSolver.elitistReplacement(eliteCount: 2)
    /// ```
    ///
    /// - Precondition: `eliteCount` is not negative.
    static func elitistReplacement(eliteCount: Int) -> ReplacementOperator<Element> {
        if eliteCount < 0 {
            fatalError("eliteCount must not be negative, but is \(eliteCount)")
        }
        return { old, new in
            let keptCount = min(eliteCount, old.count, new.count)
            guard keptCount > 0 else { return new }

            // Fittest first; on a tie, the earlier individual first.
            let ranked = old.indices.sorted { first, second in
                if old[first].fitness != old[second].fitness {
                    return old[first].fitness > old[second].fitness
                }
                return first < second
            }
            let elite = ranked.prefix(keptCount).map { old[$0] }
            return elite + new.prefix(new.count - keptCount)
        }
    }
}
