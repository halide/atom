// Copyright 2015 Adobe Systems Incorporated
// All Rights Reserved.

ImageParam input(type_of<uint8_t>(), 3, "image 1");

Var x, y, c;

Func ip;

RDom dom(input);

ip(x, y, c) = cast<float>(BoundaryConditions::repeat_edge(input)(x, y, c));

Param<int> radius("radius", 5, 1, 15);

RDom r(-radius, radius, -radius, radius);

Func weight;
weight(x, y) = exp(-((x * x + y * y) / cast<float>(2 * radius * radius)));

Func rweight;
rweight(x, y) = weight(x, y) / sum(weight(r.x, r.y));

result(x, y, c) = cast<uint8_t>(
    sum(ip(x + r.x, y + r.y, c) * rweight(r.x, r.y)));

rweight.compute_root();

result.parallel(y, 2).vectorize(x, 4);
