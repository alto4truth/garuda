#include <iostream>
#include "garuda/Domain/AbstractDomain.h"
#include "garuda/Domain/IntegerDomain.h"
#include "garuda/Group/GroupDomain.h"
#include "garuda/Group/GroupDomainManager.h"

using namespace garuda;

int main() {
    std::cout << "Garuda Static Analysis Framework\n";
    std::cout << "================================\n\n";

    auto group_mgr = std::make_shared<GroupDomainManager>();
    
    auto g1 = group_mgr->createGroup("values");
    g1->setTop();
    std::cout << "Created group: " << g1->getName() << "\n";
    std::cout << "  isTop: " << (g1->isTop() ? "yes" : "no") << "\n";
    
    auto g2 = group_mgr->createGroup("pointers");
    g2->addMember("ptr1", std::make_unique<IntegerDomain>(0, 100));
    std::cout << "Created group: " << g2->getName() << "\n";
    std::cout << "  members: " << g2->getMemberCount() << "\n";
    
    std::cout << "\nGroups: " << group_mgr->getGroupCount() << "\n";
    for (const auto& name : group_mgr->getGroupNames()) {
        std::cout << "  - " << name << "\n";
    }
    
    std::cout << "\nCycles: " << (group_mgr->detectCycles() ? "yes" : "no") << "\n";
    std::cout << "Topo: ";
    for (const auto& n : group_mgr->topologicalSort()) {
        std::cout << n << " ";
    }
    std::cout << "\n\nDone!\n";
    
    return 0;
}