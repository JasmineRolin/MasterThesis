module States 

using ..VehicleSchedules 
using ..Scenarios
using ..Solutions
using ..Requests

export State 

mutable struct State 
    solution::Solution
    event::Request
    visitedRoute::Dict{Int, Dict{String, Int}} 

    # Constructor
    function State(scenario::Scenario, event::Request)
        return new(Solution(scenario), event, Dict{Int, Dict{String, Int}}())
    end
end



end