//===-- Gradients.swift ---------------------------------------*- swift -*-===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2014 - 2017 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//
//===----------------------------------------------------------------------===//
//
// This file contains gradient definitions for Tensor ops.
//
// Terminology:
// - originalValue (f): The function being differentiated, or the result of that
//   function.
// - Adjoint (f'): The function as the result of differentiation, computing
//   the Jacobian-vector products or gradients with respect to all arguments,
//   or the result of that function.
// - Seed: The back-propagated adjoint, i.e. the adjoint of the caller of the
//   function with respect to the result of the function.
//
// For more information, visit:
// https://en.wikipedia.org/wiki/Automatic_differentiation
//
// Each function in this file is the adjoint of some corresponding function
// defined in Ops.swift with respect to all of its parameters. The attribute
// '@differentiable(adjoint: ...)' is used to define the adjoint for a
// function. The automatic differentiation pass will pick up these adjoints
// and chain them together for arbitrary differentiable programs.
//
// NOTE:
// - Currently, we do not want to expose adjoint functions to users. The name of
//   each adjoint function should start with an underscore.
// TODO:
// - Add gradients for more ops ('sum', 'mean', etc).
// - Fix gradients for broadcasting ops (need to perform reduction).
//
// FIXME:
// - Handle scalar broadcasting.
//
//===----------------------------------------------------------------------===//

//===----------------------------------------------------------------------===//
// Method-style differential operators
//===----------------------------------------------------------------------===//

public extension Differentiable {
  @inlinable
  func gradient<R : Differentiable>(
    in f: @autodiff (Self) -> Tensor<R>
  ) -> CotangentVector
    where R : Differentiable & FloatingPoint {
    return self.pullback(in: f)(Tensor<R>(1))
  }

  @inlinable
  func valueWithGradient<R : Differentiable>(
    in f: @autodiff (Self) -> Tensor<R>
  ) -> (value: Tensor<R>, gradient: CotangentVector)
    where R : Differentiable & FloatingPoint {
    let (y, pb) = self.valueWithPullback(in: f)
    return (y, pb(Tensor<R>(1)))
  }

  @inlinable
  func gradient<T : Differentiable, R : Differentiable>(
    at x: T, in f: @autodiff (Self, T) -> Tensor<R>
  ) -> (CotangentVector, T.CotangentVector)
    where R : Differentiable & FloatingPoint {
    return self.pullback(at: x, in: f)(Tensor<R>(1))
  }

  @inlinable
  func valueWithGradient<T : Differentiable, R : Differentiable>(
    at x: T, in f: @autodiff (Self, T) -> Tensor<R>
  ) -> (value: Tensor<R>, gradient: (CotangentVector, T.CotangentVector))
    where R : Differentiable & FloatingPoint {
    let (y, pb) = self.valueWithPullback(at: x, in: f)
    return (y, pb(Tensor<R>(1)))
  }
}

//===----------------------------------------------------------------------===//
// Free-function-style differential operators
//===----------------------------------------------------------------------===//

// Value with gradient

@inlinable
public func valueWithGradient<T, R>(
  at x: T, in f: @autodiff (T) -> Tensor<R>
) -> (value: Tensor<R>, gradient: T.CotangentVector)
where T : Differentiable, R : Differentiable & FloatingPoint {
  let (y, pullback) = valueWithPullback(at: x, in: f)
  return (y, pullback(Tensor<R>(1)))
}

@inlinable
public func valueWithGradient<T, U, R>(
  at x: T, _ y: U, in f: @autodiff (T, U) -> Tensor<R>
) -> (value: Tensor<R>, gradient: (T.CotangentVector, U.CotangentVector))
  where T : Differentiable, U : Differentiable,
        R : Differentiable & FloatingPoint {
  let (y, pullback) = valueWithPullback(at: x, y, in: f)
  return (y, pullback(Tensor<R>(1)))
}

