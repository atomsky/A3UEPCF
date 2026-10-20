#include "script_component.hpp"

class CfgPatches {
    class a3ue {
        name = "Point Campfire";
        units[] = {};
        weapons[] = {};
        requiredVersion = REQUIRED_VERSION;
        requiredAddons[] = {"A3A_core", "A3A_ultimate"};
        author = "Land_Strider";
        authors[] = { AUTHORS, "Land_Strider" };
        authorUrl = "";
        VERSION_CONFIG;
        A3A_compatibility[] = {12, 2};
    };
};

class A3A 
{
#include "Params.hpp"
#if __A3_DEBUG__
    #include "CfgFunctions.hpp"
#endif
};
#if __A3_DEBUG__
#else
    #include "CfgFunctions.hpp"
#endif