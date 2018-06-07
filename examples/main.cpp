// Copyright 2015 Adobe Systems Incorporated
// All Rights Reserved.

#include "Halide.h"

Halide::Func getFunction();

int main(int argc, char **argv) {
    Halide::Func theFunc = getFunction();

    if (argc >= 3) {
        std::vector<Halide::Argument> arguments = theFunc.infer_arguments();

        Halide::Target target = Halide::get_target_from_environment();
        target.set_feature(Halide::Target::Feature::UserContext);

        theFunc.compile_to_object(argv[1] + std::string(".o"), arguments, argv[2], target);
        // handy line of code for diagnosing changes to the API to a generated library
        // theFunc.compile_to_header(argv[1] + std::string("_Header.h"), arguments, argv[2], target);

        return 0;
    }

    return 1;
}
