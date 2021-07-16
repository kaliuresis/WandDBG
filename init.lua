base_dir = "mods/wand_dbg/"
dofile_once( base_dir .. "files/debugger.lua" );
dofile_once( base_dir .. "files/utils.lua" );

local gui = GuiCreate()

debug_wand = init_debugger(gui)

local show_wand_dbg = true
local show_tree = true

local current_i = 0
local playing = true
local playback_timer = 20
local looping = true

local last_wand_deck
local cast_history, base_actions, action_trees, start_deck, always_casts, always_cast_cards

local current_action_stack

local discarded = {}
local hand = {}
local deck = {}


-- debug_wand = dofile_once( "mods/wand_dbg/files/debugger.lua" );

function OnWorldInitialized()

end

local _ModTextFileGetContent = ModTextFileGetContent;
function OnWorldPreUpdate()
    -- dofile( "mods/spell_lab/files/gui/update.lua" );
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

local gui_id = 0
function next_id()
    gui_id = gui_id+1
    return gui_id
end

function get_bg_sprite(type)
    local bg_sprite = "data/ui_gfx/inventory/item_bg_"
    if(type == ACTION_TYPE_PROJECTILE) then
        bg_sprite = bg_sprite .. "projectile"
    elseif(type == ACTION_TYPE_STATIC_PROJECTILE) then
        bg_sprite = bg_sprite .. "static_projectile"
    elseif(type == ACTION_TYPE_MODIFIER) then
        bg_sprite = bg_sprite .. "modifier"
    elseif(type == ACTION_TYPE_DRAW_MANY) then
        bg_sprite = bg_sprite .. "draw_many"
    elseif(type == ACTION_TYPE_MATERIAL) then
        bg_sprite = bg_sprite .. "material"
    elseif(type == ACTION_TYPE_OTHER) then
        bg_sprite = bg_sprite .. "other"
    elseif(type == ACTION_TYPE_UTILITY) then
        bg_sprite = bg_sprite .. "utility"
    elseif(type == ACTION_TYPE_PASSIVE) then
        bg_sprite = bg_sprite .. "passive"
    end
    bg_sprite = bg_sprite .. ".png"
    return bg_sprite
end

local player

local card_sprites
local action_sprites = {}
local dying_action_sprites = {}

function make_debug_card(action)
    return {action = action, x = 0, y = 0, theta = 0, scale = 1.0, dx = 0, dy = 0, dtheta = 0, dscale = 0.0, x_target = 0, y_target = 0}
end

function clear_card_sprites()
    local children = EntityGetAllChildren(player)
    if children ~= nil then
        for i, c in ipairs(children) do
            if(EntityHasTag(c, "dbg_card")) then
                EntityKill(c)
            end
        end
    end
end

function add_sprite(card)
    local bg_sprite = get_bg_sprite(card.action.type)
    local card_sprite = EntityCreateNew("debug_card")
    EntityAddChild(player, card_sprite)
    EntityAddTag(card_sprite, "dbg_card")
    -- EntityAddComponent(card_sprite, "VariableStorageComponent",
    --                    {value_int = i})
    EntityAddComponent(card_sprite, "SpriteComponent",
                        {_tags = "enabled_in_world,ui,no_hitbox,",
                        image_file = bg_sprite,
                        emissive="1",
                        offset_x="10",
                        offset_y="19",
                        -- has_special_scale="1",
                        -- special_scale_x="1.0",
                        -- special_scale_y="1.0",
                        z_index="-1.5"})
    EntityAddComponent(card_sprite, "SpriteComponent",
                        {_tags = "enabled_in_world,ui,no_hitbox,",
                        image_file = card.action.sprite,
                        emissive="1",
                        offset_x="8",
                        offset_y="17",
                        -- has_special_scale="1",
                        -- special_scale_x="1.0",
                        -- special_scale_y="1.0",
                        z_index="-1.51"})
    return card_sprite
end

function clear_action_sprites()
    local children = EntityGetAllChildren(player)
    if(children ~= nil) then
        for i, c in ipairs(children) do
            if(EntityHasTag(c, "dbg_action")) then
                EntityKill(c)
            end
        end
    end
    action_sprites = {}
end