@inlinable
public func valueWithGradient<T, U, V, R>(
  at x: T, _ y: U, _ z: V, in f: @autodiff (T, U, V) -> Tensor<R>
) -> (value: Tensor<R>,
      gradient: (T.CotangentVector, U.CotangentVector, V.CotangentVector))
  where T : Differentiable, U : Differentiable, V : Differentiable,
        R : Differentiable & FloatingPoint {
  let (y, pullback) = valueWithPullback(at: x, y, z, in: f)
  return (y, pullback(Tensor<R>(1)))
}

// Value with gradient (curried)

@inlinable
public func valueWithGradient<T, R>(
  of f: @escaping @autodiff (T) -> Tensor<R>
) -> (T) -> (value: Tensor<R>, gradient: T.CotangentVector)
  where T : Differentiable, R : Differentiable & FloatingPoint {
  return { x in valueWithGradient(at: x, in: f) }
}

@inlinable
public func valueWithGradient<T, U, R>(
  of f: @escaping @autodiff (T, U) -> Tensor<R>
) -> (T, U)
    -> (value: Tensor<R>, gradient: (T.CotangentVector, U.CotangentVector))
  where T : Differentiable, U : Differentiable,
        R : Differentiable & FloatingPoint {
  return { x, y in valueWithGradient(at: x, y, in: f) }
}

@inlinable
public func valueWithGradient<T, U, V, R>(
  of f: @escaping @autodiff (T, U, V) -> Tensor<R>
) -> (T, U, V)
    -> (value: Tensor<R>,
        gradient: (T.CotangentVector, U.CotangentVector, V.CotangentVector))
  where T : Differentiable, U : Differentiable, V : Differentiable,
        R : Differentiable & FloatingPoint {
  return { x, y, z in valueWithGradient(at: x, y, z, in: f) }
}

// Gradient

@inlinable
public func gradient<T, R>(
  at x: T, in f: @autodiff (T) -> Tensor<R>
) -> T.CotangentVector
  where T : Differentiable, R : Differentiable & FloatingPoint {
  return pullback(at: x, in: f)(Tensor<R>(1))
}

@inlinable
public func gradient<T, U, R>(
  at x: T, _ y: U, in f: @autodiff (T, U) -> Tensor<R>
) -> (T.CotangentVector, U.CotangentVector)
  where T : Differentiable, U : Differentiable,
        R : Differentiable & FloatingPoint {
  return pullback(at: x, y, in: f)(Tensor<R>(1))
}

@inlinable
public func gradient<T, U, V, R>(
  at x: T, _ y: U, _ z: V, in f: @autodiff (T, U, V) -> Tensor<R>
) -> (T.CotangentVector, U.CotangentVector, V.CotangentVector)
  where T : Differentiable, U : Differentiable, V : Differentiable,
        R : Differentiable & FloatingPoint {
  return pullback(at: x, y, z, in: f)(Tensor<R>(1))
}

// Gradient (curried)

@inlinable
public func gradient<T, R>(
  of f: @escaping @autodiff (T) -> Tensor<R>
) -> (T) -> T.CotangentVector
  where T : Differentiable, R : Differentiable & FloatingPoint {
  return { x in gradient(at: x, in: f) }
}

@inlinable
public func gradient<T, U, R>(
  of f: @escaping @autodiff (T, U) -> Tensor<R>
) -> (T, U) -> (T.CotangentVector, U.CotangentVector)
  where T : Differentiable, U : Differentiable,
        R : Differentiable & FloatingPoint {
  return { x, y in gradient(at: x, y, in: f) }
}

@inlinable
public func gradient<T, U, V, R>(
  of f: @escaping @autodiff (T, U, V) -> Tensor<R>
) -> (T, U, V) -> (T.CotangentVector, U.CotangentVector, V.CotangentVector)
  where T : Differentiable, U : Differentiable, V : Differentiable,
        R : Differentiable & FloatingPoint {
  return { x, y, z in gradient(at: x, y, z, in: f) }
}

//===----------------------------------------------------------------------===//
// Elementwise binary
//===----------------------------------------------------------------------===//

