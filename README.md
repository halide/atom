# atomic-halide package

An Atom editor package for rapid development of simple Halide imaging language pipelines.

Purpose
-------
This package was the direct result of wanting a more streamlined way to learn the basics of image processing using [Halide][halide]. Halide has an excellent set of well commented tutorials, but as I was experimenting with them, I found myself wanting a tighter iteration process than running make and looking at written image files after each code change.

This is noted as much as anything to say that this is a prototype of a live coding environment for imaging algorithms and not a finished product. It was created for the purposes of learning a number of technologies (Atom's Electron app framework, Node.js, image processing in general, Halide in particular, using web technology for desktop app UI, CoffeeScript, etc). I knew very little about any of these when I started. The UI is also very much of the "simplest thing that could possibly work" variety. I am neither a UI or web developer.

All that is to say that if there are rookie mistakes in the code or examples, feel free to point them out (politely).

Installation/Setup
------------------

Prerequisites:
* A copy of [Github's Atom Editor][atom].
* A C++ build toolchain: Xcode on the Mac, Visual Studio on Windows, make and g++ on Linux, etc.
* A [binary distribution of Halide][halide-release] or a compatible version [built from source][halide-git].
* A working version of Python (used by node-gyp to install native node modules via Atom's package manager). I used 32-bit Python 2.7.10 from [python.org][python].

Special Note for those on Mac OS X using Xcode 7. As of this writing, the most recently posted Halide binary distribution (Sept 11) has a [crashing bug][bug] that was [fixed][bugfix] on the 25th. Until there's a new release including that fix, you'll have to build from source.

* Clone this git repo.

    On Mac and Linux, you can put it anywhere and run setup.sh to symlink it in as a local Atom package and run apm install to fetch and build the native modules.

    On Windows, I found it is easier to just put the repo in Atom's local package directory directly (.atom/packages in your home directory) and run setup.bat from there to perform the apm install.
* Restart Atom or run the Reload command in the View menu to pick up the newly installed package.
* Add the examples folder of the git repo as a project folder.
* Open one of the cpp files (stretch.cpp, mosiac.cpp, etc).
* In the Packages menu for Atomic Halide, invoke the Toggle Preview command.
* On first use, press the Configure button at the top of the panel and select the folder where your build of Halide resides (it should have the include and bin or Debug/Release subfolders).

How it Works
------------
When the preview is opened, a new editor is opened, or the current editor is saved, the package attempts to shell out to make (Mac/Linux) or nmake (Windows) to build a shared library (dylib, so, dll on Mac, Linux, and Windows respectively). The details of how to go from a source file to a dylib are mostly defined by target definitions in the Makefile/NMakefile in the examples folder.

If there is no target, it leaves the existing panel in place. If there is a target and it fails, the error output is presented in the panel. If it succeeds, a JavaScript FFI is used to bind to the render function and parse the exported parameter metadata to build the panel of controls (sliders, checkboxes, and text fields).

As those inputs are manipulated, the render function is invoked (in process) and the buffer is copied into an ImageData to paint the result onto the HTML5 canvas element. If the source file is changed and saves, the panel is regenerated and the inputs are reset.

This really streamlined my workflow for playing with imaging algorithms. It makes it easy to introduce new parameters and see how various values affect the output. That iterative feedback loop makes the process much more fun.

Thanks
------
Special thanks go out to those who've contributed to Halide itself. It's a really neat piece of work and the excellent tutorials made it quite approachable. Thanks also to Github for Atom and the various authors of the [Node modules I used](package.json). Having such excellent building blocks made this much easier to assemble.

Caveats
-------
Most of the work on this package was done on a Mac. I did get it working on Windows as well, but I haven't exposed the required toolchain paths as configuration, so a different version of Visual Studio and the Windows SDK probably requires a slight tweak to a few constants in the [package source code](lib/winenv.coffee) right now. It also tested it on Ubuntu 14.04 and got that working.

Also, the package does nothing to set up the build toolchain (make, a C++ compiler, etc). It assumes it can shell out to make or nmake and that those in turn can determine the correct compiler to use.

Since the FFI runs the render function synchronously in process, you can hang or crash Atom if you make serious mistakes in your imaging code. There are certain kinds of bound checking mistakes that Halide will report via an error callback and those are handled more gracefully. I experimented with various degrees of async rendering (out of process, in process but using the FFI async call path), but haven't made the switch yet because I didn't like the way they felt to use, so I haven't done that yet.

These and a few others are also noted in the [TODO list](TODO.txt).

[atom]: https://atom.io
[halide]: http://halide-lang.org/
[halide-git]: https://github.com/halide/Halide
[halide-release]: https://github.com/halide/Halide/releases
[python]: https://www.python.org
[bug]: https://github.com/halide/Halide/issues/936
[bugfix]: https://github.com/halide/Halide/commit/46bb4d8190dfe11a5b3e818ef149f3785ae4d43d
