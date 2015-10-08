// Copyright 2015 Adobe Systems Incorporated
// All Rights Reserved.

Var x, y, c;
ImageParam ip(type_of<uint8_t>(), 3, "image 1");

RDom dom(ip);

Param<float> stretch("zoom factor", 0.0f, -1.0f, 1.0f);
Param<float> ratio("stretch ratio", 0.0f, -1.0f, 1.0f);
Param<float> xoffset("horizontal position", 0.0f, 0.0f, 1.0f);
Param<float> yoffset("vertical position", 0.0f, 0.0f, 1.0f);

Expr stretchx = pow(5, stretch);
Expr stretchy = pow(4, ratio) * stretchx;

Expr xsrc = x / stretchx + dom.x.extent() * xoffset;
Expr ysrc = y / stretchy + dom.y.extent() * yoffset;

Func bcip;
bcip = BoundaryConditions::constant_exterior(ip, 0);

result(x, y, c) = bcip(cast<int>(xsrc), cast<int>(ysrc), c);

result.parallel(y, 2).vectorize(x, 8);
