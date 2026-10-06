//  EvaluatedElement.swift
//  genetic-solver
//
//  An individual together with its fitness, evaluated once.

// MARK: - EvaluatedElement

/// An individual together with its fitness, which is evaluated once, when
/// the value is created.
///
/// The solver evaluates each individual once and passes the result along:
/// the population, the selection and replacement operators, the termination
/// check and `bestElement` all use `EvaluatedElement`, so reading `fitness`
/// costs nothing, however often it is read.
///
/// To add an individual of your own, for example in a replacement operator,
/// create one with `EvaluatedElement(_:)`, which calls `fitness()` once.
public struct EvaluatedElement<Element: FitnessEvaluatable> {
    // MARK: Properties

    /// The individual.
    public let element: Element

    /// The individual's fitness: the value `element.fitness()` returned when
    /// this value was created.
    public let fitness: Element.Fitness

    // MARK: Lifecycle

    /// Evaluates `element.fitness()` once and keeps the result.
    public init(_ element: Element) {
        self.element = element
        fitness = element.fitness()
    }
}

// MARK: Equatable

extension EvaluatedElement: Equatable where Element: Equatable {}

// MARK: Hashable

extension EvaluatedElement: Hashable where Element: Hashable, Element.Fitness: Hashable {}

// MARK: Sendable

extension EvaluatedElement: Sendable where Element: Sendable, Element.Fitness: Sendable {}
