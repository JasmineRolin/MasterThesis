module onlinesolution

include("onlineSolutionUtils.jl")
using .onlineSolutionUtils
export updateTimeWindowsOnline! 
export onlineAlgorithm

include("OnlineSolutionResults.jl")
using .OnlineSolutionResults
export createGantChartOfSolutionOnline,writeOnlineKPIsToFile, createGantChartOfSolutionAndEventOnline

end
