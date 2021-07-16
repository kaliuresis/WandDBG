function clamp(x, a, b)
    return math.max(a, math.min(b, x))
end

function soft_clamp(x, a, b)
    return math.tanh((x-0.5*(a+b))/(b-a))*(b-a)+0.5*(a+b)
end

function sign(x)
    if(x >= 0) then
        return 1
    end
    return -1
end
