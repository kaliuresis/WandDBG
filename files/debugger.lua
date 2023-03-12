init_debugger = function()
    debugging = true
    dofile( "data/scripts/gun/gun.lua" );

    --Undo the modifications from Spell Lab
    function register_action( state )
        state.reload_time = current_reload_time
        ConfigGunActionInfo_PassToGame( state )
    end

    local cast_history = {}

    local action_trees = {}
    local current_node = nil
    local current_explanation = ""
    local shot_type = "root"
    local timeout_frames = 0

    local removed_actions = {}
    local inserted_actions = {}

    local uses_table = {}

    local table_insert = table.insert
    local table_remove = table.remove

    local original_order_deck = order_deck
    function order_deck()
        for i, a in ipairs(deck) do
            a.temp_index = i
        end
        original_order_deck()
        local order = {}
        for i, a in ipairs(deck) do
            order[i] = a.temp_index
            a.temp_index = nil
        end
        make_snapshot("order_deck", {order=order})
    end

    function move_discarded_to_deck()
        for i,action in ipairs(discarded) do
            table.insert(deck, action)
        end
        discarded = copy_table(discarded)
        while #discarded > 0 do
            table.remove(discarded, 1)
        end
    end

    function move_hand_to_discarded()
        for i,action in ipairs(hand) do

            local identify = false

            if got_projectiles or (action.type == ACTION_TYPE_OTHER) or (action.type == ACTION_TYPE_UTILITY) then -- ACTION_TYPE_MATERIAL, ACTION_TYPE_PROJECTILE are handled via got_projectiles
                if action.uses_remaining > 0 then
                    if action.custom_uses_logic then
                        -- do nothing
                    elseif action.is_identified then
                        -- consume consumable actions
                        action.uses_remaining = action.uses_remaining - 1
                        local reduce_uses = ActionUsesRemainingChanged( action.inventoryitem_id, action.uses_remaining )
                        if not reduce_uses then
                            action.uses_remaining = action.uses_remaining + 1 -- cancel the reduction
                        end
                    end
                end

                identify = true
            end

            if identify then
                ActionUsed( action.inventoryitem_id )
                action.is_identified = true
            end

            if use_game_log then
                if action.is_identified then
                    LogAction( action.name )
                else
                    LogAction( "?" )
                end
            end

            if action.uses_remaining ~= 0 or action.custom_uses_logic then
                if action.permanently_attached == nil then
                    table.insert( discarded, action )
                end
            end
        end
        hand = copy_table(hand)
        while #hand > 0 do
            if hand[1].permanently_attached == nil then
                table.remove(hand, 1)
            else
                make_snapshot("delete_ac_card", {source = "hand", index = 1, unique_ac_id = hand[1].unique_ac_id})
                table_remove(hand, 1)
            end
        end
    end

    function action_reset()
        current_reload_time = current_reload_time - 25

        for i,v in ipairs( hand ) do
            -- print( "removed " .. v.id .. " from hand" )
            table.insert( discarded, v )
        end

        for i,v in ipairs( deck ) do
            -- print( "removed " .. v.id .. " from deck" )
            table.insert( discarded, v )
        end

        hand = copy_table(hand)
        deck = copy_table(deck)

        while #hand > 0 do
            table.remove(hand, 1)
        end
        while #deck > 0 do
            table.remove(deck, 1)
        end

        if ( force_stop_draws == false ) then
            force_stop_draws = true
            move_discarded_to_deck()
            order_deck()
        end
    end

    function copy_table(t)
        local out = {}
        for _, a in ipairs(t) do
            table.insert(out, a)
        end
        return out
    end

    cast_state_list_metatable = {
        __concat = function(a,b)
            local action_id = ""
            if(current_node == nil) then
                action_id = "from_wand"
                -- a[1] = a[1].."from_wand:"..b
            else
                action_id = current_node.action.id
                -- a[1] = a[1]..current_node.action.id..":"..b
            end

            local identifier = action_id.."{"..b.."}"
            a[1] = comma_multiplicity_list_add(a[1], identifier)

            -- for i, e in ipairs(a) do
            --     if(e.items==b and e.action_id==action_id) then
            --         e.count = e.count+1
            --         return a
            --     end
            -- end
            -- table.insert(a, {items=b, action_id=action_id, count=1})
            return a
        end,
    }
    function new_cast_state_list()
        local list = {""}
        setmetatable(list, cast_state_list_metatable)
        return list
    end


    local cast_state_maybe_changed = false
    function make_snapshot(event_type, info, copy_c)
        local event = {
            type = event_type,
            info = info,
            node = current_node,
            c_final = c,
        }
        if(c.last_copy == nil or copy_c or cast_state_maybe_changed) then
            event.c = {}
            ConfigGunActionInfo_Copy(c, event.c)
            c.last_copy = event.c
            cast_state_maybe_changed = false
        else
            event.c = c.last_copy
        end
        table.insert(cast_history, event)
    end

    ConfigGunActionInfo_PassToGame = function()
    end

    ConfigGunShotEffects_PassToGame = function()
    end

    OnNotEnoughManaForAction = function()
        --GamePrint("not enough mana")
    end

    BeginProjectile = function(entity_filename)
        current_projectile = entity_filename
        c.projectiles = comma_multiplicity_list_add(c.projectiles, entity_filename)
    end
    EndProjectile = function()
        current_projectile = ""
    end
    BeginTriggerTimer = function(frames)
        shot_type = "timer"
        timeout_frames = frames
    end
    BeginTriggerHitWorld = function()
        shot_type = "trigger"
    end
    BeginTriggerDeath = function()
        shot_type = "death_trigger"
    end
    EndTrigger = function()
    end
    SetProjectileConfigs = function()
    end

    local reloaded = false
    StartReload = function()
        reloaded = true
        --GamePrint("not enough mana")
    end

    ActionUsed = function(inventoryitem_id) end

    OnActionPlayed = function(action_id)
        if(action_id == nil) then action_id = "nil" end
        --GamePrint("action " .. action_id .. " played")
    end

    ActionUsesRemainingChanged = function(inventoryitem_id, uses_remaining)
        if(uses_remaining < 0) then
            return false
        end
        uses_table[inventoryitem_id] = uses_remaining
        return true
    end

    draw_shot = function( shot, instant_reload_if_empty )
        local c_old = c

        c = shot.state

        c.shot_type = shot_type
        if(shot_type == "timer") then
            c.timer = timeout_frames
        end
        c.parent_projectile = current_projectile
        c.root_node = current_node

        if(c_old ~= c) then
            c_old_copy = {}
            ConfigGunActionInfo_Copy(c_old, c_old_copy)
            make_snapshot("new_cast_state", {c_old=c_old_copy, c_old_final=c_old}, true)
        end

        shot_structure = {}
        draw_actions( shot.num_of_cards_to_draw, instant_reload_if_empty )
        register_action( shot.state )
        SetProjectileConfigs()

        make_snapshot("register_action", {}, true)

        c = c_old
    end


    local draw_total = 0
    local draw_step = 0
    local original_draw_actions = draw_actions
    draw_actions = function(how_many, instant_reload_if_empty)
        draw_total = how_many
        draw_step = 0
        if(current_node ~= nil) then
            current_node.draw_how_many = how_many
            if(dont_draw_actions) then
                current_node.dont_draw_actions = true
            end
            if(playing_permanent_card) then
                current_node.playing_permanent_card = true
            end
        end
        original_draw_actions(how_many, instant_reload_if_empty)
    end

    local original_draw_action = draw_action
    draw_action = function(instant_reload_if_empty)
        local old_explanation = current_explanation
        current_explanation = "draw"
        draw_step = draw_step+1
        local out = original_draw_action(instant_reload_if_empty)
        if(not out) then
            draw_step = draw_step-1
        end
        current_explanation = old_explanation
        return out
    end

    local original_check_recursion = check_recursion
    check_recursion = function(data, rec_)
        local rec = original_check_recursion(data, rec_)
        if(rec == -1) then
            local node = {parent = current_node, children = {}, action = data, rec = recursion_level, iter = iteration, explanation=current_explanation, recursion_limited=true, event_index = #cast_history, end_event_index = #cast_history}
            table.insert(current_node.children, node)
        end
        return rec
    end

    local adding_always_cast = false

    local ac_play_actions = function(action)
        OnActionPlayed( action.id )

        table_insert(hand, action)
        adding_always_cast = true

        set_current_action( action )
        action.action()

        local is_projectile = false

        if action.type == ACTION_TYPE_PROJECTILE then
            is_projectile = true
            got_projectiles = true
        end

        if  action.type == ACTION_TYPE_STATIC_PROJECTILE then
            is_projectile = true
            got_projectiles = true
        end

        if action.type == ACTION_TYPE_MATERIAL then
            is_projectile = true
            got_projectiles = true
        end

        if is_projectile then
            for i,modifier in ipairs(active_extra_modifiers) do
                extra_modifiers[modifier]()
            end
        end

        current_reload_time = current_reload_time + ACTION_DRAW_RELOAD_TIME_INCREASE
    end

    function modify_action(action, is_always_cast)
        local original_action = action.action
        if(action.id == "RESET") then
            original_action = action_reset
        end
        action.original_action = action.original_action or original_action
        action.action = function( recursion_level, iteration )
            local node = {parent = current_node, children = {}, action = action, rec = recursion_level, iter = iteration, explanation=current_explanation}
            if(current_explanation == "draw") then
                node.draw_step = draw_step
                node.draw_total = draw_total
            end
            table.insert(current_node.children, node)
            current_node = node
            if(is_always_cast and adding_always_cast) then
                make_snapshot("add_ac_card", {dest = "hand"})
                adding_always_cast = false
            end
            current_explanation = action.id
            make_snapshot("action", {recursion_level=recursion_level, iteration=iteration})
            cast_state_maybe_changed = true
            node.event_index = #cast_history
            local ret = action.original_action(recursion_level, iteration)
            make_snapshot("action_end", {recursion_level=recursion_level, iteration=iteration}, true)
            node.end_event_index = #cast_history
            current_node = node.parent
            current_explanation = node.explanation
            return ret
        end
    end

    for i, action in ipairs(actions) do
        modify_action(action, false)
    end

    function debug_wand(wand_deck, wand_stats)
        dbglog_y = 0
        mana = wand_stats.mana

        cast_history = {}
        action_trees = {}

        removed_actions = {}
        inserted_actions = {}

        _clear_deck( false )
        local start_deck = {}
        local always_casts = {}
        uses_table = {}

        if(wand_deck ~= nil) then

            -- GamePrint("maximize_uses = "..tostring(wand_stats.maximize_uses) .. ", unlimited_spells = "..tostring(wand_stats.unlimited_spells))
            for i, card in ipairs(wand_deck) do
                local inventoryitem_id = i
                local is_identified = true

                for j, action in ipairs(actions) do
                    if action.id == card.id then
                        action_clone = {}
                        clone_action( action, action_clone )
                        action_clone.original_action = action.original_action

                        if(card.is_always_cast) then
                            action_clone.permanently_attached = true
                            action_clone.uses_remaining = -1
                            action_clone.sprite = action.sprite
                            action_clone.deck_index = nil
                            table.insert(always_casts, action_clone)
                        else
                            action_clone.inventoryitem_id = inventoryitem_id
                            action_clone.uses_remaining   = card.uses_remaining or -1
                            action_clone.deck_index       = #deck
                            action_clone.is_identified    = is_identified
                            action_clone.sprite = action.sprite
                            if(action.max_uses ~= nil and action.max_uses ~= -1 and wand_stats.maximize_uses ~= nil) then
                                action_clone.uses_remaining = wand_stats.maximize_uses and action.max_uses or 0
                            end
                            if(wand_stats.unlimited_spells and not action.never_unlimited) then
                                action_clone.uses_remaining = -1
                            end
                            -- GamePrint(action.id.." uses = "..action_clone.uses_remaining)
                            uses_table[action_clone.inventoryitem_id] = action_clone.uses_remaining
                            table.insert(deck, action_clone)
                        end
                        break
                    end
                end
            end

            for j, action in ipairs(deck) do
                table.insert(start_deck, action)
            end
        end

        -- for i, action in ipairs(deck) do
        --     modify_action(action, false)
        -- end

        table.insert = function(t, i)
            local table_name
            if(t == discarded) then table_name = "discarded" end
            if(t == hand)      then table_name = "hand" end
            if(t == deck)      then table_name = "deck" end
            if(table_name ~= nil) then
                local found_matching_action = false
                for j, r in ipairs(removed_actions) do
                    if (r.action == i) then
                        -- GuiText(gui, dbglog_x, dbglog_y, i.id .. " " .. table_name .. " <- " .. r.table_name)
                        -- dbglog_y = dbglog_y+10
                        make_snapshot("card_move", {source = r.table_name, dest = table_name, index = r.index})
                        table_remove(removed_actions, j)
                        found_matching_action = true
                        break
                    end
                end
                if(not found_matching_action) then
                    table_insert(inserted_actions, {table_name = table_name, action = i})
                end
            end

            return table_insert(t, i)
        end

        table.remove = function(t, index)
            local table_name
            if(t == discarded) then table_name = "discarded" end
            if(t == hand)      then table_name = "hand" end
            if(t == deck)      then table_name = "deck" end
            if(table_name ~= nil) then
                local i = t[index]
                local found_matching_action = false
                for j, r in ipairs(inserted_actions) do
                    if (r.action == i) then
                        -- GuiText(gui, dbglog_x, dbglog_y, i.id .. " " .. r.table_name .. " <- " .. table_name)
                        -- dbglog_y = dbglog_y+10
                        make_snapshot("card_move", {source = table_name, dest = r.table_name, index = index})
                        table_remove(inserted_actions, j)
                        found_matching_action = true
                        break
                    end
                end
                if(not found_matching_action) then
                    table_insert(removed_actions, {table_name = table_name, action = i, index = index})
                end
            end

            return table_remove(t, index)
        end

        local original_ConfigGunActionInfo_Init = ConfigGunActionInfo_Init
        local original_ConfigGunActionInfo_Copy = ConfigGunActionInfo_Copy

        ConfigGunActionInfo_Init = function (value)
            value.projectiles = ""
            original_ConfigGunActionInfo_Init( value )
            value.extra_entities = new_cast_state_list()
        end

        ConfigGunActionInfo_Copy = function(source, dest)
            dest.projectiles = source.projectiles
            original_ConfigGunActionInfo_Copy(source, dest)
            dest.extra_entities = copy_table(source.extra_entities)
            setmetatable(dest.extra_entities, cast_state_list_metatable)
        end


        local original_GameGetFrameNum                          = GameGetFrameNum
        local original_EntityGetWithTag                         = EntityGetWithTag
        local original_EntityGetInRadiusWithTag                 = EntityGetInRadiusWithTag
        local original_GetUpdatedEntityID                       = GetUpdatedEntityID
        local original_EntityGetComponent                       = EntityGetComponent
        local original_EntityGetFirstComponent                  = EntityGetFirstComponent
        local original_EntityInflictDamage                      = EntityInflictDamage
        local original_EntityGetTransform                       = EntityGetTransform
        local original_EntityLoad                               = EntityLoad
        local original_EntityGetAllChildren                     = EntityGetAllChildren
        local original_EntityGetName                            = EntityGetName
        local original_EntityHasTag                             = EntityHasTag
        local original_EntityGetFirstComponentIncludingDisabled = EntityGetFirstComponentIncludingDisabled
        local original_ComponentGetValue2                       = ComponentGetValue2
        local original_ComponentSetValue2                       = ComponentSetValue2

        local zeta_list = {}

        for i, s in ipairs(wand_stats.zeta_options) do
            table.insert(zeta_list, { name="", tags="",
                                      components = {{type_name = "ItemActionComponent", tags="", action_id=s}},
                                      children = {}})
        end

        local player = {
            name = "player", tags="player_unit",
            components = {
                {type_name = "DamageModelComponent", tags="",
                 hp = wand_stats.hp, max_hp = wand_stats.max_hp,
                 damage_multipliers = wand_stats.damage_multipliers,
                 n_stainless = wand_stats.n_stainless,
                 ambrosia = wand_stats.ambrosia,
                },
                {type_name = "WalletComponent", tags="",
                 mHasReachedInf = 0, mMoneyPrevFrame = wand_stats.money, money = wand_stats.money, money_spent = 0},
                {type_name = "Inventory2Component", tags="", mActiveItem = {}},
            },
            children = {
                { -- inventory_quick
                    name = "inventory_quick", tags="",
                    components = {},
                    children = {
                        { -- wand with all zeta options
                            name="wand", tags="wand,",
                            components = {},
                            children = zeta_list
                        }
                    }
                }
            }
        }

        local entities = {player}

        n_entities_with_tag = {
            homing_target = wand_stats.n_enemies,
            projectile = wand_stats.n_projectiles,
            black_hole_giga = wand_stats.n_omega_black_holes,
        }

        if(wand_stats.frame_number) then
            GameGetFrameNum                      = function()
                return wand_stats.frame_number
            end
        end
        EntityGetWithTag                         = function(tag)
            local matches = {}
            for i,e in ipairs(entities) do
                if(string.find(","..e.tags, ","..tag..",")) then
                    table.insert(matches, e)
                end
            end

            n_matches = n_entities_with_tag[tag] or 0
            for i=#matches,n_matches do
                matches[i] = 0
            end
            return matches
        end
        EntityGetInRadiusWithTag                 = function(x, y, r, tag)
            return EntityGetWithTag(tag)
        end
        GetUpdatedEntityID                       = function() return player end
        EntityGetComponent                       = function(entity_id, component_type_name, tag)
            components = {}
            for i, c in ipairs(player.components) do
                if(c.type_name == component_type_name and (tag==nil or string.find(","..c.tags, ","..tag..","))) then
                    table.insert(components, c)
                end
            end
            return components
        end
        EntityGetFirstComponent                  = function(entity_id, component_type_name, tag)
            if(entity_id) then
                for i, c in ipairs(entity_id.components) do
                    if(c.type_name == component_type_name and (tag==nil or string.find(","..c.tags, ","..tag..","))) then
                        return c
                    end
                end
            end
            return nil
        end
        EntityGetFirstComponentIncludingDisabled = EntityGetFirstComponent
        EntityInflictDamage = function(entity, amount, damage_type, description, ragdoll_fx, impulse_x, impulse_y, entity_who_is_responsible, world_pos_x, world_pos_y, knockback_force)
            local comp = EntityGetFirstComponent(entity, "DamageModelComponent")
            if(comp ~= nil and not comp.ambrosia) then
                local type = string.lower(string.sub(damage_type, 8)) -- a bit hacky, but I think this works
                comp.hp = comp.hp-amount*comp.damage_multipliers[type]*math.pow(0.5, comp.n_stainless)
            end
        end
        EntityGetTransform                       = function(entity_id) return 0,0,0,1,1 end
        EntityLoad                               = function(entity_id) end
        EntityGetAllChildren                     = function(entity_id) if(entity_id) then return entity_id.children end end
        EntityGetName                            = function(entity_id) if(entity_id) then return entity_id.name end end
        EntityHasTag                             = function(entity_id, tag) if(entity_id) then return string.find(","..entity_id.tags, ","..tag..",") end end
        ComponentGetValue2                       = function(component_id, variable_name) return component_id[variable_name] end
        ComponentSetValue2                       = function(component_id, variable_name, value) component_id[variable_name] = value end

        local every_other_state = tonumber(GlobalsGetValue( "GUN_ACTION_IF_HALF_STATUS", "0"))
        if(wand_stats.every_other_state~=nil) then
            GlobalsSetValue( "GUN_ACTION_IF_HALF_STATUS", wand_stats.every_other_state and "1" or "0")
        end

        gun = wand_stats.gun_config
        state_from_game = {}
        ConfigGunActionInfo_Init(state_from_game)
        for m, v in pairs(wand_stats.gunaction_config) do
            if(m == "extra_entities") then
                if(v ~= nil and v ~= "") then
                    state_from_game.extra_entities = state_from_game.extra_entities..v
                end
            else
                state_from_game[m] = v
            end
        end
        -- if gun.shuffle_deck_when_empty then
        --     GamePrint("Shuffle Deck When Empty: yes")
        -- else
        --     GamePrint("Shuffle Deck When Empty: no")
        -- end

        -- GuiText(gui, dbglog_x, dbglog_y,'starting shot')
        -- dbglog_y = dbglog_y+10

        --GamePrint("cards in deck: " .. #deck)
        first_shot   = true
        reloading    = false
        start_reload = false
        got_projectiles = false

        local cast_limit = 26

        reloaded = false

        local cast_number = 1
        while(not reloaded or #deck > #start_deck) do
            _start_shot(wand_stats.mana)

            current_node = {parent = nil, children = {}, cast_number = cast_number, c = c}
            table.insert(action_trees, current_node)
            cast_number = cast_number+1

            local old_table_insert = table.insert
            playing_permanent_card = true
            current_explanation = "always_cast"
            for ac, action in ipairs(always_casts) do
                action_clone = {}
                clone_action(action, action_clone)
                action_clone.original_action = action.original_action
                action_clone.permanently_attached = true
                action_clone.uses_remaining   = -1
                action_clone.sprite = action.sprite

                modify_action(action_clone, true)

                handle_mana_addition(action_clone)
                ac_play_actions(action_clone)
            end
            playing_permanent_card = false
            table.insert = old_table_insert

            shot_type = "root"
            _draw_actions_for_shot(false)
            _handle_reload()
            -- draw_shot(root_shot, false)
            -- move_hand_to_discarded()
            make_snapshot("cast_done", {}, true)
            cast_limit = cast_limit - 1
            if(cast_limit == 0) then
                break
            end
        end

        table.insert = table_insert
        table.remove = table_remove

        ConfigGunActionInfo_Init = original_ConfigGunActionInfo_Init
        ConfigGunActionInfo_Copy = original_ConfigGunActionInfo_Copy

        GameGetFrameNum                          = original_GameGetFrameNum
        EntityGetWithTag                         = original_EntityGetWithTag
        EntityGetInRadiusWithTag                 = original_EntityGetInRadiusWithTag
        GetUpdatedEntityID                       = original_GetUpdatedEntityID
        EntityGetComponent                       = original_EntityGetComponent
        EntityGetFirstComponent                  = original_EntityGetFirstComponent
        EntityInflictDamage                      = original_EntityInflictDamage
        EntityGetTransform                       = original_EntityGetTransform
        EntityLoad                               = original_EntityLoad
        EntityGetAllChildren                     = original_EntityGetAllChildren
        EntityGetName                            = original_EntityGetName
        EntityHasTag                             = original_EntityHasTag
        EntityGetFirstComponentIncludingDisabled = original_EntityGetFirstComponentIncludingDisabled
        ComponentGetValue2                       = original_ComponentGetValue2
        ComponentSetValue2                       = original_ComponentSetValue2

        -- GuiText(gui, dbglog_x, dbglog_y,'ending shot')
        -- dbglog_y = dbglog_y+10

        GlobalsSetValue("GUN_ACTION_IF_HALF_STATUS", tostring(every_other_state))

        return cast_history, action_trees, start_deck, always_casts
    end

    return debug_wand
    end
