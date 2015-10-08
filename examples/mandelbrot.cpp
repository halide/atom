// Copyright 2015 Adobe Systems Incorporated
// All Rights Reserved.

// This sample is a derivative work of lesson 13 in the Halide language tutorials:
// https://github.com/halide/Halide/blob/master/tutorial/lesson_13_tuples.cpp
//
// While the below is a fairly tiny part of the Halide project, its license
// details are included here for reference.

// Copyright (c) 2012-2014 MIT CSAIL, Google Inc., and other contributors
//
// Developed by:
//
//   The Halide team
//   http://halide-lang.org
//
// Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

Var x, y, c;

// Tuples can also be a convenient way to represent compound
// objects such as complex numbers. Defining an object that
// can be converted to and from a Tuple is one way to extend
// Halide's type system with user-defined types.
struct Complex {
    Expr real, imag;

    // Construct from a Tuple
    Complex(Tuple t) : real(t[0]), imag(t[1]) {}

    // Construct from a pair of Exprs
    Complex(Expr r, Expr i) : real(r), imag(i) {}

    // Construct from a call to a Func by treating it as a Tuple
    Complex(FuncRefExpr t) : Complex(Tuple(t)) {}
    Complex(FuncRefVar t) : Complex(Tuple(t)) {}

    // Convert to a Tuple
    operator Tuple() const {
        return {real, imag};
    }

    // Complex addition
    Complex operator+(const Complex &other) const {
        return {real + other.real, imag + other.imag};
    }

    // Complex multiplication
    Complex operator*(const Complex &other) const {
        return {real * other.real - imag * other.imag,
        				real * other.imag + imag * other.real};
    }

    // Complex magnitude
    Expr magnitude() const {
        return real * real + imag * imag;
    }

    // Other complex operators would go here. The above are
    // sufficient for this example.
};

// Let's use the Complex struct to compute a Mandelbrot set.
Func mandelbrot;

// Copied from the original Tuple mandelbrot example (Halide lesson 13)
// Using Atomic Halide, though, it's easy to parameterize the pipeline and
// use direct manipulation to understand and give the magic numbers names.
Param<float> width("width", 3180.0f, -400.0f, 4000.0f);
Param<float> height("height", 2800.0f, -400.0f, 4000.0f);
Param<float> xoff("horizontal position", 2125.0f, -400.0f, 4000.0f);
Param<float> yoff("vertical position", 2030.0f, -400.0f, 4000.0f);
Param<int> steps("steps", 20, 1, 40);
Param<float> thresh("threshold", 16.0f, 2.0f, 64.0f);
Param<int> brightness("brightness", 15, 2, 40);
Param<float> realinit("real initial value", 0.0f, -2.0f, 2.0f);
Param<float> imaginit("imaginary initial value", 0.0f, -2.0f, 2.0f);

// The initial complex value corresponding to an x, y coordinate
// in our Func.
Complex initial((x - xoff)/width, (y - yoff) / height);

// Pure definition.
Var t;
mandelbrot(x, y, t) = Complex(realinit, imaginit);

// We'll use an update definition to take 12 steps.
RDom r(1, steps);
Complex current = mandelbrot(x, y, r-1);

// The following line uses the complex multiplication and
// addition we defined above.
mandelbrot(x, y, r) = current*current + initial;

// We'll use another tuple reduction to compute the iteration
// number where the value first escapes a circle of radius 4.
// This can be expressed as an argmin of a boolean - we want
// the index of the first time the given boolean expression is
// false (we consider false to be less than true).  The argmax
// would return the index of the first time the expression is
// true.

Expr escape_condition = Complex(mandelbrot(x, y, r)).magnitude() < thresh;
Tuple first_escape = argmin(escape_condition);

// We only want the index, not the value, but argmin returns
// both, so we'll index the argmin Tuple expression using
// square brackets to get the Expr representing the index.
Func escape;
result(x, y, c) = cast<uint8_t>(clamp(first_escape[0] * brightness, 0, 255));

result.reorder(c, x, y);
mandelbrot.compute_at(result, y);
result.parallel(y);