function add_action_sprite(card)
    local bg_sprite = get_bg_sprite(card.action.type)
    local card_sprite = EntityCreateNew("debug_action")
    EntityAddChild(player, card_sprite)
    EntityAddTag(card_sprite, "dbg_action")
    -- EntityAddComponent(card_sprite, "VariableStorageComponent",
    --                    {value_int = i})
    -- EntityAddComponent(card_sprite, "SpriteComponent",
    --                     {_tags = "enabled_in_world,ui,no_hitbox,",
    --                     image_file = bg_sprite,
    --                     emissive="1",
    --                     offset_x="10",
    --                     offset_y="19",
    --                     -- has_special_scale="1",
    --                     -- special_scale_x="1.0",
    --                     -- special_scale_y="1.0",
    --                     z_index="-1.5"})
    EntityAddComponent(card_sprite, "SpriteComponent",
                        {_tags = "enabled_in_world,ui,no_hitbox,",
                        image_file = card.action.sprite,
                        emissive="1",
                        offset_x="8",
                        offset_y="17",
                        -- has_special_scale="1",
                        -- special_scale_x="1.0",
                        -- special_scale_y="1.0",
                        z_index="-1.51"})
    EntityAddComponent(card_sprite, "SpriteComponent",
                        {_tags = "enabled_in_world,ui,no_hitbox,line1,",
                        image_file = "data/fonts/font_pixel_white.xml",
                        is_text_sprite="1",
                        emissive="1",
                        offset_x="15",
                        offset_y="4",
                        text="",
                        has_special_scale="1",
                        special_scale_x="0.6",
                        special_scale_y="0.6",
                        z_index="-1.51"})
    EntityAddComponent(card_sprite, "SpriteComponent",
                        {_tags = "enabled_in_world,ui,no_hitbox,line2,",
                        image_file = "data/fonts/font_pixel_white.xml",
                        is_text_sprite="1",
                        emissive="1",
                        offset_x="15",
                        offset_y="-4",
                        text="",
                        has_special_scale="1",
                        special_scale_x="0.6",
                        special_scale_y="0.6",
                        z_index="-1.51"})
    return card_sprite
end

function push_action(action)
    local new_action_sprite = {sprite=add_action_sprite(action), x = 0, y = 0, theta = 0, scale = 1.0, dx = 0, dy = 0, dtheta = 0, dscale = 0.0, x_target = 0, y_target = 0, line1 = "", line2 = ""}
    table.insert(action_sprites, new_action_sprite)
    return new_action_sprite
end

