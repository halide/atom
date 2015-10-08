// Copyright 2015 Adobe Systems Incorporated
// All Rights Reserved.

Var x, y, c;
ImageParam ip(type_of<uint8_t>(), 3, "image 1");

Func bcip;
bcip = BoundaryConditions::repeat_edge(ip);

Param<int> width("block width", 16, 2, 200);
Expr height = width;

RDom r(0, width, 0, height);

Func tile;

tile(x, y, c) = sum(cast<float>(bcip(
    x * width + r.x,
    y * height + r.y,
    c
))) / (width * height);

result(x, y, c) = cast<uint8_t>(tile(x / width, y / height, c));

Var x_outer, y_outer, x_inner, y_inner, tile_index;
result
    .tile(x, y, x_outer, y_outer, x_inner, y_inner, width, height)
    .fuse(x_outer, y_outer, tile_index)
    .parallel(tile_index);

tile.compute_at(result, tile_index);
