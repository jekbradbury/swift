// SWIFT_ENABLE_TENSORFLOW
// RUN: %target-swift-frontend -typecheck -verify %s

struct Empty : Differentiable {}

struct Simple : AdditiveArithmetic, Differentiable {
  var w: Float
  var b: Float
}
let simple = Simple(w: 1, b: 1)
assert(simple.moved(along: simple) == simple + simple)
assert(simple.tangentVector(from: simple) == simple)

// Test type with mixed members.
struct Mixed : AdditiveArithmetic, Differentiable {
  var simple: Simple
  var float: Float
}
let mixed = Mixed(simple: simple, float: 1)
assert(mixed.moved(along: mixed) == mixed + mixed)
assert(mixed.tangentVector(from: mixed) == mixed)

// Test type with manual definition of vector space types to `Self`.
struct VectorSpacesEqualSelf : AdditiveArithmetic, Differentiable {
  var w: Float
  var b: Float
  typealias TangentVector = VectorSpacesEqualSelf
  typealias CotangentVector = VectorSpacesEqualSelf
}

// Test generic type with vector space types to `Self`.
struct GenericVectorSpacesEqualSelf<T> : AdditiveArithmetic, Differentiable
  where T : AdditiveArithmetic, T : Differentiable,
        T == T.TangentVector, T == T.CotangentVector
{
  var w: T
  var b: T
}
let genericSame = GenericVectorSpacesEqualSelf<Double>(w: 1, b: 1)
assert(genericSame.moved(along: genericSame) == genericSame + genericSame)
assert(genericSame.tangentVector(from: genericSame) == genericSame)

// Test nested type.
struct Nested : AdditiveArithmetic, Differentiable {
  var simple: Simple
  var mixed: Mixed
  var generic: GenericVectorSpacesEqualSelf<Double>
}
let nested = Nested(simple: simple, mixed: mixed, generic: genericSame)
assert(nested.moved(along: nested) == nested + nested)
assert(nested.tangentVector(from: nested) == nested)

_ = pullback(at: Nested(simple: simple, mixed: mixed, generic: genericSame)) { model in
  model.simple + model.simple
}

// Test type whose stored properties doesn't conform to `AdditiveArithmetic`.
// Thus, `Self` cannot be used as `TangentVector` or `CotangentVector`.
// Vector space structs types must be synthesized.
// Note: it would be nice to emit a warning if conforming `Self` to
// `AdditiveArithmetic` is possible.
struct NotAdditiveArithmetic : Differentiable {
  var w: Float
  var b: Float
}

// Test type with immutable, differentiable stored property.
struct ImmutableStoredProperty : Differentiable {
  var w: Float
  let fixedBias: Float = .pi
}
_ = ImmutableStoredProperty.TangentVector(w: 1, fixedBias: 1)

// Test type whose properties are not all differentiable.
struct DifferentiableSubset : Differentiable {
  var w: Float
  var b: Float
  @noDerivative var flag: Bool
  @noDerivative let technicallyDifferentiable: Float = .pi
}
let tangentSubset = DifferentiableSubset.TangentVector(w: 1, b: 1)
let cotangentSubset = DifferentiableSubset.CotangentVector(w: 1, b: 1)

_ = pullback(at: DifferentiableSubset(w: 1, b: 2, flag: false)) { model in
  model.w + model.b
}

// Test nested type whose properties are not all differentiable.
struct NestedDifferentiableSubset : Differentiable {
  var x: DifferentiableSubset
  var mixed: Mixed
  @noDerivative var technicallyDifferentiable: Float
}

// Test type that uses synthesized vector space types but provides custom
// method.
struct HasCustomMethod : Differentiable {
  var simple: Simple
  var mixed: Mixed
  var generic: GenericVectorSpacesEqualSelf<Double>
  func moved(along: TangentVector) -> HasCustomMethod {
     print("Hello world")
     return self
  }
}

/*
// Test type with generic members that conform to `Differentiable`.
// Since it's not the case that
// `T == T.TangentVector == T.CotangentVector`,
// it's necessary to synthesize new vector space struct types.

// FIXME: Blocked by bug, potentially related to SR-9595.
// Type checker is unable to infer `T.TangentVector : AdditiveArithmetic` due
// to mutually recursive constraints:
// - `TangentVector.CotangentVector == CotangentVector`
// - `CotangentVector.CotangentVector == TangentVector`
struct GenericNeedsVectorSpaceStructs<T> : Differentiable
  where T : Differentiable
{
  var w: T
  var b: T
}

// Test generic type with vector space types to `Self`.
struct GenericNotAdditiveArithmetic<T> : Differentiable
  where T : Differentiable, T == T.TangentVector, T == T.CotangentVector
{
  var w: T
  var b: T
}

// Test type in generic context.
// FIXME: Blocked by bug, potentially related to SR-9595.
struct A<T : Differentiable> {
  struct B<U : Differentiable, V> : Differentiable {
    struct InGenericContext {
      var w: T
      var b: U
    }
  }
}
*/

// Test errors.

// Test manually customizing vector space types.
// Thees should fail. Synthesis is semantically unsupported if vector space
// types are customized.
struct VectorSpaceTypeAlias : AdditiveArithmetic, Differentiable { // expected-error {{type 'VectorSpaceTypeAlias' does not conform to protocol 'Differentiable'}}
  var w: Float
  var b: Float
  typealias TangentVector = Simple
}
struct VectorSpaceCustomStruct : AdditiveArithmetic, Differentiable { // expected-error {{type 'VectorSpaceCustomStruct' does not conform to protocol 'Differentiable'}}
  var w: Float
  var b: Float
  struct CotangentVector : AdditiveArithmetic, Differentiable {
    var w: Float.CotangentVector
    var b: Float.CotangentVector
    typealias TangentVector = VectorSpaceCustomStruct.CotangentVector
    typealias CotangentVector = VectorSpaceCustomStruct.CotangentVector
  }
}
