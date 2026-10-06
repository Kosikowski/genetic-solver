//  AnyRandomNumberGeneratorTests.swift
//  genetic-solverTests
//
//  Tests that AnyRandomNumberGenerator gives the standard library's random
//  functions the same numbers as the generator it wraps.

import XCTest
@testable import genetic_solver

final class AnyRandomNumberGeneratorTests: XCTestCase {
    func testForwardsEveryCallToNext() {
        var wrapped = AnyRandomNumberGenerator(SeededRandomNumberGenerator(seed: 1))
        var direct = SeededRandomNumberGenerator(seed: 1)

        XCTAssertEqual((0 ..< 1000).map { _ in wrapped.next() }, (0 ..< 1000).map { _ in direct.next() })
    }

    /// The solver and tournaments used to pass their `any RandomNumberGenerator`
    /// to these functions directly. Through the wrapper they must give the
    /// same values and draw the same number of times, so that seeded runs
    /// don't change.
    func testRandomFunctionsGiveTheSameValuesAsWithTheGeneratorItself() {
        for seed in UInt64(0) ..< 200 {
            var wrapped = AnyRandomNumberGenerator(SeededRandomNumberGenerator(seed: seed))
            var direct: any RandomNumberGenerator = SeededRandomNumberGenerator(seed: seed)

            XCTAssertEqual(randomValues(using: &wrapped), randomValues(using: &direct), "seed \(seed)")
            XCTAssertEqual(wrapped.next(), direct.next(), "seed \(seed): both drew the same number of times")
        }
    }

    /// The largest and smallest numbers a generator can return, including
    /// 0, which makes `Int.random(in:)` reject the number and draw again.
    ///
    /// `ScriptedGenerator` repeats its last value forever, so each sequence
    /// ends with `UInt64.max`, which no bound used here rejects. A value that
    /// is rejected, such as 0 or `1 << 63` for `Int.random(in: 0 ..< 1000)`,
    /// would make that call draw it again forever.
    func testRandomFunctionsGiveTheSameValuesForExtremeNumbers() {
        let sequences: [[UInt64]] = [[.max], [0, .max, 1, .max - 1, 1 << 63, .max], [0, 0, 0, .max]]
        for values in sequences {
            var wrapped = AnyRandomNumberGenerator(ScriptedGenerator(values: values))
            var direct: any RandomNumberGenerator = ScriptedGenerator(values: values)

            XCTAssertEqual(randomValues(using: &wrapped), randomValues(using: &direct), "\(values)")
        }
    }

    /// A generator that is a value is copied with the wrapper, state and all.
    func testCopyOfAValueGeneratorContinuesTheSameSequence() {
        var wrapped = AnyRandomNumberGenerator(SeededRandomNumberGenerator(seed: 3))
        _ = wrapped.next()
        var copy = wrapped

        XCTAssertEqual((0 ..< 10).map { _ in wrapped.next() }, (0 ..< 10).map { _ in copy.next() })
    }

    /// A generator that is a class is shared: the wrapper and its copies all
    /// draw from the same instance.
    func testSharesAGeneratorThatIsAClass() {
        let shared = SharedCountingGenerator(seed: 2)
        var wrapped = AnyRandomNumberGenerator(shared)
        var copy = wrapped

        _ = wrapped.next()
        _ = copy.next()
        _ = Double.random(in: 0 ..< 1, using: &wrapped)

        XCTAssertEqual(shared.draws, 3)
        XCTAssertTrue((wrapped.base as? SharedCountingGenerator) === shared)
    }

    // MARK: Helpers

    /// Values from the standard library's random functions, including those
    /// the solver and tournaments use, as text so that values of every type
    /// can be compared.
    private func randomValues(using generator: inout some RandomNumberGenerator) -> [String] {
        var values: [String] = []
        for _ in 0 ..< 20 {
            values.append("\(Double.random(in: 0 ..< 1, using: &generator))")
            values.append("\(Double.random(in: -5 ... 5, using: &generator))")
            values.append("\(Float.random(in: 0 ..< 1, using: &generator))")
            values.append("\(Int.random(in: 0 ..< 3, using: &generator))")
            values.append("\(Int.random(in: 0 ..< 1000, using: &generator))")
            values.append("\(Int.random(in: Int.min ... Int.max, using: &generator))")
            values.append("\(UInt64.random(in: 0 ... .max, using: &generator))")
            values.append("\(Bool.random(using: &generator))")
            values.append("\((0 ..< 10).randomElement(using: &generator)!)")
            values.append("\((0 ..< 10).shuffled(using: &generator))")
        }
        return values
    }
}
