// Copyright 2015 Adobe Systems Incorporated
// All Rights Reserved.

Var x, y, c;
ImageParam ip(type_of<uint8_t>(), 3, "image 1");

Param<float> red("red channel multiplier", 1.0f, 0.0f, 2.0f);
Param<float> green("green channel multiplier", 1.0f, 0.0f, 2.0f);
Param<float> blue("blue channel multiplier", 1.0f, 0.0f, 2.0f);
Param<float> noise("noise amount", 0.0f, 0.0f, 1.0f);
Param<bool> invert("invert", false);

Expr noiseVal = noise * (random_float() - 0.5) * 255;
Expr input = select(invert, 255 - ip(x, y, c), ip(x, y, c));

result(x, y, c) = cast<int8_t>(
    clamp( select(
        c == 0, input * red,
        c == 1, input * green,
        c == 2, input * blue,
        0) + noiseVal, 0, 255)
);

result.vectorize(x, 8).parallel(y, 4);
