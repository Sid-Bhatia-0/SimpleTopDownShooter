import Test
include("utils.jl")

Test.@testset begin
    for i in 0:1000
        Test.@test integer_sqrt(i) == isqrt(i)
    end
end
