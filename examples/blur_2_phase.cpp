// Copyright 2015 Adobe Systems Incorporated
// All Rights Reserved.

ImageParam input(type_of<uint8_t>(), 3, "image 1");

Var x("x"), y("y"), c("c"), xi("xi"), yi("yi");

Func ip("ip");

RDom dom(input);

ip(x, y, c) = cast<float>(BoundaryConditions::repeat_edge(input)(x, y, c));

Param<int> radius("radius", 15, 1, 50);

RDom r(-radius, radius);

Func weight("weight");
weight(x) = exp(-((x * x) / cast<float>(2 * radius * radius)));

Func rweight("rweight");
rweight(x) = weight(x) / sum(weight(r.x));

Func blur_x("blur_x");
blur_x(x, y, c) = cast<uint8_t>(
  sum(ip(x + r.x, y, c) * rweight(r.x)));

Func blur_y;
blur_y(x, y, c) = cast<uint8_t>(
    sum(blur_x(x, y + r.x, c) * rweight(r.x)));

rweight.compute_root();

blur_y.split(y, y, yi, 8).parallel(y).vectorize(x, 8);
blur_x.store_at(blur_y, y).compute_at(blur_y, yi).vectorize(x, 8);

result = blur_y;
