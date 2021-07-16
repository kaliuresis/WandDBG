dofile_once("data/scripts/lib/utilities.lua")

local entity_id = GetUpdatedEntityID()
local x, y, theta = EntityGetTransform( entity_id )

local x_targe, y_target, omega

local variable_comps = EntityGetComponent(player, "VariableStorageComponent")
if(comps ~= nil) then
    for i, v in ipairs(variable_comps) do
        local n = ComponentGetValue2(v, name)
        if(n == "x_target") then
            x_target = ComponentGetValue2( v, "value_float" )
        end
        if(n == "y_target") then
            y_target = ComponentGetValue2( v, "value_float" )
        end
        if(n == "angular_vel") then
            omega = ComponentGetValue2( v, "value_float" )
        end
    end
end

edit_component(entity_id, "VelocityComponent", function(comp,vars)
    vel_x, vel_y = ComponentGetValueVector2( comp, "mVelocity")

    local rx = x_target-x
    local ry = y_target-y

    local k = 1
    local c = 0.1

    vel_x = (1-c)*vel_x + k*rx
    vel_y = (1-c)*vel_y + k*ry
    omega = omega + vel_x
    ComponentSetValueVector2( comp, "mVelocity", vel_x, vel_y)
end)


local k = 1
local c = 0.1

omega = (1-c)*omega-k*theta
theta = theta + omega

EntitySetTransform(entity_id, x, y, theta)
