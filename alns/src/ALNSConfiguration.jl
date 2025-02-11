module ALNSConfigurations 

using .ALNSParameters, .GenericMethods

#==
 Struct to describe configuration of ALNS algorithm 
==#
struct ALNSConfiguration
    destroyMethods::Vector{GenericMethod}
    repairMethods::Vector{GenericMethod}
    parameters::ALNSParameter
end



end