extension Tensor where Scalar : Differentiable & FloatingPoint {
  @inlinable
  static func _adjointAdd(
    _ seed: Tensor, _ originalValue: Tensor, _ x: Tensor, _ y: Tensor
  ) -> (Tensor, Tensor) {
    let seed = seed.broadcast(like: originalValue)
    return (seed.unbroadcast(like: x), seed.unbroadcast(like: y))
  }

  @inlinable
  static func _adjointSubtract(
    _ seed: Tensor, _ originalValue: Tensor, _ x: Tensor, _ y: Tensor
  ) -> (Tensor, Tensor) {
    let seed = seed.broadcast(like: originalValue)
    return (seed.unbroadcast(like: x), 0 - seed.unbroadcast(like: y))
  }

  @inlinable
  static func _adjointMultiply(
    _ seed: Tensor, _ originalValue: Tensor, _ x: Tensor, _ y: Tensor
  ) -> (Tensor, Tensor) {
    return ((y * seed).unbroadcast(like: x),
            (x * seed).unbroadcast(like: y))
  }

  @inlinable
  static func _adjointDivide(
    _ seed: Tensor, _ originalValue: Tensor, _ x: Tensor, _ y: Tensor
  ) -> (Tensor, Tensor) {
    return ((seed / y).unbroadcast(like: x),
            ((0 - x) / y.squared() * seed).unbroadcast(like: y))
  }
}

@inlinable
func _adjointMinMax<T : Differentiable & FloatingPoint>(
  _ seed: Tensor<T>, _ originalValue: Tensor<T>, _ x: Tensor<T>, _ y: Tensor<T>
) -> (Tensor<T>, Tensor<T>) {
  let denom = 1 + Tensor<T>(x .== y)
  let dfdx = seed * Tensor<T>(x .== originalValue) / denom
  let dfdy = seed * Tensor<T>(y .== originalValue) / denom
  return (dfdx.unbroadcast(like: x), dfdy.unbroadcast(like: y))
}

@inlinable
func _adjointPow<T : Differentiable & FloatingPoint>(
  _ seed: Tensor<T>, _ originalValue: Tensor<T>, _ x: Tensor<T>, _ y: Tensor<T>
) -> (Tensor<T>, Tensor<T>) {
  return ((seed * y * pow(x, y-1)).unbroadcast(like: x),
          (seed * log(x) * originalValue).unbroadcast(like: y))
}

//===----------------------------------------------------------------------===//
// Elementwise unary
//===----------------------------------------------------------------------===//

extension Tensor where Scalar : Differentiable & FloatingPoint {
  @inlinable
  static func _adjointNegate(
    _ seed: Tensor, _ originalValue: Tensor, _ x: Tensor
  ) -> Tensor {
    return -seed.broadcast(like: originalValue)
  }
}

@inlinable
func _adjointLog<T : Differentiable & FloatingPoint>(
  _ seed: Tensor<T>, _ originalValue: Tensor<T>, _ x: Tensor<T>
) -> Tensor<T> {
  return seed / x
}

@inlinable
func _adjointSin<T : Differentiable & FloatingPoint>(
  _ seed: Tensor<T>, _ originalValue: Tensor<T>, _ x: Tensor<T>
) -> Tensor<T> {
  return seed * cos(x)
}

@inlinable
func _adjointCos<T : Differentiable & FloatingPoint>(
  _ seed: Tensor<T>, _ originalValue: Tensor<T>, _ x: Tensor<T>
) -> Tensor<T> {
  return -seed * sin(x)
}

@inlinable
func _adjointTan<T : Differentiable & FloatingPoint>(
  _ seed: Tensor<T>, _ originalValue: Tensor<T>, _ x: Tensor<T>
) -> Tensor<T> {
  return seed * (1 + originalValue.squared())
}

@inlinable
func _adjointSinh<T : Differentiable & FloatingPoint>(
  _ seed: Tensor<T>, _ originalValue: Tensor<T>, _ x: Tensor<T>
) -> Tensor<T> {
  return seed * cosh(x)
}

