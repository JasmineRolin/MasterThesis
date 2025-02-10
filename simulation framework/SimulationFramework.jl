
module SimulationFramework

using utils

# ------
# Function to split requests into online and offline requests
# ------
function splitRequests(requests::Vector{Request})

    onlineRequests = Request[]
    offlineRequests = Request[]

    for (~,r) in enumerate(requests)
        if r.callTime == 0
            push!(offlineRequests, r)
        else
            push!(onlineRequests, r)
        end
    end

    sort!(onlineRequests, by = x -> x.callTime)

    return onlineRequests, offlineRequests

end


function simulateScenario(scenario::Scenario)




end





end