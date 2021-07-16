function init_debugger(gui)
    local dbglog_x = 350
    local dbglog_y = 0

    dofile_once( "data/scripts/gun/gun.lua" );

    local cast_history = {}
    local action_stack = {}

    local action_trees = {}
    local current_action_node = nil
    local current_explanation = ""

    local base_actions = {}
    local base_action = true

    local removed_actions = {}
    local inserted_actions = {}

    local table_insert = table.insert
    local table_remove = table.remove

    local original_order_deck = order_deck
    function order_deck()
        original_order_deck()
        local order = {}
        for i, a in ipairs(deck) do
            order[a.deck_index] = i
        end
        make_snapshot("order_deck", {order=order})
    end

    function move_discarded_to_deck()
        for i,action in ipairs(discarded) do
            table.insert(deck, action)
        end
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

    function make_snapshot(event_type, info)
        local event = {
            type = event_type,
            info = info,
            -- discarded = copy_table(discarded),
            -- hand = copy_table(hand),
            -- deck = copy_table(deck),
            action_stack = copy_table(action_stack),
            c = {}
        }
        ConfigGunActionInfo_Copy(c, event.c)
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
        -- if(current_node and string.sub(current_node.action.id, 1, 4) == "ADD_" and current_node.flavor == nil) then
        --     node.flavor = entity_filename
        -- end
        --GamePrint("not enough mana")
    end

    BeginProjectile = function(entity_filename)
        --GamePrint("BeginProjectile " .. entity_filename)
    end
    EndProjectile = function()
        --GamePrint("EndProjectile")
    end
    BeginTriggerTimer = function(timeout_frames)
        --GamePrint("BeginTriggerTimer " .. timeout_frames)
    end
    BeginTriggerHitWorld = function()
        --GamePrint("BeginTriggerHitWorld")
    end
    BeginTriggerDeath = function()
        --GamePrint("BeginTriggerDeath")
    end
    EndTrigger = function()
        --GamePrint("EndTrigger")
    end
    SetProjectileConfigs = function()
        --GamePrint("SetProjectileConfigs")
    end

    local reloaded = false
    StartReload = function()
        reloaded = true
        --GamePrint("not enough mana")
    end

    EntityLoad = function()
        --GamePrint("not enough mana")
    end

    ActionUsed = function(inventoryitem_id) end

    OnActionPlayed = function(action_id)
        if(action_id == nil) then action_id = "nil" end
        --GamePrint("action " .. action_id .. " played")
        base_action = true
        -- GuiText(gui, dbglog_x, dbglog_y, action_id .. " played")
        -- dbglog_y = dbglog_y + 10
    end

    local draw_total = 0
    local draw_current = 0
    local original_draw_actions = draw_actions
    draw_actions = function(how_many, instant_reload_if_empty)
        -- make_snapshot("draw", {how_many = how_many, instant_reload_if_empty=instant_reload_if_empty, dont_draw_actions=dont_draw_actions})
        if(action_stack[#action_stack] ~= nil) then
            action_stack[#action_stack].draw_step = 0
            action_stack[#action_stack].draw_how_many = how_many
            if(dont_draw_actions) then
                action_stack[#action_stack].draw_how_many = -1
            end
        end
        draw_total = how_many
        draw_current = 0
        current_node.draw = how_many
        if(dont_draw_actions) then
            current_node.dont_draw_actions = true
        end
        if(playing_permanent_card) then
            current_node.playing_permanent_card = true
        end
        original_draw_actions(how_many, instant_reload_if_empty)
    end

    local original_draw_action = draw_action
    draw_action = function(instant_reload_if_empty)
        -- make_snapshot("draw_step", {instant_reload_if_empty=instant_reload_if_empty})
        local current_action = action_stack[#action_stack]
        if(current_action ~= nil) then
            action_stack[#action_stack] = {
                i = current_action.i,
                action = current_action.action,
                base_index = current_action.base_index,
                draw_step = current_action.draw_step+1,
                draw_how_many = current_action.draw_how_many,
            }
        end
        draw_current = draw_current+1
        local old_explanation = current_explanation
        current_explanation = "draw "..draw_current.."/"..draw_total
        original_draw_action(instant_reload_if_empty)
        current_explanation = old_explanation
    end

    function debug_wand(wand_deck, wand_stats)
        dbglog_y = 0
        local wand_mana = 20000;
        mana = wand_mana

        cast_history = {}
        action_stack = {}
        base_actions = {}
        base_action = true

        removed_actions = {}
        inserted_actions = {}

        _clear_deck( false )
        local start_deck = {}
        local always_casts = {}

        if(wand_deck ~= nil) then
            -- for i, action_id in ipairs(wand_deck) do
            --     _add_card_to_deck(action_id, i, -1, true)
            -- end

            for i, action_id in ipairs(wand_deck) do
                local inventory_item_id = i
                local uses_remaining = -1
                local is_identified = true

                for j, action in ipairs(actions) do
                    if action.id == action_id then
                        action_clone = {}
                        clone_action( action, action_clone )
                        action_clone.inventoryitem_id = inventoryitem_id
                        action_clone.uses_remaining   = uses_remaining
                        action_clone.deck_index       = #deck
                        action_clone.is_identified    = is_identified
                        action_clone.sprite = action.sprite
                        -- debug_print( "uses " .. uses_remaining )
                        -- if(action.never_unlimited == true) then action_clone.uses_remaining = 0 end
                        if(i <= wand_stats.n_always_casts) then
                            action_clone.permanently_attached = true
                            action_clone.uses_remaining = -1
                            action_clone.deck_index = 0
                            table.insert(always_casts, action_clone)
                        else
                            table.insert(deck, action_clone)
                        end
                        break
                    end
                end
            end

            for i, action_id in ipairs(wand_deck) do
                local inventory_item_id = i
                local uses_remaining = -1
                local is_identified = true

                if(i > wand_stats.n_always_casts) then
                    for j, action in ipairs(actions) do
                        if action.id == action_id then
                            action_clone = {}
                            clone_action( action, action_clone )
                            action_clone.inventoryitem_id = inventoryitem_id
                            action_clone.uses_remaining   = uses_remaining
                            action_clone.deck_index       = #start_deck
                            action_clone.is_identified    = is_identified
                            action_clone.sprite = action.sprite
                            -- debug_print( "uses " .. uses_remaining )
                            table.insert(start_deck, action_clone)
                            break
                        end
                    end
                end
            end
        end

        function modify_action(action)
            local original_action = action.action
            if(action.id == "RESET") then
                original_action = action_reset
            end
            action.action = function( recursion_level, iteration )
                local base_index = 0
                if(#action_stack > 0) then
                    base_index = action_stack[#action_stack].base_index
                end
                if(base_action) then
                    table.insert(base_actions, action)
                    base_index = #base_actions
                end

                local indent_level = 1+(recursion_level or 0) + (iteration or 0)
                indent = ""
                for j=1,indent_level do
                    indent = indent .. "  "
                end
                if(base_action) then
                    indent = indent .. "base action " .. base_index .. ": "
                end
                -- GuiText(gui, dbglog_x, dbglog_y, indent .. action.id .. " played")
                -- dbglog_y = dbglog_y + 10

                local node = {parent = current_node, children = {}, action = action, rec = recursion_level, iter = iteration, draw_current = draw_current, draw_total = draw_total, explanation=current_explanation}
                if(current_node == nil) then
                    table.insert(action_trees, node)
                else
                    table.insert(current_node.children, node)
                end
                current_node = node
                current_explanation = action.id
                table.insert(action_stack, {i = #cast_history+1, action = action, base_index = base_index})
                make_snapshot("action", {base_action=base_action, node=node, recursion_level=recursion_level, iteration=iteration})
                node.event_index = #cast_history
                base_action = false
                local ret = original_action(recursion_level, iteration)
                table.remove(action_stack, #action_stack)
                make_snapshot("action_end", {base_action=base_action, recursion_level=recursion_level, iteration=iteration})
                node.end_event_index = #cast_history
                current_node = node.parent
                current_explanation = node.explanation
                return ret
            end
        end

        for i, action in ipairs(always_casts) do
            modify_action(action)
        end

        for i, action in ipairs(deck) do
            modify_action(action)
        end

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

        GlobalsSetValue( "GUN_ACTION_IF_HALF_STATUS", tostring( 0 ) )

        gun = wand_stats.gun_config
        state_from_game = {}
        ConfigGunActionInfo_Init(state_from_game)
        for i, v in ipairs(wand_stats.gunactions_config) do
            state_from_game[i] = v
        end
        if gun.shuffle_deck_when_empty then
           GamePrint("Shuffle Deck When Empty: yes")
        else
           GamePrint("Shuffle Deck When Empty: no")
        end

        -- GuiText(gui, dbglog_x, dbglog_y,'starting shot')
        -- dbglog_y = dbglog_y+10

        --GamePrint("cards in deck: " .. #deck)
        first_shot   = true
        reloading    = false
        start_reload = false
        got_projectiles = false

        local iteration_limit = 100

        reloaded = false

        current_node = nil
        while(not reloaded) do
            _start_shot(wand_mana)

            local old_table_insert = table.insert
            playing_permanent_card = true
            local unique_ac_id = 1
            for ac, action in ipairs(always_casts) do
                handle_mana_addition(action)
                -- table.insert = function(t, i)
                --     local table_name
                --     if(t == discarded) then table_name = "discarded" end
                --     if(t == hand)      then table_name = "hand" end
                --     if(t == deck)      then table_name = "deck" end
                --     if(table_name ~= nil) then
                --         make_snapshot("add_ac_card", {dest = table_name, ac_index = ac})
                --     end
                --     return table_insert(t, i)
                -- end
                -- play_action(action)

                OnActionPlayed( action.id )

                make_snapshot("add_ac_card", {dest = "hand", ac_index = ac, unique_ac_id = unique_ac_id})
                action.unique_ac_id = unique_ac_id
                unique_ac_id = unique_ac_id + 1
                table_insert( hand, action )

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
            playing_permanent_card = false
            table.insert = old_table_insert

            _draw_actions_for_shot(false)
            _handle_reload()
            -- draw_shot(root_shot, false)
            -- move_hand_to_discarded()
            make_snapshot("cast_done", {})
            iteration_limit = iteration_limit - 1
            if(iteration_limit == 0) then
                break
            end
        end

        table.insert = table_insert
        table.remove = table_remove

        -- GuiText(gui, dbglog_x, dbglog_y,'ending shot')
        -- dbglog_y = dbglog_y+10

        return cast_history, base_actions, action_trees, start_deck, always_casts
    end

    return debug_wand
end
