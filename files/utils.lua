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

function lerp(a, b, t)
    return a*(1-t)+b*t
end

function cubic_bezier(a,b,c,t)
    return lerp(lerp(a,b,t), lerp(b,c,t), t)
end

function bezier(a,b,c,d,t)
    return lerp(cubic_bezier(a,b,c,t), cubic_bezier(b,c,d,t), t)
end

function complexx(ar, ai, br, bi)
    return ar*br-ai*bi, ar*bi+ai*br
end
