#include <iostream>
#include <llvm/IR/LLVMContext.h>
#include <llvm/IR/Module.h>
#include <llvm/IRReader/IRReader.h>
#include <llvm/Support/CommandLine.h>
#include <llvm/Support/raw_ostream.h>
#include <llvm/Support/Error.h>
#include "garuda/Analysis/GarudaAnalysis.h"
#include "garuda/Group/GroupDomainManager.h"
#include "garuda/Update/ProgressUpdateTracker.h"

using namespace llvm;

static cl::opt<std::string> InputFileName(cl::Positional, cl::desc("<input bitcode file>"), cl::Required);
static cl::opt<std::string> OutputFileName("o", cl::desc("Output filename"), cl::value_desc("output"), cl::init("-"));
static cl::opt<bool> Verbose("v", cl::desc("Verbose output"));

namespace garuda {

class SimpleAnalysis : public FunctionAnalysis {
protected:
    std::shared_ptr<AnalysisResult> analyzeFunction(llvm::Function* function) override {
        auto result = std::make_shared<AnalysisResult>();

        auto group = std::make_shared<GroupDomain>(function->getName().str());
        group->setTop();
        result->setGroupDomain(function->getName().str(), group);

        result->setConverged(true);
        result->setIterationCount(1);

        return result;
    }
};

}

int main(int argc, char** argv) {
    LLVMContext context;
    SMDiagnostic err;

    cl::ParseCommandLineOptions(argc, argv, "Garuda Static Analysis Tool\n");

    std::string input = InputFileName;
    if (input == "-") {
        errs() << "Error: No input file specified\n";
        return 1;
    }

    auto module = parseIRFile(input, err, context);
    if (!module) {
        err.print(argv[0], errs());
        return 1;
    }

    outs() << "Garuda Static Analysis Tool\n";
    outs() << "==========================\n\n";
    outs() << "Module: " << module->getName() << "\n";
    outs() << "Functions: " << module->size() << "\n";
    outs() << "Globals: " << module->global_size() << "\n\n";

    auto groupManager = std::make_shared<garuda::GroupDomainManager>();
    auto progressTracker = std::make_shared<garuda::ProgressUpdateTracker>();

    outs() << "Analysis complete.\n";

    return 0;
}