@inlinable
func _adjointCosh<T : Differentiable & FloatingPoint>(
  _ seed: Tensor<T>, _ originalValue: Tensor<T>, _ x: Tensor<T>
) -> Tensor<T> {
  return seed * sinh(x)
}

@inlinable
func _adjointTanh<T : Differentiable & FloatingPoint>(
  _ seed: Tensor<T>, _ originalValue: Tensor<T>, _ x: Tensor<T>
) -> Tensor<T> {
  return seed * (1 - originalValue.squared())
}

@inlinable
func _adjointExp<T : Differentiable & FloatingPoint>(
  _ seed: Tensor<T>, _ originalValue: Tensor<T>, _ x: Tensor<T>
) -> Tensor<T> {
  return originalValue * seed
}

@inlinable
func _adjointCeil<T : Differentiable & FloatingPoint>(
  _ seed: Tensor<T>, _ originalValue: Tensor<T>, _ x: Tensor<T>
) -> Tensor<T> {
  return Tensor(0).broadcast(like: x)
}

@inlinable
func _adjointFloor<T : Differentiable & FloatingPoint>(
  _ seed: Tensor<T>, _ originalValue: Tensor<T>, _ x: Tensor<T>
) -> Tensor<T> {
  return Tensor(0).broadcast(like: x)
}

@inlinable
func _adjointSqrt<T : Differentiable & FloatingPoint>(
  _ seed: Tensor<T>, _ originalValue: Tensor<T>, _ x: Tensor<T>
) -> Tensor<T> {
  return seed / (2 * originalValue)
}

@inlinable
func _adjointRsqrt<T : Differentiable & FloatingPoint>(
  _ seed: Tensor<T>, _ originalValue: Tensor<T>, _ x: Tensor<T>
) -> Tensor<T> {
  return -seed / 2 * pow(originalValue, 3)
}

func _adjointSquared<T : Differentiable & FloatingPoint>(
  _ seed: Tensor<T>, _ originalValue: Tensor<T>, _ x: Tensor<T>
) -> Tensor<T> {
  return 2 * x * seed
}

//===----------------------------------------------------------------------===//
// Linear algebra
//===----------------------------------------------------------------------===//

@inlinable
func _adjointMatmul<Scalar : Differentiable & FloatingPoint>(
  _ seed: Tensor<Scalar>, _ originalValue: Tensor<Scalar>,
  _ left: Tensor<Scalar>, _ right: Tensor<Scalar>
) -> (Tensor<Scalar>, Tensor<Scalar>) {
  let bcSeed = seed.broadcast(like: originalValue)
  return (matmul(bcSeed, right.transposed()), matmul(left.transposed(), bcSeed))
}

// TODO: We have to define a custom adjoint on • because AD can't yet
// differentiate generic methods. After AD can differentiate generic methods,
// remove the custom adjoint.
extension Tensor where Scalar : Differentiable & FloatingPoint {
  @inlinable
  static func _adjointMatmulOperator(seed: Tensor, originalValue: Tensor,
                                     lhs: Tensor, rhs: Tensor)
      -> (Tensor, Tensor) {
    return _adjointMatmul(seed, originalValue, lhs, rhs)
  }

  @inlinable
  func _adjointTransposed(
    _ seed: Tensor, _ originalValue: Tensor, _ permutations: Tensor<Int32>
  ) -> Tensor {
    let seed = seed.broadcast(like: originalValue)
    return seed.transposed(withPermutations: permutations)
  }
}

//===----------------------------------------------------------------------===//
// Shape transformations
//===----------------------------------------------------------------------===//

extension Tensor where Scalar : Differentiable & FloatingPoint {
  @inlinable
  func _adjointReshaped(
    seed: Tensor, originalValue: Tensor, toShape newShape: Tensor<Int32>
  ) -> Tensor {
    let seed = seed.broadcast(like: originalValue)
    return seed.reshaped(toShape: shapeTensor)
  }

  @inlinable
  func _adjointReshaped(
    seed: Tensor, originalValue: Tensor, to newShape: TensorShape
  ) -> Tensor {
    let seed = seed.broadcast(like: originalValue)
    return seed.reshaped(toShape: shapeTensor)
  }

