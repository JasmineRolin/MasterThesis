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
    totalNTaxi::Int

    # Constructor
    function State(scenario::Scenario, event::Request, totalNTaxi::Int)
        return new(Solution(scenario), event, Dict{Int, Dict{String, Int}}(), totalNTaxi)
    end
end



end