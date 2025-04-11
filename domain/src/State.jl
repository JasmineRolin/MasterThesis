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

    function State(scenario::Scenario, event::Request, visitedRoute::Dict{Int, Dict{String, Int}}, totalNTaxi::Int)
        return new(Solution(scenario), event, visitedRoute, totalNTaxi)
    end

    function State(solution::Solution, event::Request, totalNTaxi::Int)
        return new(solution, event, Dict{Int, Dict{String, Int}}(), totalNTaxi)
    end

    function State(solution::Solution, event::Request, visitedRoute::Dict{Int, Dict{String, Int}}, totalNTaxi::Int)
        return new(solution, event, visitedRoute, totalNTaxi)
    end
end



end