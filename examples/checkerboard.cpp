// Copyright 2015 Adobe Systems Incorporated
// All Rights Reserved.

Var x, y, c;

Param<int> size("size", 32, 4, 256);
Param<int> shade_1("shade 1", 192, 0, 255);
Param<int> shade_2("shade 2", 64, 0, 255);

result(x, y, c) = cast<uint8_t>(select(
    (floor (x / size) % 2) != (floor(y / size) % 2), shade_1, shade_2));

result.parallel(y).vectorize(x, 8);
