// Copyright 2015 Adobe Systems Incorporated
// All Rights Reserved.

// This code was inspired by a series of videos demonstrating the creation of
// fractal noise found here: http://tobyschachman.com/Shadershop/

const int green_channel = 1;
const int blue_channel = 2;

Param<int> levels("levels", 6, 1, 16);
Param<int> swidth("tile width", 128, 64, 600);
Param<float> water("water level", 0.9f, 0.0f, 2.0f);
Param<float> snow("snow level", 1.56f, 0.0f, 2.0f);
Param<int> seed("randomizer seed", 0);

Var x, y, c;

Func vx;
vx( x ) = cast<float>(x) / swidth;

Func random;
random( x, y ) = random_float(seed);

Func stepRandom;
stepRandom( x, y ) = random( x / swidth + 1, y / swidth + 1 );

Func fvx;
fvx( x ) = vx( x ) - floor(vx( x ));
Func smoothSaw;
smoothSaw( x ) = fvx( x ) * fvx( x ) * ((fvx( x ) - 1) * -2 + 1);

Func horizontal;
horizontal( x, y )  = stepRandom( x, y ) * smoothSaw( x ) +
	(stepRandom( x - swidth , y ) * ( smoothSaw( x ) * -1 + 1));

Func noise2D;
noise2D( x, y ) = (
    (horizontal( x, y - swidth ) * (smoothSaw( y ) * -1 + 1)) +
    (horizontal( x, y ) * (smoothSaw( y )))
);

Var i;
Func noiseAtLevel;
noiseAtLevel(x, y, i) = noise2D( x * i, y * i ) / i;

Func fractalNoise2D;
RDom r(0, levels);
fractalNoise2D( x, y ) = sum(noiseAtLevel(x, y, 1 << r));

Expr fnValue = fractalNoise2D( x, y );

// colored by "elevation" blue water, green land, snowy peaks
Expr coloredValue = select(
    fnValue > snow, fnValue / snow,                       // snow -> white
    fnValue <= snow && fnValue >= water, select(          // land
        c == green_channel, fnValue - water / 1.5f, 0 ),  // darkish green
    fnValue < water, select(					          // water
        c == blue_channel, max( 0.5f, fnValue ) * 1.4f, 0 ),
	0
);

// Cast it back to an 8-bit unsigned integer.
result(x, y, c) = cast<uint8_t>( clamp(
    coloredValue * 128, 0, 255 ));

result.reorder(c, x, y);
fractalNoise2D.compute_at(result, y);
result.parallel(y);
