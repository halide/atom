// Copyright 2015 Adobe Systems Incorporated
// All Rights Reserved.

Var x, y, c;
ImageParam ip1(type_of<uint8_t>(), 3, "image 1");
ImageParam ip2(type_of<uint8_t>(), 3, "image 2");

Param<float> balance("balance", 0.5f, 0.0f, 1.0f);

result(x, y, c) = cast<int8_t>(
    clamp(
        balance * ip1(x, y, c) + (1.0f - balance) * ip2(x, y, c), 0, 255
    )
);

result.vectorize(x, 8).parallel(y, 4);