  @inlinable
  func _adjointExpandingShape(
    seed: Tensor, originalValue: Tensor, at shapeIndex: Int32
  ) -> Tensor {
    let seed = seed.broadcast(like: originalValue)
    return seed.squeezingShape(at: shapeIndex)
  }
}

//===----------------------------------------------------------------------===//
// Reduction
//===----------------------------------------------------------------------===//

 extension Tensor where Scalar : Differentiable & FloatingPoint {
  @inlinable
  func _adjointSumToScalar(
    seed: Tensor, originalValue: Tensor
  ) -> Tensor {
    return seed.broadcast(like: self)
  }
}

//===----------------------------------------------------------------------===//
// Normalization
//===----------------------------------------------------------------------===//

extension Tensor where Scalar : Differentiable & FloatingPoint {
  // TODO: Verify that these calculations are correct.
  @inlinable
  func _adjointBatchNormalized(
    seed: Tensor,
    originalValue: Tensor,
    offset: Tensor,
    scale: Tensor,
    epsilon: Tensor
  ) -> (Tensor, Tensor, Tensor, Tensor) {
    let axis = self.rank - 1
    let mean = self.mean(alongAxes: axis)
    let squaredDiff: Tensor = Raw.squaredDifference(self, mean)
    let variance = squaredDiff.mean(alongAxes: axis)

    let diff = self - mean
    let inv = rsqrt(variance + epsilon)
    let norm = diff * inv

    let dNorm = seed * scale
    let dVariance = -(dNorm * diff).sum(alongAxes: axis) / 2 * pow(inv, -3)
    let dMean = (-dNorm * inv).sum(alongAxes: axis) +
      dVariance * (-diff * 2).mean(alongAxes: axis)
    let dOffset = seed.sum(alongAxes: axis)
    let dScale = (norm * seed).sum(alongAxes: axis)
    let dim = Tensor(Tensor<Int32>(shapeTensor[axis]))
    let tmp = (dNorm * inv) + (dVariance * 2 * dMean / dim)
    let dSelf = tmp + (dMean / dim)
    return (dSelf, dOffset, dScale, Tensor<Scalar>(0))
  }
}

//===----------------------------------------------------------------------===//
// Convolution and pooling
//===----------------------------------------------------------------------===//

extension Tensor where Scalar : Differentiable & FloatingPoint {
  /// TensorFlow builtin conv2d gradient helper for the input.
  @inlinable
  @differentiable(
    wrt: (.1, .2),
    adjoint: _adjointTFConv2DBackpropInput(_:_:_:_:_:_:_:)
  )
  func _TFConv2DBackpropInput(
    shape: Tensor<Int32>,
    filter: Tensor,
    backpropOutput: Tensor,
    strides: (Int32, Int32, Int32, Int32),
    padding: Padding
  ) -> Tensor {
    return Raw.conv2DBackpropInput(
      inputSizes: shape,
      filter: filter,
      outBackprop: backpropOutput,
      strides: [strides.0, strides.1, strides.2, strides.3],
      padding: padding.raw)
  }

  /// TensorFlow builtin conv2d gradient helper for the filter.
  @inlinable
  @differentiable(
    wrt: (.0, .2),
    adjoint: _adjointTFConv2DBackpropFilter(_:_:_:_:_:_:_:)
  )
  func _TFConv2DBackpropFilter(
    input: Tensor,
    filterSizes: Tensor<Int32>,
    backpropOutput: Tensor,
    strides: (Int32, Int32, Int32, Int32),
    padding: Padding
  ) -> Tensor {
    return Raw.conv2DBackpropFilter(
      input,
      filterSizes: filterSizes,
      outBackprop: backpropOutput,
      strides: [strides.0, strides.1, strides.2, strides.3],
      padding: padding.raw)
  }

