SPELL_INFO = {}
function SPELL_INFO.get_spell_info()
    --we don't personally need these, but Goki's things does some jank
    local original_BeginProjectile               = BeginProjectile
    local original_OnActionPlayed                = OnActionPlayed
    local original_Reflection_RegisterProjectile = Reflection_RegisterProjectile

    BeginProjectile               = BeginProjectile               or (function() end)
    OnActionPlayed                = OnActionPlayed                or (function() end)
    Reflection_RegisterProjectile = Reflection_RegisterProjectile or (function() end)

    dofile( "data/scripts/gun/gun.lua" );
    reflecting = true

    local action_table = {}
    local projectile_table = {}
    local extra_entity_table = {}

    local original_GlobalsGetValue = GlobalsGetValue
    local original_GlobalsSetValue = GlobalsSetValue

    GlobalsGetValue = function() return nil end
    GlobalsSetValue = function() end

    EntityLoad = function() end

    local original_add_projectile                   = add_projectile
    local original_add_projectile_trigger_timer     = add_projectile_trigger_timer
    local original_add_projectile_trigger_hit_world = add_projectile_trigger_hit_world
    local original_add_projectile_trigger_death     = add_projectile_trigger_death
    local original_draw_actions                     = draw_actions
    local original_check_recursion                  = check_recursion

    add_projectile = function(entity_filename)
        if(current_action ~= nil) then
            if(projectile_table[entity_filename] == nil) then projectile_table[entity_filename] = {} end
            projectile_table[entity_filename].normal = current_action
        end
    end

    add_projectile_trigger_timer = function(entity_filename)
        if(current_action ~= nil) then
            if(projectile_table[entity_filename] == nil) then projectile_table[entity_filename] = {} end
            projectile_table[entity_filename].timer = current_action
        end
    end

    add_projectile_trigger_hit_world = function(entity_filename)
        if(current_action ~= nil) then
            if(projectile_table[entity_filename] == nil) then projectile_table[entity_filename] = {} end
            projectile_table[entity_filename].trigger = current_action
        end
    end

    add_projectile_trigger_death = function(entity_filename)
        if(current_action ~= nil) then
            if(projectile_table[entity_filename] == nil) then projectile_table[entity_filename] = {} end
            projectile_table[entity_filename].death_trigger = current_action
        end
    end

    check_recursion = function(data, recursion_level) return -1 end

    draw_actions = function( how_many, instant_reload_if_empty )
        c.draw_many_count = how_many
    end

    for i, action in ipairs(actions) do
        ConfigGunActionInfo_Init(c)
        ConfigGunShotEffects_Init(shot_effects)
        current_action = action
        action.action()
        action.c = {}
        ConfigGunActionInfo_Copy(c, action.c)

        for entity_filename in string.gmatch(c.extra_entities, "[^ ,]+") do
            extra_entity_table[entity_filename] = current_action
        end
        action_table[action.id] = action
    end

    add_projectile                   = original_add_projectile
    add_projectile_trigger_timer     = original_add_projectile_trigger_timer
    add_projectile_trigger_hit_world = original_add_projectile_trigger_hit_world
    add_projectile_trigger_death     = original_add_projectile_trigger_death
    draw_actions                     = original_draw_actions
    check_recursion                  = original_check_recursion

    GlobalsGetValue = original_GlobalsGetValue
    GlobalsSetValue = original_GlobalsSetValue

    BeginProjectile               = original_BeginProjectile
    -- OnActionPlayed                = original_OnActionPlayed
    Reflection_RegisterProjectile = original_Reflection_RegisterProjectile

    return action_table, projectile_table, extra_entity_table
end
