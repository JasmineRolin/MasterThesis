using Test 
using Dates
using utils 

#==
 Test all domain modules
==#

#==
 Test minutesSinceMidnight 
==#
@testset "minutesSinceMidnight test" begin
    time1 = "08:00:00"
    time2 = "09:45"
    time3 = "test"  # Invalid time

    # Tests
    @test minutesSinceMidnight(time1) == 480
    @test minutesSinceMidnight(time2) == 585
    @test_throws ArgumentError begin
        minutesSinceMidnight(time3)
    end
end
