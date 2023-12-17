import SimpleTopDownShooter as STDS
import Test

Test.@testset "SimpleTopDownShooter.jl" begin
    Test.@testset "integer_sqrt" begin
        for i in 0:1000
            Test.@test STDS.integer_sqrt(i) == isqrt(i)
        end
    end
end
