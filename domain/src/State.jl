module States 

using ..VehicleSchedules 
using ..Scenarios
using ..Solutions
using ..Requests

export State 

mutable struct State 
    solution::Solution
    event::Request


    # Constructor
    function State(scenario::Scenario, event::Request)
        return new(Solution(scenario), event)
    end
end



end