  @inlinable
  func _adjointTFConv2DBackpropInput(
    _ seed: Tensor,
    _ originalValue: Tensor,
    _ shape: Tensor<Int32>,
    _ filter: Tensor,
    _ backpropOutput: Tensor,
    _ strides: (Int32, Int32, Int32, Int32),
    _ padding: Padding
  ) -> (Tensor, Tensor) {
    return (
      _TFConv2DBackpropFilter(input: seed, filterSizes: shape,
                              backpropOutput: backpropOutput, strides: strides,
                              padding: padding),
      seed.convolved2D(withFilter: filter, strides: strides, padding: padding)
    )
  }

  @inlinable
  func _adjointTFConv2DBackpropFilter(
    _ seed: Tensor,
    _ originalValue: Tensor,
    _ input: Tensor,
    _ filterSizes: Tensor<Int32>,
    _ backpropOutput: Tensor,
    _ strides: (Int32, Int32, Int32, Int32),
    _ padding: Padding
  ) -> (Tensor, Tensor) {
    return (
      _TFConv2DBackpropInput(shape: filterSizes, filter: seed,
                             backpropOutput: backpropOutput, strides: strides,
                             padding: padding),
      input.convolved2D(withFilter: seed, strides: strides, padding: padding)
    )
  }

  @inlinable
  func _adjointConvolved2D(
    seed: Tensor,
    originalValue: Tensor,
    filter: Tensor,
    strides: (Int32, Int32, Int32, Int32),
    padding: Padding
  ) -> (Tensor, Tensor) {
    return (
      _TFConv2DBackpropInput(
        shape: shapeTensor, filter: filter, backpropOutput: seed,
        strides: strides, padding: padding
      ),
      _TFConv2DBackpropFilter(
        input: self, filterSizes: filter.shapeTensor, backpropOutput: seed,
        strides: strides, padding: padding
      )
    )
  }

  @inlinable
  func _adjointMaxPooled(
    seed: Tensor,
    originalValue: Tensor,
    kernelSize: (Int32, Int32, Int32, Int32),
    strides: (Int32, Int32, Int32, Int32),
    padding: Padding
  ) -> Tensor {
    // TODO: Currently this is not higher order differentiable. Redefine in
    // closed form.
    return Raw.maxPoolGradV2(
      origInput: self,
      origOutput: originalValue,
      grad: seed,
      ksize: Tensor<Int32>(kernelSize),
      strides: Tensor<Int32>(strides),
      padding: padding.raw
    )
  }

  @inlinable
  func _adjointAveragePooled(
    seed: Tensor,
    originalValue: Tensor,
    kernelSize: (Int32, Int32, Int32, Int32),
    strides: (Int32, Int32, Int32, Int32),
    padding: Padding
  ) -> Tensor {
    // TODO: Currently this is not higher order differentiable. Redefine in
    // closed form.
    return Raw.avgPoolGrad(
      origInputShape: shapeTensor,
      grad: seed,
      ksize: [kernelSize.0, kernelSize.1, kernelSize.2, kernelSize.3],
      strides: [strides.0, strides.1, strides.2, strides.3],
      padding: padding.raw
    )
  }
}

//===----------------------------------------------------------------------===//
// Composite math
//===----------------------------------------------------------------------===//

@inlinable
func _adjointRelu<T : Differentiable &  FloatingPoint>(
  _ seed: Tensor<T>, _ originalValue: Tensor<T>, _ x: Tensor<T>
) -> Tensor<T> {
  return Tensor(x .> 0) * seed
}

@inlinable
func _adjointLogSoftmax<T : Differentiable & FloatingPoint>(
  _ seed: Tensor<T>, _ originalValue: Tensor<T>, _ x: Tensor<T>
) -> Tensor<T> {
  let softmax = exp(originalValue)
  return seed - x.sum(alongAxes: x.rank - 1) * softmax
}

@inlinable
func _adjointSigmoid<T : Differentiable & FloatingPoint>(
  _ seed: Tensor<T>, _ originalValue: Tensor<T>, _ x: Tensor<T>
) -> Tensor<T> {
  return seed * originalValue * (1 - originalValue)
}
