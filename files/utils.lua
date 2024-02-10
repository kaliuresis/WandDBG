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

function copy_table(t)
    local out = {}
    for i, a in pairs(t) do
        -- table.insert(out, a)
        out[i] = a
    end
    return out
end

function projectile_list_add(list, element)
    local entry = projectile_table[element]
    local i = entry and entry.i or 1
    for j = 1,#list,2 do
        if(list[j] == i) then
            list[j+1] = list[j+1]+1
            return
        end
    end
    table.insert(list, i)
    table.insert(list, 1)
end

-- function comma_multiplicity_list_add(list, new_element)
--     --NOTE: this can fail if elements can contain a * character, or if they can be substrings of each other
--     -- but this is fine since it's only used for filenames
--     local i, j = string.find(list, new_element)
--     if(i ~= nil) then
--         local  pre = string.sub(list, 1, j)
--         local post = string.sub(list, j+1)
--         local n = 1
--         local i, j = string.find(post, "%*%d+")
--         if(i==1) then
--             n = tonumber(string.sub(post,2,j))
--             post = string.sub(post,j+1)
--         end
--         list = pre.."*"..(n+1)..post
--         return list
--     end
--     list = list..new_element..";"
--     return list
-- end

-- function comma_multiplicity_list_iter(list)
--     return function()
--         local mult_i, mult_j = string.find(list, "%*%d+")
--         local comma_i, comma_j = string.find(list, ";")
--         if(not comma_i) then
--             return
--         end
--         local n = 1
--         local item_end = comma_i
--         if(mult_i~=nil and mult_i < comma_i) then
--             n = tonumber(string.sub(list, mult_i+1, mult_j))
--             item_end = mult_i
--         end
--         local item = string.sub(list, 1, item_end-1)
--         list = string.sub(list, comma_j+1)
--         -- GamePrint(item.." x "..n)
--         return item, n
--     end
-- end

-- function format_comma_list(text)
--     local counts = {}
--     for item in string.gmatch(text, "[^ ,]+") do
--         counts[item] = (counts[item] or 0)+1
--     end
--     local formatted = ""
--     for i, n in pairs(counts) do
--         formatted = formatted..i
--         if(n ~= 1) then
--             formatted = formatted.." (x"..n..")"
--         end
--         formatted = formatted..", "
--     end
--     return formatted
-- end

-- function make_format_comma_list_with_images(get_image)
--     return function(text)
--         local counts = {}
--         for item in string.gmatch(text, "[^ ,]+") do
--             counts[item] = (counts[item] or 0)+1
--         end
--         local formatted = {}
--         for i, n in pairs(counts) do
--             table.insert(formatted, {get_image(i), i})
--             if(n ~= 1) then
--                 table.insert(formatted, "x"..n.." ")
--             else
--                 table.insert(formatted, " ")
--             end
--         end
--         return formatted
--     end
-- end

function get_projectile_action(entity_filename)
    local action = projectile_table[entity_filename]
    if(action == nil) then
        return nil
    end
    if(action.normal ~= nil) then
        return action.normal
    elseif(action.timer ~= nil) then
        return action.timer
    elseif(action.trigger ~= nil) then
        return action.trigger
    elseif(action.death_trigger ~= nil) then
        return action.death_trigger
    end
    return nil
end

function get_projectile_icon(entity_filename)
    local action = projectile_table[entity_filename]
    if(action == nil) then
        return "data/ui_gfx/gun_actions/unidentified.png"
    end
    if(action.normal ~= nil) then
        return action.normal.sprite
    elseif(action.timer ~= nil) then
        return action.timer.sprite
    elseif(action.trigger ~= nil) then
        return action.trigger.sprite
    elseif(action.death_trigger ~= nil) then
        return action.death_trigger.sprite
    end
    return "data/ui_gfx/gun_actions/unidentified.png"
end

function format_projectiles(list)
    local formatted = {}
    for j = 1,#list,2 do
        local e = list[j]
        local n = list[j+1]
        local item = projectile_list[e]
        table.insert(formatted, {get_projectile_icon(item), item})
        if(n ~= 1) then
            table.insert(formatted, "x"..n.." ")
        elseif(last_e) then
            table.insert(formatted, " ")
        end
    end
    return formatted
end

function format_cast_state_list(list)
    local formatted = {}
    for identifier, n in pairs(list) do
        -- local action_id = string.match(identifier, "[^:]*")
        local action_id = string.match(identifier, "[^{]*")
        local items = string.sub(identifier, #action_id+2,-2)
        local action_sprite
        local action = action_table[action_id]
        if(action ~= nil) then
            action_sprite = action.sprite
        else
            action_sprite = "data/ui_gfx/gun_actions/unidentified.png"
        end
        table.insert(formatted, {action_sprite, items})
        if(n ~= 1) then
            table.insert(formatted, "x"..n.." ")
        else
            table.insert(formatted, " ")
        end
    end
    return formatted
end