function pop_action(fadetime)
    local action_sprite = action_sprites[#action_sprites]
    action_sprite.dy = action_sprite.dy+2
    action_sprite.dscale = action_sprite.dscale+1
    action_sprite.lifetime = fadetime
    action_sprite.max_lifetime = fadetime
    table.remove(action_sprites, #action_sprites)
    table.insert(dying_action_sprites, action_sprite)
end

local playback_wait = 20

function animate_card(card, sprite_entity, cx, cy, gui_to_world_scale)
    local rx = 0
    local ry = 0
    if(card.x_target ~= nil and card.y_target ~= nil) then
        rx = card.x_target - card.x
        ry = card.y_target - card.y
    end

    local k = 0.1
    local c = 0.5

    local ddx = -c*card.dx + k*rx
    card.dx = card.dx + ddx
    card.dy = (1.0-c)*card.dy + k*ry

    local k_theta = 0.1
    local c_theta = 0.5
    card.dtheta = (1.0-c)*card.dtheta - k_theta*card.theta
    card.dtheta = card.dtheta - 0.01*ddx

    local k_scale = 0.2
    local c_scale = 0.5
    card.dscale = (1.0-c_scale)*card.dscale + k_scale*(1.0-card.scale)

    card.x = card.x + card.dx
    card.y = card.y + card.dy
    card.theta = card.theta + card.dtheta
    card.scale = card.scale + card.dscale
    if(card.scale < 0.1) then card.scale = 0.1 end

    EntitySetTransform(sprite_entity,
                       cx+gui_to_world_scale*card.x, cy+gui_to_world_scale*card.y, card.theta, card.scale, card.scale)

    local line1 = EntityGetFirstComponent(sprite_entity, "SpriteComponent", "line1")
    local line2 = EntityGetFirstComponent(sprite_entity, "SpriteComponent", "line2")
    if(line1 ~= nil) then
        local old_text = ComponentGetValue2(line1, "text")
        if(card.line1 ~= old_text) then
            ComponentSetValue2(line1, "text", card.line1)
            EntityRefreshSprite(sprite_entity, line1)
        end
    end
    if(line2 ~= nil) then
        local old_text = ComponentGetValue2(line2, "text")
        if(card.line2 ~= old_text) then
            ComponentSetValue2(line2, "text", card.line2)
            EntityRefreshSprite(sprite_entity, line2)
        end
    end
end

function animate_dying_card(card, sprite_entity, cx, cy, gui_to_world_scale)
    local c = 0.1

    local ddx = -c*card.dx
    card.dx = card.dx + ddx
    card.dy = (1.0-c)*card.dy

    local k_theta = 0.1
    local c_theta = 0.5
    card.dtheta = (1.0-c)*card.dtheta - k_theta*card.theta
    card.dtheta = card.dtheta - 0.01*ddx

    local c_scale = 0.1
    card.dscale = (1.0-c_scale)*card.dscale

    card.x = card.x + card.dx
    card.y = card.y + card.dy
    card.theta = card.theta + card.dtheta
    card.scale = card.scale + card.dscale
    if(card.scale < 0.1) then card.scale = 0.1 end

    local alpha = 1
    card.lifetime = card.lifetime-1
    alpha = card.lifetime/card.max_lifetime
    if(card.lifetime <= 0) then
        EntityKill(card.sprite)
        return false
    end

    EntitySetTransform(sprite_entity,
                       cx+gui_to_world_scale*card.x, cy+gui_to_world_scale*card.y, card.theta, card.scale, card.scale)
    local sprites = EntityGetComponent(sprite_entity, "SpriteComponent")
    if(sprites ~= inl) then
        for i, s in ipairs(sprites) do
            ComponentSetValue2(s, "alpha", alpha)
        end
    end
    local line1 = EntityGetFirstComponent(sprite_entity, "SpriteComponent", "line1")
    local line2 = EntityGetFirstComponent(sprite_entity, "SpriteComponent", "line2")
    if(line1 ~= nil) then
        local old_text = ComponentGetValue2(line1, "text")
        if(card.line1 ~= old_text) then
            ComponentSetValue2(line1, "text", card.line1)
            EntityRefreshSprite(sprite_entity, line1)
        end
    end
    if(line2 ~= nil) then
        local old_text = ComponentGetValue2(line2, "text")
        if(card.line2 ~= old_text) then
            ComponentSetValue2(line2, "text", card.line2)
            EntityRefreshSprite(sprite_entity, line2)
        end
    end

    return true
end

function draw_deck(base_x, base_y, cx, cy, gui_to_world_scale, deck, focus_on_end)
    if(focus_on_end == nil) then focus_on_end = true end
    for i, card in ipairs(deck) do
        -- local sprite = card.action.sprite
        -- local bg_sprite = get_bg_sprite(card.action.type)

        -- local im_w, im_h = GuiGetImageDimensions(gui, bg_sprite, scale)

        -- local x_rel = 16*i
        -- local y_rel = 0

        -- GuiImage(gui, next_id(), base_x+x_rel-im_w/2, base_y+y_rel-im_h/2, bg_sprite,
        --          1.0, scale, 0, 0)

        -- im_w, im_h = GuiGetImageDimensions(gui, sprite, scale)
        -- GuiImage(gui, next_id(), base_x+x_rel-im_w/2, base_y+y_rel-im_h/2, sprite,
        --          1.0, scale, 0, 0)

        local spacing = 24
        local max_spacings = 6
        if(#deck > max_spacings) then
            if(focus_on_end) then
                card.x_target = base_x + spacing*max_spacings*(math.exp(-(#deck-i+1)/max_spacings)-math.exp(-(#deck)/max_spacings))
            else
                card.x_target = base_x + spacing*max_spacings*(1-math.exp(-(i-1)/max_spacings))
            end
        else
            card.x_target = base_x + spacing*(i-1)
        end

        card.y_target = base_y + 0.0

        animate_card(card, card.sprite, cx, cy, gui_to_world_scale)
    end
end

function draw_playback(base_x, base_y, width, mx, my)
    local button_width = 8
    local button_spacing = 4
    local bar_width = width - (4*button_width+4*button_spacing)

    local current_i_target = nil
    if(cast_history == nil) then return current_i_target end

    local play_pause = base_dir.."files/ui_gfx/play.png"
    local play_pause_text = "play"
    if(playing) then
        play_pause = base_dir.."files/ui_gfx/pause.png"
        play_pause_text = "pause"
    end
    local loop_text = "loop"
    if(looping) then
        loop_text = "don't loop"
    end

    local x = base_x+bar_width
    x = x+button_spacing
    local prev_pressed = GuiImageButton(gui, next_id(), x, base_y-3.5, "", base_dir.."files/ui_gfx/prev.png")
    GuiTooltip(gui, "previous", "")
    x = x+button_spacing+button_width
    local play_pause_pressed = GuiImageButton(gui, next_id(), x, base_y-3.5, "", play_pause)
    GuiTooltip(gui, play_pause_text, "")
    x = x+button_spacing+button_width
    local next_pressed = GuiImageButton(gui, next_id(), x, base_y-3.5, "", base_dir.."files/ui_gfx/next.png")
    GuiTooltip(gui, "next", "")
    x = x+button_spacing+button_width
    if(not looping) then GuiColorSetForNextWidget( gui, 0.5, 0.5, 0.5, 0.5) end
    local loop_pressed = GuiImageButton(gui, next_id(), x, base_y-3.5, "", base_dir.."files/ui_gfx/loop.png")
    GuiTooltip(gui, loop_text, "")

    if(play_pause_pressed) then
        playing = not playing
    end
    if(loop_pressed) then
        looping = not looping
    end
    if(next_pressed) then
        current_i_target = current_i+1
    end
    if(prev_pressed) then
        current_i_target = current_i-1
    end

    local last_x_rel = 0
    local last_y_rel = 0
    local last_indent_offset = 0

    local base_scale = 0.5
    local scale = base_scale

    local first_action = true

    local j = 0
    local x_rel = 0
    local y_rel = 0

    local mouse_t = clamp((mx-base_x)/bar_width*#cast_history, 0.001, #cast_history)

    local ui_hover = (math.abs(mx-(base_x+bar_width/2)) <= bar_width/2+button_width/2 and math.abs(my-(base_y)) <= button_width)

    --invisible line to block clicks from casting spells
    draw_line(base_x, base_y,
              base_x+bar_width, base_y,
              2*button_width, 0.0, 0)

    draw_line(base_x, base_y,
              base_x+bar_width, base_y,
              1.0, 1.0, 0)
    GuiImage(gui, next_id(), base_x+bar_width*(current_i-1)/#cast_history-3.5, base_y-3.5, base_dir.."files/ui_gfx/big_dot.png",
             1, 1)
    if(ui_hover) then
        local clicked = GuiImageButton(gui, next_id(), base_x+bar_width*mouse_t/#cast_history-50.5, base_y-50.5, "", base_dir.."files/ui_gfx/invisible_button.png")
        GuiText(gui, base_x+bar_width*mouse_t/#cast_history, base_y, math.ceil(mouse_t).."/"..#cast_history)
        GuiImage(gui, next_id(), base_x+bar_width*mouse_t/#cast_history-3.5, base_y-3.5, base_dir.."files/ui_gfx/big_dot.png", 0.5, 1)
       if(clicked) then
           current_i_target = math.ceil(mouse_t)
       end
    end
    if #cast_history < bar_width then
        for i, e in ipairs(cast_history) do
            if(e.type == "action") then
                GuiImage(gui, next_id(), base_x+bar_width*i/#cast_history-1.5, base_y-1.5, base_dir.."files/ui_gfx/small_dot.png",
                         1, 1)
            end
        end
    end

    --         local action = e.action_stack[#e.action_stack]
    --         local sprite = action.action.sprite
    --         local bg_sprite = get_bg_sprite(action.action.type)
    --         local expansion_width = 10
    --         x_rel = clamp((2*expansion_width*math.tanh((i-current_i)/expansion_width)+(width*i)/#cast_history), 0, width)
    --         j = j+1

    --         scale = base_scale*(1+(2/expansion_width)*math.pow(math.cosh((i-current_i)/expansion_width), -2))
    --         -- if(i == current_i) then
    --         --     scale = base_scale*1.5
    --         -- else
    --         --     scale = base_scale
    --         -- end

    --         local im_w, im_h = GuiGetImageDimensions(gui, bg_sprite, scale)

    --         GuiImage(gui, next_id(), base_x+x_rel-im_w/2, base_y+y_rel-im_h/2, bg_sprite,
    --                  1.0, scale, 0, 0)

    --         im_w, im_h = GuiGetImageDimensions(gui, sprite, scale)
    --         GuiImage(gui, next_id(), base_x+x_rel-im_w/2, base_y+y_rel-im_h/2, sprite,
    --                  1.0, scale, 0, 0)
    --         last_x_rel = x_rel
    --         last_y_rel = y_rel
    --         first_action = false
    --     elseif(e.type == "cast_done") then
    --         first_action = true
    --     end
    -- end

    return current_i_target
end

function compress_node(tree)
    tree.str = "(" .. tree.action.id
    local previous_child_string = nil
    for i, c in ipairs(children) do
        if(c.str == nil) then
            compress_node(c)
        end
        if(i != 0) then
            tree.str = tree.str .. " "
        end
        tree.str = tree.str .. c.str
        c.identical_to_previous = (c.str == previous_child_string)
        previous_child_string = c.str
    end
    tree.str = tree.str..")"
end

function draw_node(tree, x_spacing, y_spacing, scale, x, y, parent_x, parent_y)
    local im_w, im_h = GuiGetImageDimensions(gui, bg_sprite, scale)
    GuiImage(gui, next_id(), x-im_w/2, y-im_h/2, bg_sprite,
             1.0, scale, 0, 0)

    im_w, im_h = GuiGetImageDimensions(gui, sprite, scale)
    GuiImage(gui, next_id(), x-im_w/2, y-im_h/2, sprite,
             1.0, scale, 0, 0)

    if(parent_x ~= nil and parent_y ~= nil) then
        local start_x = parent_x+8*base_scale
        local start_y = parent_y
        local end_x = x-8*base_scale
        local end_y = y
        draw_spline(start_x, start_y, start_x+0.5*x_spacing, start_y,
                    end_x-0.5*x_spacing, end_y, end_x, end_y,
                    0.5, 1.0, 0, 4, 1)
    end

    local height = 0
    local drawn_ellipses = false
    for i, c in ipairs(tree.children) do
        local child_x = x+x_spacing
        local child_y = y+height
        if(c.identical_to_previous) then
            if(not drawn_ellipses) then
                --TODO: make this vertical
                GuiText(gui, child_x, child_y,'...')
                height = height + y_spacing
            end
            drawn_ellipses = true
        else
            local child_height = draw_node(c, x_spacing, y_spacing, scale, child_x, child_y, x, y)
            height = height+child_height
            drawn_ellipses = false
        end
    end
    if(#tree.children == 0) then
        height = y_spacing
    end
    return height
end

function draw_tree(tree)
    local base_x = 20
    local base_y = 50
    sub_action_count = {}
    for j, base_action in ipairs(base_actions) do
        sub_action_count[j] = 0
    end
    local x_spacing = 24
    local y_spacing = 8

    local last_x_rel = 0
    local last_y_rel = 0
    local last_indent_offset = 0

    local base_scale = 0.5
    local scale = base_scale

    local current_i_found = false
    local current_i_target = current_i
    local first_action = true
    local stack_positions = {}
    for i, e in ipairs(cast_history) do
        if(e.type == "action") then
            local action = e.action_stack[#e.action_stack]
            local sprite = action.action.sprite
            local bg_sprite = get_bg_sprite(action.action.type)
            local j = action.base_index
            if(e.info.base_action) then
                sub_action_count[j] = 0
                -- elseif(recursion_level) then
            else
                sub_action_count[j] = sub_action_count[j]+1
            end
            -- local x_rel = x_spacing*(j-1)
            -- local y_rel = y_spacing*sub_action_count[j]
            -- local indent_offset = 4*(1+(e.info.recursion_level or 0) + (e.info.iteration or 0))
            local x_rel = x_spacing*#e.action_stack
            local y_rel = last_y_rel
            if(x_rel <= last_x_rel) then
                y_rel = y_rel + y_spacing
            end
            stack_positions[#e.action_stack] = {x = x_rel, y = y_rel}
            local indent_offset = 0

            -- GameCreateSpriteForXFrames(bg_sprite, base_x+x_rel+indent_offset, base_y+y_rel)
            -- GameCreateSpriteForXFrames(sprite, base_x+x_rel+indent_offset, base_y+y_rel)
            local button_width = y_spacing
            -- local ui_hover = (math.abs(mx-(base_x+x_rel+indent_offset)) <= button_width/2
            --                       and math.abs(my-(base_y+y_rel)) <= button_width/2)
            -- if((current_i <= i and (not current_i_found))
            --     or ui_hover) then
            --     if(ui_hover) then current_i_target = i end
            --     current_i_found = true
            --     scale = base_scale*1.5
            -- else
            --     scale = base_scale
            -- end

            local im_w, im_h = GuiGetImageDimensions(gui, bg_sprite, scale)

            GuiImage(gui, next_id(), base_x+x_rel+indent_offset-im_w/2, base_y+y_rel-im_h/2, bg_sprite,
                     1.0, scale, 0, 0)

            im_w, im_h = GuiGetImageDimensions(gui, sprite, scale)
            GuiImage(gui, next_id(), base_x+x_rel+indent_offset-im_w/2, base_y+y_rel-im_h/2, sprite,
                     1.0, scale, 0, 0)
            -- if(not first_action and last_x_rel ~= x_rel) then
            --     draw_line(base_x+last_x_rel+last_indent_offset+8*base_scale, base_y+last_y_rel,
            --               base_x+x_rel+indent_offset-8*base_scale, base_y+y_rel,
            --               0.5, 1.0, 0, 4)
            -- end
            if(stack_positions[#e.action_stack-1] ~= nil) then
                local start_x = base_x+stack_positions[#e.action_stack-1].x+8*base_scale
                local start_y = base_y+stack_positions[#e.action_stack-1].y
                local end_x = base_x+x_rel-8*base_scale
                local end_y = base_y+y_rel
                draw_spline(start_x, start_y, start_x+0.5*x_spacing, start_y,
                            end_x-0.5*x_spacing, end_y, end_x, end_y,
                            0.5, 1.0, 0, 4, 1)
            end

            last_x_rel = x_rel
            last_y_rel = y_rel
            last_indent_offset = indent_offset
            first_action = false
        elseif(e.type == "cast_done") then
            first_action = true
        end
    end

    return current_i_target
end

function draw_line(x1, y1, x2, y2, thickness, alpha, end_spacing, arrow_size, arrow_pos)
    thickness = thickness or 1
    end_spacing = end_spacing or 0
    arrow_pos = arrow_pos or 0.5
    alpha = alpha or 0
    local material_name = "spark_white"
    local sprite = base_dir .. "files/ui_gfx/line_dot.png"
    local dx = (x2-x1)
    local dy = (y2-y1)
    local length = math.sqrt(dx*dx+dy*dy)
    dx = dx/length
    dy = dy/length
    local rotation = math.atan2(-dx, dy)
    local x_off, y_off = complexx(-0.5*thickness, 0.5*thickness, dx, dy)
    GuiImage(gui, next_id(), x1+dx*end_spacing+x_off, y1+dy*end_spacing+y_off, sprite,
             alpha, thickness, length-2*end_spacing, rotation)

    if(arrow_size) then
        local x0 = lerp(x1, x2, arrow_pos)+dx*arrow_size/2
        local y0 = lerp(y1, y2, arrow_pos)+dy*arrow_size/2
        local xt, yt = complexx(-arrow_size, arrow_size/2, dx,dy)
        draw_line(x0, y0, x0+xt, y0+yt, thickness, alpha)
        xt, yt = complexx(-arrow_size, -arrow_size/2, dx,dy)
        draw_line(x0, y0, x0+xt, y0+yt, thickness, alpha)
    end
end

function draw_spline(x0, y0, x1, y1, x2, y2, x3, y3, thickness, alpha, end_spacing, arrow_size, arrow_pos, segment_spacing)
    segment_spacing = segment_spacing or 0.05
    arrow_pos = arrow_pos or 0.5
    local x = x0
    local y = y0
    local drew_arrow = false
    for t = segment_spacing,1+0.5*segment_spacing,segment_spacing do
        local new_x = bezier(x0, x1, x2, x3, t)
        local new_y = bezier(y0, y1, y2, y3, t)

        if(not drew_arrow and t >= 1-1.5*segment_spacing) then
            draw_line(x, y, new_x, new_y, thickness, alpha, end_spacing, arrow_size, arrow_pos)
            drew_arrow = true
        else
            draw_line(x, y, new_x, new_y, thickness, alpha, end_spacing)
        end
        x = new_x
        y = new_y
    end
end


function get_deck(deck_name)
    if(deck_name == "discarded") then
        return discarded
    elseif(deck_name == "hand") then
        return hand
    elseif(deck_name == "deck") then
        return deck
    end
end

function set_history(current_i_target)
    old_i = current_i
    reset_cast_except_action_sprites()

    if(current_i_target <= 1) then
        for i = 1, #action_sprites do
            pop_action(10)
        end
        return
    end

    e = cast_history[current_i_target-1]

    local deletion_start = 1
    if(current_action_stack ~= nil) then
        for i, a in ipairs(current_action_stack) do
            if(i <= #e.action_stack and a.action == e.action_stack[i].action) then
                deletion_start = i+1
            else
                break
            end
        end
    end

    for i = deletion_start, #action_sprites do
        pop_action(10)
    end

    for i=deletion_start, #e.action_stack do
        local card
        if(e.action_stack[i].action.permanently_attached) then
            local unique_ac_id = e.action_stack[i].action.unique_ac_id
            for j, ac_card in ipairs(always_cast_cards) do
                if(ac_card.unique_ac_id == unique_ac_id) then
                    card = ac_card.card
                    break
                end
            end
        else
            local index = e.action_stack[i].action.deck_index + 1
            if(index >= 1 and index <= #start_deck) then
                card = start_deck[index]
            end
        end
        if(card ~= nil) then
            local action_sprite = push_action(card)

            local parent_action_index = #e.action_stack-1
            action_sprite.x = card.x
            action_sprite.y = card.y
        end
    end

    step_history(current_i_target-1, true, true)
    current_action_stack = e.action_stack
end

function step_history(steps, no_instant_step, skip_actions)
    if(steps == nil) then steps = 1 end
    local start_i = current_i
    while current_i < start_i+steps do
        if(current_i > #cast_history or current_i <= 0) then break end
        local e = cast_history[current_i]
        current_action_stack = e.action_stack
        if(not skip_actions and e.type == "action") then
            local card
            if(e.action_stack[#e.action_stack].action.permanently_attached) then
                local unique_ac_id = e.action_stack[#e.action_stack].action.unique_ac_id
                for j, ac_card in ipairs(always_cast_cards) do
                    if(ac_card.unique_ac_id == unique_ac_id) then
                        card = ac_card.card
                        break
                    end
                end
            else
                local index = e.action_stack[#e.action_stack].action.deck_index + 1
                if(index >= 1 and index <= #start_deck) then
                    card = start_deck[index]
                end
            end
            if(card ~= nil) then
                card.dscale = card.dscale+0.5
                card.dy = card.dy-10.0

                local action_sprite = push_action(card)

                local parent_action_index = #e.action_stack-1
                action_sprite.x = card.x
                action_sprite.y = card.y
            end

            -- Speed up playback for divide by's
            local iteration = e.info.iteration or 0
            playback_wait = math.ceil(20*math.pow(2, -0.5*iteration))
            -- playback_wait = math.ceil(15*math.pow(2, -0.5*iteration))
            -- if(iteration >= 2) then
            --     playback_wait = 1
            -- end

            -- if(action.action.id == "RESET") then
            --     playing = false
            -- end

            current_action_stack = e.action_stack
        elseif(not skip_actions and e.type == "action_end") then
            pop_action(10)
        -- elseif(e.type == "draw") then
        --     local action_sprite = action_sprites[#e.action_stack]
        --     if(action_sprite ~= nil) then
        --         action_sprite.draw_step = 1
        --         action_sprite.draw_how_many = e.info.how_many
        --         action_sprite.line1 = "draw"
        --         action_sprite.line2 = action_sprite.draw_step.."/"..action_sprite.draw_how_many
        --         if(e.info.dont_draw_actions) then
        --             action_sprite.line1 = "can't draw"
        --             action_sprite.line2 = ""
        --         end
        --     end
        --     if(not no_instant_step) then steps = steps+1 end
        -- elseif(e.type == "draw_step") then
        --     local action_sprite = action_sprites[#e.action_stack]
        --     if(action_sprite ~= nil) then
        --         action_sprite.line1 = "draw"
        --         action_sprite.line2 = action_sprite.draw_step.."/"..action_sprite.draw_how_many
        --         action_sprite.draw_step = action_sprite.draw_step+1
        --     end
        --     if(not no_instant_step) then steps = steps+1 end
        elseif(e.type == "card_move") then
            local source = get_deck(e.info.source)
            local dest = get_deck(e.info.dest)
            local item = source[e.info.index]
            table.remove(source, e.info.index)
            table.insert(dest, item)
            playback_wait = 10
        elseif(e.type == "add_ac_card") then
            local dest = get_deck(e.info.dest)
            local action = always_casts[e.info.ac_index]
            local card = make_debug_card(action)
            card.sprite = add_sprite(card)
            table.insert(card_sprites, card.sprite)
            table.insert(dest, card)
            table.insert(always_cast_cards, {unique_ac_id=e.info.unique_ac_id, card=card})
            playback_wait = 10
        elseif(e.type == "delete_ac_card") then
            local source = get_deck(e.info.source)
            local sprite = source[e.info.index].sprite
            table.remove(source, e.info.index)
            for i, s in ipairs(card_sprites) do
                if(s == sprite) then
                    table.remove(card_sprites, i)
                    break
                end
            end
            for i, ac_card in ipairs(always_cast_cards) do
                if(ac_card.unique_ac_id == e.info.unique_ac_id) then
                    table.remove(always_cast_cards, i)
                    break
                end
            end
            EntityKill(sprite)
            playback_wait = 10
        elseif(e.type == "order_deck") then
            -- table.sort(deck, function(a,b) return e.info.order[a.deck_index] < e.info.order[b.deck_index] end)
            table.sort(deck, function(a,b) return a.action.deck_index < b.action.deck_index end)
        -- elseif(e.type == "cast_done") then
        --     -- table.sort(deck, function(a,b) return e.info.order[a.deck_index] < e.info.order[b.deck_index] end)
        --     playing = false
        else
            if(not no_instant_step) then steps = steps+1 end
        end
        current_i = current_i + 1
    end
end

function reset_cast()
    clear_action_sprites()
    reset_cast_except_action_sprites()
end

function reset_cast_except_action_sprites()
    current_i = 1

    discarded = {}
    hand = {}
    deck = {}

    for i, card in ipairs(start_deck) do
        table.insert(deck, card)
    end
end

function OnWorldPostUpdate()
    player = EntityGetWithTag( "player_unit" )[1];
    local held_wand
    if(player ~= nil) then
        local inventory = EntityGetFirstComponent(player, "Inventory2Component")
        local active_item = ComponentGetValue2( inventory, "mActiveItem" )

        if(active_item ~= nil) and EntityHasTag(active_item, "wand") then
            held_wand = active_item
        end

        -- local children = EntityGetAllChildren(player)
        -- card_sprites = {}
        -- for i, c in ipairs(children) do
        --     if(EntityHasTag(c, "dbg_card")) then
        --         local index =
        --         table.insert(card_sprites, c, index)
        --     end
        -- end
    end

    GuiStartFrame(gui)
    gui_id = 0

    local mx, my = DEBUG_GetMouseWorld()

    local cx, cy, cw, ch = GameGetCameraBounds()
    cx, cy = GameGetCameraPos()
    cw = cw - 4
    -- ch = ch - 2
    local cx = cx-cw/2
    local cy = cy-ch/2

    local gw, gh = GuiGetScreenDimensions(gui)

    mx = (mx-cx)*gw/cw+0.5
    my = (my-cy)*gh/ch+0.5

    local dot_sprite = base_dir .. "files/ui_gfx/line_dot.png"
    GuiImage(gui, next_id(), mx, my, dot_sprite,
             1.0, 1, 0, 0)

    local wand_changed = false

    local open_pressed = GuiImageButton(gui, next_id(), gw-16, gh-16, "", base_dir.."files/ui_gfx/icon.png")
    local open_tooltip = "Show Wand DBG"
    if(show_wand_dbg) then
        open_tooltip = "Hide Wand DBG"
    end
    GuiTooltip(gui, open_tooltip, "")
    if(open_pressed) then
        show_wand_dbg = not show_wand_dbg
        wand_changed = true
    end
    if(not show_wand_dbg) then
        clear_card_sprites()
        reset_cast()
        return
    end

    local open_tree_pressed = GuiImageButton(gui, next_id(), gw-16-32, gh-16, "", base_dir.."files/ui_gfx/icon.png")
    local open_tree_tooltip = "Show Flowchart"
    if(show_tree) then
        open_tree_tooltip = "Hide Flowchart"
    end
    GuiTooltip(gui, open_tree_tooltip, "")
    if(open_tree_pressed) then
        show_tree = not show_tree
    end

    local wand_deck = {}
    local n_always_casts = 0
    if(player ~= nil and held_wand ~= nil) then
        local spells = EntityGetAllChildren(held_wand) or {}
        local ability_component = EntityGetFirstComponentIncludingDisabled(held_wand, "AbilityComponent")
        local deck_capacity = ComponentObjectGetValue(ability_component, "gun_config", "deck_capacity")
        local deck_capacity2 = EntityGetWandCapacity(held_wand)
        n_always_casts = deck_capacity - deck_capacity2

        for i,s in ipairs(spells) do
            local comp = EntityGetFirstComponentIncludingDisabled(s, "ItemActionComponent")
            if ( comp ~= nil ) then
                local action_id = ComponentGetValue2( comp, "action_id" )
                table.insert(wand_deck, action_id)
            end
        end
        if(last_wand_deck == nil or #wand_deck ~= #last_wand_deck) then
            wand_changed = true
        else
            for i,a in ipairs(wand_deck) do
                if(a ~= last_wand_deck[i]) then
                    wand_changed = true
                    break
                end
            end
        end
        last_wand_deck = wand_deck
        if(wand_changed) then
            GamePrint("wand changed")
            local ability = EntityGetFirstComponentIncludingDisabled(held_wand, "AbilityComponent")
            local wand_stats = {gun_config = {}, gunactions_config = {}, n_always_casts = n_always_casts}
            ConfigGun_Init(wand_stats.gun_config)
            wand_stats.actions_per_round = ComponentObjectGetValue2(ability, "gun_config", "actions_per_round")
            wand_stats.reload_time = ComponentObjectGetValue2(ability, "gun_config", "reload_time")
            wand_stats.deck_capacity = ComponentObjectGetValue2(ability, "gun_config", "deck_capacity")
            wand_stats.shuffle_deck_when_empty = ComponentObjectGetValue2(ability, "gun_config", "shuffle_deck_when_empty")

            -- local gunaction_config_members = ComponentObjectGetMembers(ability, "gun_config")
            -- for i, m in ipairs(gunaction_config_members) do
            --     wand_stats.gun_config[member] = ComponentObjectGetValue2(ability, "gun_config", member)
            -- end

            -- local gunaction_config_members = ComponentObjectGetMembers(ability, "gunaction_config")
            -- for i, m in ipairs(gunaction_config_members) do
            --     wand_stats.gunaction_config[member] = ComponentObjectGetValue2(ability, "gunaction_config", member)
            -- end

            local start_deck_actions
            cast_history, base_actions, action_trees, start_deck_actions, always_casts = debug_wand(wand_deck, wand_stats)
            always_cast_cards = {}
            start_deck = {}
            if(cast_history ~= nil) then GamePrint("#cast_history = " .. #cast_history) end
            for i, action in ipairs(start_deck_actions) do
                table.insert(start_deck, make_debug_card(action))
            end

            reset_cast()
        end
        if(cast_history ~= nil and base_actions ~= nil and start_deck ~= nil) then
            if(wand_changed or card_sprites == nil or #card_sprites ~= #start_deck) then
                clear_card_sprites()
                card_sprites = {}
                for i, card in ipairs(start_deck) do
                    card.sprite = add_sprite(card)
                    table.insert(card_sprites, card.sprite)
                end
            end

            local current_i_target = draw_playback(10, gh*0.9, gw-20, mx, my)
            local current_i_target_set = false
            if(current_i_target == nil) then
                current_i_target = current_i
            else
                current_i_target_set = true
            end

            if(current_i_target ~= current_i) then
                set_history(current_i_target)
            end
            if(current_i > #cast_history) then
                reset_cast()
            end

            if(cast_history ~= nil) then
                if(current_i > #cast_history or current_i < 1) then current_i = 1 end
                -- discarded = cast_history[current_i].discarded
                -- hand = cast_history[current_i].hand
                -- deck = cast_history[current_i].deck

                local base_x = 32
                local base_y = gh*0.8

                GuiText(gui, base_x, base_y-40,'discarded:')
                draw_deck(base_x, base_y, cx, cy, cw/gw, discarded)
                base_x = base_x+16*13
                -- base_y = base_y+32

                GuiText(gui, base_x, base_y-40,'hand:')
                draw_deck(base_x, base_y, cx, cy, cw/gw, hand)
                base_x = base_x+16*13
                -- base_y = base_y+32

                GuiText(gui, base_x, base_y-40,'deck:')
                draw_deck(base_x, base_y, cx, cy, cw/gw, deck, false)
            end

            if(current_action_stack ~= nil and #current_action_stack > 0) then
                for i, a in ipairs(action_sprites) do
                    -- local a = action_sprites[i]
                    a.x_target = 10+32*i
                    a.y_target = gh*0.6

                    local action = current_action_stack[i]
                    if(action.draw_how_many == nil) then
                        a.line1 = ""
                        a.line2 = ""
                    elseif(action.draw_how_many == -1) then
                        a.line1 = "can't draw"
                        a.line2 = ""
                    elseif(action.draw_how_many >= 1) then
                        a.line1 = "draw"
                        a.line2 = action.draw_step.."/"..action.draw_how_many
                        if(action.draw_step == 0) then
                            a.line2 = "1/"..action.draw_how_many
                        end
                    end

                    animate_card(a, a.sprite, cx, cy, cw/gw)
                end
            end

            for i=#dying_action_sprites,1,-1 do
                local alive = animate_dying_card(dying_action_sprites[i], dying_action_sprites[i].sprite, cx, cy, cw/gw)
                if(not alive) then
                    table.remove(dying_action_sprites, i)
                end
            end

            if(not looping and current_i == #cast_history) then
                playing = false
            end
            if(playing) then
                playback_timer = playback_timer-1
            else
                playback_timer = 1
            end
            if(playback_timer <= 0) then
                step_history(1)
                playback_timer = playback_wait
            end

            if(show_tree) then
                draw_tree()
            end

            -- for i, e in ipairs(cast_history) do
            --    if(e.type == "action" and e.base_action) then

            --    elseif(e.type == "card_move") then

            --    end
            -- end
        end
    end
end
