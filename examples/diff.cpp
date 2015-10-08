// Copyright 2015 Adobe Systems Incorporated
// All Rights Reserved.

Var x, y, c;
ImageParam ip1(type_of<uint8_t>(), 3, "image 1");
ImageParam ip2(type_of<uint8_t>(), 3, "image 2");

Func diffAt;

diffAt(x, y, c) = abs(cast<float>(ip1(x, y, c)) - ip2(x, y, c)) / 255.0f;

result(x, y, c) = cast<uint8_t>(diffAt(x, y, c) * max(ip1(x, y, c), ip2(x, y, c)));
