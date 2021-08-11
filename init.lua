base_dir = "mods/wand_dbg/"
mod_name = "wand_dbg"
dofile_once("data/scripts/lib/utilities.lua");
dofile_once(base_dir .. "files/debugger.lua");
dofile_once(base_dir .. "files/spell_info.lua");
dofile_once(base_dir .. "files/utils.lua");
dofile_once(base_dir .. "files/ui.lua");

local gui = GuiCreate()

action_table, projectile_table, extra_entity_table = SPELL_INFO.get_spell_info()
debug_wand = init_debugger()
-- actions_list, projectile_table, extra_entity_table = {}, {}, {}
dofile_once(base_dir .. "files/cast_state_properties.lua");

local show_wand_dbg = ModSettingGet(mod_name..".show")
local show_animation = ModSettingGet(mod_name..".show_animation")
local need_to_remake_cards = false

--                                                     id    x    y    w    h   show           title
local config_window     = make_window(    "config_window", 390, 150, 230, 180, false, "Wand Options")
local tree_window       = make_window(      "tree_window",  10,  54, 300, 170, false,    "Flowchart")
local cast_state_window = make_window("cast_state_window", 320,  54, 300, 170, false,  "Cast States")

local cast_states = {}
local cast_state_collapsed = {}

local current_i = 0
local current_i_target = nil
local playing = true
local playback_timer = 20
local looping = true

local current_c = nil

local last_wand_deck
local last_wand_stats
local wand_changed = false
local cast_history, action_trees, start_deck, always_casts, always_cast_cards

local options = {
    {id="maximize_uses", name="Spell Uses", type="boolean", value=false, true_text="Max", false_text="0"},
    {id="unlimited_spells", name="Unlimited Spells", type="boolean", value=false},
    {id="mana", name="Mana", type="number", value=0, min=0, max=100},
    {id="every_other_state", name="Every Other State", type="boolean", value=false, true_text="Skip", false_text="Don't skip"},
    {id="n_enemies", name="Nearby enemies", type="number", value=0, min=0, max=100, integer=true},
    {id="n_projectiles", name="Nearby Projectiles", type="number", value=0, min=0, max=100, integer=true},
    {id="n_omega_black_holes", name="Nearby Omega Black Holes", type="number", value=0, min=0, max=100, integer=true},
    {id="money", name="Gold", type="number", value=0, min=0, max=2147483648, inf_value=2147483648, log_scale=true},
    {id="hp", name="HP", type="number", type = "number", value=4, min=0, max=400000000000, display_multiplier=25, log_scale=true},
    {id="max_hp", name="Max HP", type="number", type="number", value=4, min=0, max=400000000000, display_multiplier=25, log_scale=true},
    {id="n_stainless", name="Number of Stainless", type="number", value=0, min=0, max=100, integer=true},
    {id="ambrosia", name="Ambrosia Stain", type="boolean", value=false},
    -- {id="damage_multipliers", name="Damage Multipliers", type="custom", value={ curse       = 1,
    --                                                                             drill       = 1,
    --                                                                             electricity = 1,
    --                                                                             explosion   = 0.35,
    --                                                                             fire        = 1,
    --                                                                             healing     = 1,
    --                                                                             ice         = 1,
    --                                                                             melee       = 1,
    --                                                                             overeating  = 1,
    --                                                                             physics_hit = 1,
    --                                                                             poison      = 1,
    --                                                                             projectile  = 1,
    --                                                                             radioactive = 1,
    --                                                                             slice       = 1 }},
    -- {id="zeta_options", name="Zeta Options", type="custom", value = {}},
    {id="frame_number", name="Frame Number", type="text_number", value = 0, integer=true},
}

local config = {}

for i, option in ipairs(options) do
    option.default = option.value
    option.override = ModSettingGet(mod_name.."."..option.id.."_override") or nil
    option.value    = ModSettingGet(mod_name.."."..option.id.."_value") or option.value
    option.value = option.value or false
    config[option.id] = option.override and option.value
end

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

local action_sprites = {}
local dying_action_sprites = {}

function make_debug_card(action)
    card = {action = action, x = 0, y = 0, theta = 0, scale = 1.0, dx = 0, dy = 0, dtheta = 0, dscale = 0.0, x_target = 0, y_target = 0}
    action.debug_card = card
    return card
end

function clear_card_sprites(always_casts_only)
    local children = EntityGetAllChildren(player)
    if children ~= nil then
        for i, c in ipairs(children) do
            if(not always_casts_only) then
                if(EntityHasTag(c, "dbg_card")) then
                    EntityKill(c)
                end
            else
                if(EntityHasTag(c, "ac_dbg_card")) then
                    EntityKill(c)
                end
            end
        end
    end
end

function add_sprite(card, is_always_cast)
    local bg_sprite = get_bg_sprite(card.action.type)
    local card_sprite = EntityCreateNew("debug_card")
    EntityAddChild(player, card_sprite)
    if(is_always_cast) then
        EntityAddTag(card_sprite, "ac_dbg_card")
    end
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
    dying_action_sprites = {}
end

function add_action_sprite(action)
    local bg_sprite = get_bg_sprite(action.type)
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
                         image_file = action_table[action.id].sprite,
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

function push_action(node)
    local action = node.action
    local new_action_sprite = {node = node, sprite=add_action_sprite(action), x = (action.debug_card and action.debug_card.x) or 0, y = (action.debug_card and action.debug_card.y) or 0, theta = 0, scale = 1.0, dx = 0, dy = 0, dtheta = 0, dscale = 0.0, x_target = 0, y_target = 0, line1 = "", line2 = ""}
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

function draw_deck(base_x, base_y, cx, cy, gui_to_world_scale, deck, focus)
    -- if(focus_on_end == nil) then focus_on_end = true end
    focus = focus or "middle"
    for i, card in ipairs(deck) do
        -- local sprite = card.action.sprite
        -- local bg_sprite = get_bg_sprite(card.action.type)

        -- local im_w, im_h = GuiGetImageDimensions(gui, bg_sprite, scale)

        -- local x_rel = 16*i
        -- local y_rel = 0

        -- GuiImage(gui, get_id(), base_x+x_rel-im_w/2, base_y+y_rel-im_h/2, bg_sprite,
        --          1.0, scale, 0, 0)

        -- im_w, im_h = GuiGetImageDimensions(gui, sprite, scale)
        -- GuiImage(gui, get_id(), base_x+x_rel-im_w/2, base_y+y_rel-im_h/2, sprite,
        --          1.0, scale, 0, 0)

        local spacing = 24
        local max_spacings = 6
        if(#deck > max_spacings) then
            local a2 = math.min((#deck-1)/max_spacings-1, 1)
            local a1 = 1-a2
            if(focus=="right") then
                local z = (i-1)/(#deck-1)
                card.x_target = base_x + spacing*max_spacings*(a1*z+a2*z*z)
            elseif(focus=="left") then
                local z = (#deck-i)/(#deck-1)
                card.x_target = base_x + spacing*max_spacings*(1-a1*z-a2*z*z)
            elseif(focus=="middle") then
                card.x_target = base_x + spacing*max_spacings*(i-1)/(#deck-1)
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
    local prev_pressed = GuiImageButton(gui, get_id("playback_previous"), x, base_y-3.5, "", base_dir.."files/ui_gfx/prev.png")
    GuiTooltip(gui, "previous", "")
    x = x+button_spacing+button_width
    local play_pause_pressed = GuiImageButton(gui, get_id("playback_play"), x, base_y-3.5, "", play_pause)
    GuiTooltip(gui, play_pause_text, "")
    x = x+button_spacing+button_width
    local next_pressed = GuiImageButton(gui, get_id("playback_next"), x, base_y-3.5, "", base_dir.."files/ui_gfx/next.png")
    GuiTooltip(gui, "next", "")
    x = x+button_spacing+button_width
    if(not looping) then GuiColorSetForNextWidget( gui, 0.5, 0.5, 0.5, 0.5) end
    local loop_pressed = GuiImageButton(gui, get_id("playback_loop"), x, base_y-3.5, "", base_dir.."files/ui_gfx/loop.png")
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
    draw_line(gui, base_x, base_y,
              base_x+bar_width, base_y,
              2*button_width, "white", 0.0, 0)

    draw_line(gui, base_x, base_y,
              base_x+bar_width, base_y,
              1.0, "white", 1.0, 0)
    GuiImage(gui, get_id("playback_indicator"), base_x+bar_width*(current_i-1)/#cast_history-3.5, base_y-3.5, base_dir.."files/ui_gfx/big_dot.png",
             1, 1)
    if(ui_hover) then
        local clicked = GuiImageButton(gui, get_id("playback_click_blocker"), base_x+bar_width*mouse_t/#cast_history-50.5, base_y-50.5, "", base_dir.."files/ui_gfx/invisible_button.png")
        GuiText(gui, base_x+bar_width*mouse_t/#cast_history, base_y, math.ceil(mouse_t).."/"..#cast_history)
        GuiImage(gui, get_id("playback_hover_indicator"), base_x+bar_width*mouse_t/#cast_history-3.5, base_y-3.5, base_dir.."files/ui_gfx/big_dot.png", 0.5, 1)
       if(clicked) then
           current_i_target = math.ceil(mouse_t)
       end
    end
    if #cast_history < bar_width then
        for i, e in ipairs(cast_history) do
            if(e.type == "action") then
                GuiImage(gui, get_id(), base_x+bar_width*i/#cast_history-1.5, base_y-1.5, base_dir.."files/ui_gfx/small_dot.png",
                         1, 1)
            end
        end
    end

    return current_i_target
end

function process_node(tree)
    local name = tree.action and tree.action.id or "shot_"..tree.cast_number
    tree.str = "(" .. name
    local previous_child_string = nil
    for i, c in ipairs(tree.children) do
        if(c.str == nil) then
            process_node(c)
        end
        if(i ~= 0) then
            tree.str = tree.str .. " "
        end
        tree.str = tree.str .. c.str
        c.identical_to_previous = (c.str == previous_child_string)
        previous_child_string = c.str
    end
    tree.str = tree.str..")"
end

function draw_ellipses(number_identical, width, x_spacing, y_spacing, scale, x, y, parent_x, parent_y)
    -- if(parent_x ~= nil and parent_y ~= nil) then
    --     local x_start = parent_x+8*scale
    --     local y_start = parent_y
    --     local x_end = x-8*scale
    --     local y_end = y
    --     draw_spline(gui, x_start, y_start, x_start+0.5*x_spacing, y_start,
    --                 x_end-0.5*x_spacing, y_end, x_end, y_end,
    --                 0.5, "white", 1.0, 0, 4, 1)
    -- end

    x = x-8*scale
    y = y-10*scale
    draw_spline(gui, x, y, x, y+4,
                x+0.5*width, y, x+0.5*width, y+4,
                0.5, "white", 1.0, 0)
    draw_spline(gui, x+width, y, x+width, y+4,
                x+0.5*width, y, x+0.5*width, y+4,
                0.5, "white", 1.0, 0)
    GuiOptionsAddForNextWidget(gui, GUI_OPTION.Align_HorizontalCenter)
    GuiText(gui, x+0.5*width, y+2.5,"x" .. number_identical)
    height = 11
    return width, height
end

function draw_node(tree, x_spacing, y_spacing, scale, x, y, parent_x, parent_y)
    local spline_offset = 0
    if(tree.action ~= nil) then
        local sprite = tree.action.sprite
        local bg_sprite = get_bg_sprite(tree.action.type)
        local im_w, im_h = GuiGetImageDimensions(gui, bg_sprite, scale)
        GuiImage(gui, get_id("node_background"..tostring(tree)), x-im_w/2, y-im_h/2, bg_sprite,
                                                      1.0, scale, 0, 0)
        local clicked, right_clicked, hovered, text_x, text_y, width, height = get_previous_widget_info(gui)

        local foreground_scale = scale
        if(hovered) then
            foreground_scale = 1.5*foreground_scale
        end
        im_w, im_h = GuiGetImageDimensions(gui, sprite, foreground_scale)
        GuiImage(gui, get_id("node_foreground"..tostring(tree)), x-im_w/2, y-im_h/2, sprite,
                 1.0, foreground_scale, 0, 0)
        if(clicked) then
            current_i_target = tree.event_index
        end

        if(tree.recursion_limited) then
            local cross_half = 0.6*y_spacing
            draw_line(gui, x-cross_half, y-cross_half, x+cross_half, y+cross_half, 1.0, "red", 0.8)
            draw_line(gui, x-cross_half, y+cross_half, x+cross_half, y-cross_half, 1.0, "red", 0.8)
        end
    else
        -- GuiOptionsAddForNextWidget(gui, GUI_OPTION.Align_Left)
        GuiOptionsAddForNextWidget(gui, GUI_OPTION.Align_HorizontalCenter)
        GuiText(gui, x, y-5, tree.cast_number)
        local clicked, right_clicked, hovered, text_x, text_y, width, height = get_previous_widget_info(gui)
        spline_offset = width/2-3
    end

    if(parent_x ~= nil and parent_y ~= nil) then
        local x_start = parent_x+8*scale
        local y_start = parent_y
        local x_end = x-8*scale
        local y_end = y

        local color
        if(tree.explanation == "draw") then
            color = "white"
        elseif(tree.explanation == "always_cast") then
            color = "light_blue"
        else
            color = "gold"
        end
        draw_spline(gui, x_start, y_start, x_start+0.5*x_spacing, y_start,
                    x_end-0.5*x_spacing, y_end, x_end, y_end,
                    0.5, color, 1.0, 0, 4, 1)
    end

    local width = x_spacing
    local height = 0
    local max_child_width = 0
    local previous_width = 0
    local number_identical = 1
    for i, c in ipairs(tree.children) do
        local child_x = x+x_spacing
        local child_y = y+height
        if(c.identical_to_previous) then
            number_identical = number_identical + 1
        else
            if(number_identical > 1) then
                local ellipses_width, ellipses_height = draw_ellipses(number_identical, previous_width, x_spacing, y_spacing, scale, child_x, child_y, x, y)
                height = height + ellipses_height
                child_y = y+height
            end
            number_identical = 1
            local child_width, child_height = draw_node(c, x_spacing, y_spacing, scale, child_x, child_y, x+spline_offset, y)
            if(child_width > max_child_width) then
                max_child_width = child_width
            end
            previous_width = child_width
            height = height+child_height
        end
    end

    if(number_identical > 1) then
        local child_x = x+x_spacing
        local child_y = y+height
        local ellipses_width, ellipses_height = draw_ellipses(number_identical, previous_width, x_spacing, y_spacing, scale, child_x, child_y, x, y)
        height = height + ellipses_height
    end

    if(tree.draw_how_many ~= nil and tree.dont_draw_actions
       or (tree.draw_how_many == 1 and tree.playing_permanent_card)) then
        local x_start = x+8*scale
        local y_start = y
        local x_text = x+x_spacing
        if(#tree.children == 0) then
            x_text = x+0.7*x_spacing
        end
        local x_end = x_text-4*scale
        local y_end = y+height
        height = height+y_spacing
        draw_spline(gui, x_start, y_start, x_start+0.5*x_spacing, y_start,
                    x_end-0.5*x_spacing, y_end, x_end, y_end,
                    0.5, "red", 1.0, 0, 4, 1)
        local text = tree.draw_how_many
        local text_width, text_height = GuiGetTextDimensions(gui, text, 1, 0)
        GuiColorSetForNextWidget(gui,1.0,0,0,1)
        GuiOptionsAddForNextWidget(gui, GUI_OPTION.Align_HorizontalCenter)
        GuiText(gui, x_text+0.5, y_end-0.5*text_height+0.5, text)
        local cross_half = 0.3*y_spacing
        draw_line(gui, x_text-cross_half+0.5, y_end-cross_half+0.5, x_text+cross_half, y_end+cross_half, 1.0, "red", 0.8)
        draw_line(gui, x_text-cross_half+0.5, y_end+cross_half-0.5, x_text+cross_half, y_end-cross_half, 1.0, "red", 0.8)
        max_child_width = math.max(max_child_width, x_text-x_start+cross_half)
    end

    width = width+max_child_width
    if(#tree.children == 0) then
        width = 8+max_child_width
        height = y_spacing
    end
    return width, height
end

function draw_trees(base_x, base_y, min_height)
    base_x = base_x or 0
    base_y = base_y or 0

    local x_spacing = 20
    local y_spacing = 10

    local scale = 0.5

    local x = base_x+8
    local y = base_y+8

    for i, t in ipairs(action_trees) do
        local width, height = draw_node(t, x_spacing, y_spacing, scale, x, y)
        y = y + height
        extend_max_bound(width+8+0.5*x_spacing, y-base_y)
    end

    --invisible dot for bottom margin
    local dot_sprite = base_dir .. "files/ui_gfx/line_dot_white.png"
    GuiImage(gui, get_id(), x, y, dot_sprite, 0.0, 1, 0, 0)

    return y-base_y
end

function draw_text_image_list(value, x, y)
    local width = 0
    if(type(value) == "string") then
        width = GuiGetTextDimensions(gui, value)
        GuiText(gui, x, y, value)
    elseif(type(value) == "table") then
        for i,t in ipairs(value) do
            local item_width = 0
            local item_height = 0
            if(type(t) == "string") then
                item_width = GuiGetTextDimensions(gui, t)
                GuiText(gui, x, y, t)
            else
                item_width, item_height = GuiGetImageDimensions(gui, t[1], 0.5)
                GuiImage(gui, get_id, x, y+1, t[1], 1, 0.5)
                GuiTooltip(gui, t[2], "")
                item_width = item_width+1
            end
            width = width+item_width
            x = x+item_width
        end
        width = width-4
    end
    return width
end

function draw_cast_state(state, x, y)
    local base_x = x
    local base_y = y
    local width = 0
    local height = 0

    if(state.current.projectiles ~= nil and #state.current.projectiles > 0)  then
        width = draw_text_image_list(format_projectiles(state.current.projectiles), x+6, y)+10
    else
        text = cast_state_collapsed[state.c] and "no proj." or "no projectiles"
        width = draw_text_image_list(text, x+6, y)+10
    end
    y = y+8
    height = height+8
    if(not cast_state_collapsed[state.c]) then
        for i, p in ipairs(cast_state_properties) do
            local raw_value = p.get(state.current)
            if(raw_value ~= nil and (type(raw_value) ~= "table" or #raw_value > 0) and raw_value ~= p.default) then
                local value
                if(p.format ~= nil) then
                    value = p.format(raw_value)
                else
                    value = to_string(raw_value)
                end
                local text = p.name..": "
                local name_width = GuiGetTextDimensions(gui, text)
                GuiText(gui, x+4, y, text)
                local value_width = draw_text_image_list(value, x+4+name_width, y)
                width = math.max(width, name_width+value_width+8)
                y = y+8
                height = height+8
            end
        end
    -- else
    --     width = 10
    --     height = 8
    end
    height = height+4
    -- draw_box(gui, x, base_y, width, height, 1, 1)
    --invisible image to get offsets
    GuiImage(gui, get_id("cast_state_offset_"..tostring(state)), 0, 0, base_dir .. "files/ui_gfx/line_dot_white.png", 0.0)
    local clicked, right_clicked, hovered, x0, y0, widget_width, widget_height = get_previous_widget_info(gui)

    GuiOptionsAddForNextWidget(gui, GUI_OPTION.ForceFocusable)
    z_set_next_relative(gui, 1.0)

    local nine_piece = base_dir.."files/ui_gfx/9piece_outline.png"
    local highlight_nine_piece = base_dir.."files/ui_gfx/9piece_outline_highlight.png"
    if(other_window_blocking or not inner_window_hovered) then
        highlight_nine_piece = nine_piece
    end
    GuiImageNinePiece(gui, get_id("cast_state_collapse_button_"..tostring(state)), x0+x, y0+base_y, width, height, 1,
                      nine_piece, highlight_nine_piece)
    local clicked, right_clicked, hovered, widget_x, widget_y, widget_width, widget_height = get_previous_widget_info(gui)
    if(hovered) then
        -- GuiOptionsAddForNextWidget(gui, GUI_OPTION.Layout_NoLayouting)
        -- GuiImage(gui, get_id(), mx, my, base_dir .. "files/ui_gfx/line_dot_white.png", 1, 10, 10)
        GuiOptionsAddForNextWidget(gui, GUI_OPTION.Layout_NoLayouting)
        -- GuiText(gui, mx, my, "width = "..width..", height = "..height.."; widget_width = "..widget_width..", widget_height = "..widget_height)
        local tooltip_text = cast_state_collapsed[state.c] and "expand" or "collapse"
        GuiText(gui, mx, my, tooltip_text)
    end
    if(clicked) then
        cast_state_collapsed[state.c] = not cast_state_collapsed[state.c]
    end
    local image = base_dir.."files/ui_gfx/black_circle.png"
    local im_w, im_h = GuiGetImageDimensions(gui, image, 1)
    GuiImage(gui, get_id(), base_x-0.5*im_w, base_y-0.5*im_h, image, 1, 1)
    z_set_next_relative(gui, -0.5)
    if(state.c.shot_type == "root") then
        local cast_number = state.c.root_node.cast_number or "error"
        local im_w, im_h = GuiGetTextDimensions(gui, cast_number)
        GuiText(gui, base_x-0.5*im_w+0.5, base_y-0.5*im_h, cast_number)
    else
        local image = get_projectile_icon(state.c.parent_projectile)
        local im_w, im_h = GuiGetImageDimensions(gui, image, 0.5)
        GuiImage(gui, get_id(), base_x-0.5*im_w, base_y-0.5*im_h, image, 1, 0.5)
        z_set_next_relative(gui, -1.0)
        local image = base_dir.."files/ui_gfx/"..state.c.shot_type..".png"
        local im_w, im_h = GuiGetImageDimensions(gui, image, 0.5)
        GuiImage(gui, get_id(), base_x-0.5*im_w-3, base_y-0.5*im_h-3, image, 1, 0.5)
    end
    return width, height
end

function draw_cast_states(states, x, y, parent_x, parent_y)
    local width = 0
    local height = 0

    local x_spacing = 24

    local base_x = x
    local base_y = y

    for i, c in ipairs(states) do
        if(cast_states[c] == nil) then
            break
        end

        if(parent_x ~= nil) then
            local x_start = parent_x
            local y_start = math.min(parent_y, y)
            local x_end = x-4
            local y_end = y
            z_set_relative(gui, -1.5)
            draw_spline(gui, x_start, y_start, x_start+0.5*x_spacing, y_start,
                        x_end-0.5*x_spacing, y_end, x_end, y_end,
                        0.5, "white", 1.0, 0, 4, 1)
            z_set_relative(gui, 0)
        end

        local state_width, state_height = draw_cast_state(cast_states[c], x+4, y)
        state_width = state_width+8

        local child_x = x+state_width+x_spacing
        local child_y = y

        local children_width, children_height = draw_cast_states(cast_states[c].children, child_x, child_y,
                                                                 x+state_width, y+state_height)
        children_width = children_width+x_spacing+8
        state_height = math.max(state_height+8, children_height)
        y = y+state_height
        width = math.max(width, state_width+children_width)
        height = height+state_height
        extend_max_bound(4+width, y)
    end

    --invisible dot for bottom margin
    local dot_sprite = base_dir .. "files/ui_gfx/line_dot_white.png"
    GuiImage(gui, get_id(), x, y, dot_sprite, 0.0, 1, 0, 0)

    return width, height
end

function draw_config(x, y, window_x, window_y)
    for i, option in ipairs(options) do
        local option_changed = false

        local button_text = option.name..": "
        if(not option.override) then
            button_text = button_text.."Use game value"
        elseif(option.type == "boolean") then
            button_text = button_text..""..(option.value and (option.true_text or "Yes") or (option.false_text or "No"))
        elseif(option.type == "number") then
            if(option.inf_value and option.value >= option.inf_value) then
                button_text = button_text.."∞"
            else
                button_text = button_text..string.format("%.0f", option.value*(option.display_multiplier or 1))
            end
        end
        local clicked, right_clicked = GuiButton(gui, get_id("config_button_"..option.id), x, y, button_text)
        local _, __, hovered, button_x, button_y, button_width, button_height = get_previous_widget_info(gui)

        local option_width = button_width
        local option_height = button_height
        if(option.override) then
            if(option.type == "number") then
                local old_value = option.value
                GuiColorSetForNextWidget(gui,1,1,1,0)

                local slider_width = 200
                local slider_height = 12

                local slider_value   = option.log_scale and math.log(option.value+1)   or option.value
                local slider_min     = option.log_scale and math.log(option.min+1)     or option.min
                local slider_max     = option.log_scale and math.log(option.max*1.01+1)     or option.max
                local slider_default = option.log_scale and math.log(option.default+1) or option.default
                option.value = GuiSlider(gui, get_id("config_slider_"..option.id), x+12, y+button_height, "",
                                         slider_value, slider_min, slider_max, slider_default, option.display_multiplier or 1,
                                         " ", slider_width)
                get_previous_widget_info(gui)
                if(option.log_scale) then
                    option.value = math.exp(option.value)-1
                end
                if(option.integer) then
                    option.value = math.floor(option.value)
                end

                if(option.value ~= old_value) then
                    option_changed = true
                end

                option_width = math.max(option_width, slider_width)
                option_height = option_height+slider_height
            elseif(option.type == "text_number") then
                local old_value = option.value
                local textbox_id = get_id("config_text_number_box_"..option.id)
                if(gui_selected == textbox_id) then
                    -- GamePrint("text box "..textbox_id.." is selected")
                    textbox_id = ""
                end
                option.value = tonumber(GuiTextInput(gui, textbox_id, x+button_width, y,
                                                     string.format("%d", option.value), 60, 9, "0123456789")) or 0
                local clicked, right_clicked, hovered, textbox_x, textbox_y, textbox_width, textbox_height = get_previous_widget_info(gui)
                if(clicked) then
                    -- GamePrint("text box "..textbox_id.." is clicked")
                    gui_selected = textbox_id
                    new_gui_selected = textbox_id
                end

                if(option.integer) then
                    option.value = math.floor(option.value)
                end

                if(option.value ~= old_value) then
                    option_changed = true
                end

                option_width = option_width+textbox_width
                option_height = math.max(option_height, textbox_height)
            end
        end
        y = y+option_height
        extend_max_bound(option_width, y)

        if(clicked) then
            if(option.type=="boolean") then
                if(option.override) then
                    if(option.value) then
                        option.override = nil
                    else
                        option.value = true
                    end
                else
                    option.override = true
                    option.value = false
                end
            else
                option.override = not option.override
            end
            option_changed = true
        end

        if(option_changed) then
            wand_changed = true
            option.needs_saving = true
        end

        if(option.needs_saving and GameGetFrameNum()%60==0) then
            ModSettingSet(mod_name.."."..option.id.."_override", option.override==true)
            ModSettingSet(mod_name.."."..option.id.."_value", option.value)
            option.needs_saving = false
        end

        config[option.id] = option.override and option.value
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

function get_action_stack(node)
    local action_stack = {}
    while(node ~= nil and node.action ~= nil) do
        table.insert(action_stack, 1, node)
        node = node.parent
    end
    return action_stack
end

function set_history(current_i_target)
    if(current_i_target == current_i+1) then
        step_history()
        return
    end

    reset_cast_except_action_sprites()

    if(current_i_target <= 1) then
        for i = 1, #action_sprites do
            pop_action(10)
        end
        return
    end

    e = cast_history[current_i_target-1]

    local node = e.node
    local action_stack = get_action_stack(node)

    local deletion_start = 1
    --TODO: this is slightly incorrect if an action is poped, and pushed back between
    --      the current state and the new target one, but not a huge deal for now
    for i, a in ipairs(action_sprites) do
        if(i <= #action_stack and action_stack[i].action == a.node.action) then
            deletion_start = i+1 --this way it can reach beyond #action_sprites
        else
            break
        end
    end

    for i = deletion_start, #action_sprites do
        pop_action(10)
    end

    for i=deletion_start, #action_stack do
        local action_sprite = push_action(action_stack[i])
    end

    clear_card_sprites(true)
    step_history(current_i_target-current_i, true, true)
end

function step_history(steps, no_instant_step, skip_actions)
    if(steps == nil) then steps = 1 end
    local start_i = current_i
    while current_i < start_i+steps do
        if(current_i > #cast_history or current_i <= 0) then break end
        local e = cast_history[current_i]
        -- GamePrint("event: "..e.type)
        if(not skip_actions and e.type == "action") then
            local card = e.node.action.debug_card
            if(card ~= nil) then
                card.dscale = card.dscale+0.5
                card.dy = card.dy-10.0
            end

            local action_sprite = push_action(e.node)

            -- Speed up playback for divide by's
            local iteration = e.info.iteration or 0
            playback_wait = math.ceil(20*math.pow(2, -0.5*iteration))
            -- playback_wait = math.ceil(15*math.pow(2, -0.5*iteration))
            -- if(iteration >= 2) then
            --     playback_wait = 1
            -- end
        elseif(not skip_actions and e.type == "action_end") then
            pop_action(10)
            playback_wait = 10
        elseif(e.type == "new_cast_state") then
            if(cast_states[e.info.c_old_final] == nil) then
                cast_states[e.info.c_old_final] = {c = e.info.c_old_final, current = e.info.c_old, children = {}}
            else
                cast_states[e.info.c_old_final].current = e.info.c_old
            end
            table.insert(cast_states[e.info.c_old_final].children, e.c_final)
            if(not no_instant_step) then steps = steps+1 end
        elseif(e.type == "card_move") then
            local source = get_deck(e.info.source)
            local dest = get_deck(e.info.dest)
            local item = source[e.info.index]
            table.remove(source, e.info.index)
            table.insert(dest, item)
            playback_wait = 5
        elseif(e.type == "add_ac_card") then
            local dest = get_deck(e.info.dest)
            local action = e.node.action
            local card = make_debug_card(action)
            card.sprite = add_sprite(card, true)
            table.insert(dest, card)
            playback_wait = 5
        elseif(e.type == "delete_ac_card") then
            local source = get_deck(e.info.source)
            local sprite = source[e.info.index].sprite
            table.remove(source, e.info.index)
            --TODO: fade this out
            EntityKill(sprite)
            playback_wait = 5
        elseif(e.type == "order_deck") then
            local sorted_deck = {}
            for i, j in ipairs(e.info.order) do
                sorted_deck[i] = deck[j]
            end
            deck = sorted_deck
            playback_wait = 5
        -- elseif(e.type == "cast_done") then
        --     -- table.sort(deck, function(a,b) return e.info.order[a.deck_index] < e.info.order[b.deck_index] end)
        --     playing = false
        else
            if(not no_instant_step) then steps = steps+1 end
        end
        if(cast_states[e.c_final] == nil) then
            cast_states[e.c_final] = {c=e.c_final, children = {}}
        end
        cast_states[e.c_final].current = e.c
        current_i = current_i + 1
    end
end

function reset_cast()
    clear_action_sprites()
    clear_card_sprites(true)
    reset_cast_except_action_sprites()
end

function reset_cast_except_action_sprites()
    current_i = 1

    discarded = {}
    hand = {}
    deck = {}

    cast_states = {}

    if(start_deck ~= nil) then
        for i, card in ipairs(start_deck) do
            table.insert(deck, card)
        end
    end
end

function OnWorldPostUpdate()
    player = EntityGetWithTag( "player_unit" )[1];
    local held_wand
    local m1
    local px, py
    local player_hp = 4
    local player_max_hp = 4
    local player_damage_multipliers = { curse       = 1,
                                        drill       = 1,
                                        electricity = 1,
                                        explosion   = 0.35,
                                        fire        = 1,
                                        healing     = 1,
                                        ice         = 1,
                                        melee       = 1,
                                        overeating  = 1,
                                        physics_hit = 1,
                                        poison      = 1,
                                        projectile  = 1,
                                        radioactive = 1,
                                        slice       = 1 }
    local player_n_stainless = 0
    local player_has_ambrosia = 0
    local player_has_unlimited_spells = false
    if(player ~= nil) then
        local inventory = EntityGetFirstComponent(player, "Inventory2Component")
        local active_item = ComponentGetValue2( inventory, "mActiveItem" )

        if(active_item ~= nil) and EntityHasTag(active_item, "wand") then
            held_wand = active_item
        end

        px, py = EntityGetTransform(player)

        local comp = EntityGetFirstComponent(player, "DamageModelComponent")
        if(comp ~= nil) then
            player_hp = ComponentGetValue2(comp, "hp")
            player_max_hp = ComponentGetValue2(comp, "max_hp")
            local damage_multipliers_object = ComponentObjectGetMembers(comp, "damage_multipliers")
            for type, multiplier in pairs(damage_multipliers_object) do
                player_damage_multipliers[type] = tonumber(multiplier)
            end
        end

        local game_effects = EntityGetComponent(entity_id, "GameEffectComponent")
        if(game_effects ~= nil) then
            for i, e in ipairs(game_effects) do
                if(ComponentGetValue2(e, "effect") == "STAINLESS_ARMOR") then
                    player_n_stainless = player_n_stainless + 1
                end
            end
        end

        local world_entity_id = GameGetWorldStateEntity()
        if( world_entity_id ~= nil ) then
            local comp_worldstate = EntityGetFirstComponent( world_entity_id, "WorldStateComponent" )
            if( comp_worldstate ~= nil ) then
                player_has_unlimited_spells = ComponentGetValue2(comp_worldstate, "perk_infinite_spells")
            end
        end
        -- local controls_component = EntityGetFirstComponent(player, "ControlsComponent")
        -- m1 = ComponentGetValue2(controls_component, "mButtonDownLeftClick") or false
    end

    GuiStartFrame(gui)
    GuiOptionsAdd(gui, GUI_OPTION.NoPositionTween);
    start_gui(gui)

    mx, my = DEBUG_GetMouseWorld()

    local cx, cy, cw, ch = GameGetCameraBounds()
    cx, cy = GameGetCameraPos()
    cw = cw - 4
    -- ch = ch - 2
    local cx = cx-cw/2
    local cy = cy-ch/2

    gw, gh = GuiGetScreenDimensions(gui)
    -- GamePrint("screen dimensions: ("..gw..", "..gh..")")
    -- GamePrint("camera dimensions: ("..cw..", "..ch..")")

    mx = (mx-cx)*gw/cw+1.0
    my = (my-cy)*gw/cw-1.5

    -- local dot_sprite = base_dir .. "files/ui_gfx/line_dot_white.png"
    -- GuiImage(gui, get_id(), mx, my, dot_sprite,
    --          1.0, 1, 0, 0)

    local open_pressed = GuiImageButton(gui, get_id("icon"), gw-16, gh-16, "", base_dir.."files/ui_gfx/icon.png")
    local open_tooltip = "Show Wand DBG"
    if(show_wand_dbg) then
        open_tooltip = "Hide Wand DBG"
    end
    GuiTooltip(gui, open_tooltip, "")
    if(open_pressed) then
        show_wand_dbg = not show_wand_dbg
        ModSettingSet(mod_name..".show", show_wand_dbg)
        wand_changed = true
    end
    if(not show_wand_dbg) then
        clear_card_sprites()
        reset_cast()
        return
    end

    local open_animation_pressed = GuiImageButton(gui, get_id("animation_show_hide_button"), gw-16-32, gh-16, "", base_dir.."files/ui_gfx/animation_icon.png")
    local open_animation_tooltip = "Show Deck Animation"
    if(show_animation) then
        open_animation_tooltip = "Hide Deck Animation"
    end
    GuiTooltip(gui, open_animation_tooltip, "")
    if(open_animation_pressed) then
        show_animation = not show_animation
        ModSettingSet(mod_name..".show_animation", show_animation)
    end

    -- local open_tree_pressed = GuiImageButton(gui, get_id("tree_icon"), gw-16-32, gh-16, "", base_dir.."files/ui_gfx/tree_icon.png")
    -- local open_tree_tooltip = "Show Flowchart"
    -- if(tree_window.show) then
    --     open_tree_tooltip = "Hide Flowchart"
    -- end
    -- GuiTooltip(gui, open_tree_tooltip, "")
    -- if(open_tree_pressed) then
    --     tree_window.show = not tree_window.show
    --     top_window = tree_window.index
    -- end

    do_window_show_hide_button(gui, tree_window, gw-16-64, gh-16, base_dir.."files/ui_gfx/tree_icon.png")
    do_window_show_hide_button(gui, cast_state_window, gw-16-48, gh-16, base_dir.."files/ui_gfx/cast_state_icon.png")
    do_window_show_hide_button(gui, config_window, gw-16-16, gh-16, base_dir.."files/ui_gfx/config_icon.png")

    local wand_deck = {}
    local n_always_casts = 0
    if(player == nil or held_wand == nil) then
        need_to_remake_cards = true
        reset_cast()
        clear_card_sprites()
    else
        local spells = EntityGetAllChildren(held_wand) or {}
        local ability_component = EntityGetFirstComponentIncludingDisabled(held_wand, "AbilityComponent")
        local deck_capacity = ComponentObjectGetValue(ability_component, "gun_config", "deck_capacity")
        local deck_capacity2 = EntityGetWandCapacity(held_wand)
        n_always_casts = deck_capacity - deck_capacity2

        local wand_stats = {gun_config = {}, gunaction_config = {}, n_always_casts = n_always_casts}

        wand_stats.mana_max = ComponentGetValue2(ability_component, "mana_max")
        for i,option in ipairs(options) do
            if(option.id == "mana") then
                option.max = wand_stats.mana_max
                option.default = wand_stats.mana_max
            elseif(option.id == "hp") then
                option.max = config.max_hp or player_max_hp
                option.value = math.min(option.value, option.max)
                break
            end
        end

        if(last_wand_stats == nil or wand_stats.mana_max ~= last_wand_stats.mana_max) then
            wand_changed = true
        end

        ConfigGun_Init(wand_stats.gun_config)
        local gun_config_members = ComponentObjectGetMembers(ability_component, "gun_config")
        -- GamePrint("gun_config:")
        for member, value in pairs(gun_config_members) do
            -- GamePrint(member.." = "..value)
            if(type(wand_stats.gun_config[member]) == "string") then
                wand_stats.gun_config[member] = value
            elseif(type(wand_stats.gun_config[member]) == "number") then
                wand_stats.gun_config[member] = tonumber(value)
            elseif(type(wand_stats.gun_config[member]) == "boolean") then
                wand_stats.gun_config[member] = (value=="1")
            end

            if(last_wand_stats == nil or wand_stats.gun_config[member] ~= last_wand_stats.gun_config[member]) then
                wand_changed = true
            end
        end

        ConfigGunActionInfo_Init(wand_stats.gunaction_config)
        local gunaction_config_members = ComponentObjectGetMembers(ability_component, "gunaction_config")
        for member, value in pairs(gunaction_config_members) do
            if(type(wand_stats.gunaction_config[member]) == "string") then
                wand_stats.gunaction_config[member] = value
            elseif(type(wand_stats.gunaction_config[member]) == "number") then
                wand_stats.gunaction_config[member] = tonumber(value)
            elseif(type(wand_stats.gunaction_config[member]) == "boolean") then
                wand_stats.gunaction_config[member] = (value=="1")
            end

            if(last_wand_stats == nil or wand_stats.gunaction_config[member] ~= last_wand_stats.gunaction_config[member]) then
                wand_changed = true
            end
        end

        for i,s in ipairs(spells) do
            local comp = EntityGetFirstComponentIncludingDisabled(s, "ItemActionComponent")
            local item_comp = EntityGetFirstComponentIncludingDisabled(s, "ItemComponent")
            if (comp ~= nil and item_comp ~= nil) then
                local action_id = ComponentGetValue2( comp, "action_id" )
                local is_always_cast = ComponentGetValue2(item_comp, "permanently_attached")
                local uses_remaining = ComponentGetValue2(item_comp, "uses_remaining")

                table.insert(wand_deck, {id = action_id, is_always_cast = is_always_cast, uses_remaining = uses_remaining})
            end
        end
        if(last_wand_deck == nil or #wand_deck ~= #last_wand_deck) then
            wand_changed = true
        else
            for i,a in ipairs(wand_deck) do
                local b = last_wand_deck[i]
                if(a.id ~= b.id or a.is_always_cast ~= b.is_always_cast or a.uses_remaining ~= b.uses_remaining) then
                    wand_changed = true
                    break
                end
            end
        end
        last_wand_deck = wand_deck
        last_wand_stats = wand_stats
        if(wand_changed) then
            need_to_remake_cards = true
            wand_changed = false
            -- GamePrint("wand changed")

            wand_stats.mana = config.mana or ComponentGetValue2(ability_component, "mana")
            wand_stats.maximize_uses = config.maximize_uses
            wand_stats.unlimited_spells = config.unlimited_spells==nil and player_has_unlimited_spells or config.unlimited_spells
            wand_stats.n_enemies = config.n_enemies or #(EntityGetInRadiusWithTag(px, py, 240, "homing_target"))
            wand_stats.n_projectiles = config.n_projectiles or #(EntityGetInRadiusWithTag(px, py, 160, "projectile"))
            wand_stats.n_omega_black_holes = config.n_omega_black_holes or #(EntityGetWithTag(px, py, 160, "black_hole_giga"))
            wand_stats.hp = config.hp or player_hp
            wand_stats.max_hp = config.max_hp or player_max_hp
            wand_stats.every_other_state = config.every_other_state
            wand_stats.money = config.money or 0
            wand_stats.damage_multipliers = config.damage_multipliers or player_damage_multipliers
            wand_stats.n_stainless = config.n_stainless or player_n_stainless
            wand_stats.ambrosia = config.ambrosia~=nil and config.ambrosia or player_has_ambrosia
            -- wand_stats.zeta_options = string.gmatch(config.zeta_options, "[^,]")
            wand_stats.zeta_options = nil
            wand_stats.frame_number = config.frame_number

            if(not wand_stats.zeta_options) then
                wand_stats.zeta_options = {}
                local children = EntityGetAllChildren( player)
                local inventory = EntityGetFirstComponent( player, "Inventory2Component" )

                if ( children ~= nil ) and ( inventory ~= nil ) then
                    local active_wand = ComponentGetValue2( inventory, "mActiveItem" )

                    for i,child_id in ipairs( children ) do
                        if ( EntityGetName( child_id ) == "inventory_quick" ) then
                            local wands = EntityGetAllChildren( child_id )

                            if ( wands ~= nil ) then
                                for k,wand_id in ipairs( wands ) do
                                    if ( wand_id ~= active_wand ) and EntityHasTag( wand_id, "wand" ) then
                                        local spells = EntityGetAllChildren( wand_id )

                                        if ( spells ~= nil ) then
                                            for j,spell_id in ipairs( spells ) do
                                                local comp = EntityGetFirstComponentIncludingDisabled( spell_id, "ItemActionComponent" )

                                                if ( comp ~= nil ) then
                                                    local action_id = ComponentGetValue2( comp, "action_id" )

                                                    table.insert( wand_stats.zeta_options, action_id )
                                                end
                                            end
                                        end
                                    end
                                end
                            end
                        end
                    end
                end
            end

            local start_deck_actions
            cast_history, action_trees, start_deck_actions, always_casts = debug_wand(wand_deck, wand_stats)
            for i, t in ipairs(action_trees) do
                process_node(t)
            end
            always_cast_cards = {}
            start_deck = {}
            cast_state_collapsed = {}
            -- if(cast_history ~= nil) then GamePrint("#cast_history = " .. #cast_history) end
            for i, action in ipairs(start_deck_actions) do
                table.insert(start_deck, make_debug_card(action))
            end

            reset_cast()
            current_i_target = nil
        end
        if(cast_history ~= nil and start_deck ~= nil) then
            if(show_animation) then
                if(need_to_remake_cards) then
                    current_i_target = current_i
                    reset_cast()
                    clear_card_sprites()
                    for i, card in ipairs(start_deck) do
                        card.sprite = add_sprite(card)
                    end
                end
            end

            if(show_animation or cast_state_window.show) then
                if(show_animation) then
                    current_i_target = draw_playback(10, gh*0.9+5, gw-20, mx, my)
                end
                if(current_i_target == nil) then
                    current_i_target = current_i
                end
                if(current_i_target ~= current_i) then
                    set_history(current_i_target)
                end
                if(current_i > #cast_history) then
                    reset_cast()
                end

                current_i_target = nil
            end

            if(show_animation) then
                if(cast_history ~= nil) then
                    if(current_i > #cast_history or current_i < 1) then current_i = 1 end
                    -- discarded = cast_history[current_i].discarded
                    -- hand = cast_history[current_i].hand
                    -- deck = cast_history[current_i].deck

                    local base_x = 32
                    local base_y = gh*0.9
                    local label_y = gh*0.78

                    GameCreateSpriteForXFrames(base_dir.."files/ui_gfx/discarded.png", cx+cw/gw*base_x, cy+cw/gw*label_y,
                                               false, 0, 0, 1, true)
                    -- GuiText(gui, base_x, base_y-40,'discarded:')
                    draw_deck(base_x, base_y, cx, cy, cw/gw, discarded, "right")
                    base_x = base_x+16*13

                    GameCreateSpriteForXFrames(base_dir.."files/ui_gfx/hand.png", cx+cw/gw*base_x, cy+cw/gw*label_y,
                                               false, 0, 0, 1, true)
                    -- GuiText(gui, base_x, base_y-40,'hand:')
                    draw_deck(base_x, base_y, cx, cy, cw/gw, hand, "middle")
                    base_x = base_x+16*13

                    GameCreateSpriteForXFrames(base_dir.."files/ui_gfx/deck.png", cx+cw/gw*base_x, cy+cw/gw*label_y,
                                               false, 0, 0, 1, true)
                    -- GuiText(gui, base_x, base_y-40,'deck:')
                    draw_deck(base_x, base_y, cx, cy, cw/gw, deck, "left")
                end

                if(action_sprites ~= nil) then
                    for i = #action_sprites,1,-1 do
                        a = action_sprites[i]
                        a.x_target = 10+32*i
                        a.y_target = gh*0.73

                        local node = a.node
                        if(node.draw_how_many == nil) then
                            a.line1 = ""
                            a.line2 = ""
                        elseif(node.dont_draw_actions == -1) then
                            a.line1 = "can't draw"
                            a.line2 = ""
                        elseif(node.playing_permanent_card and node.draw_how_many <= 1) then
                            a.line1 = "can't draw 1"
                            a.line2 = "in always cast"
                        elseif(node.draw_how_many >= 1) then
                            a.line1 = "draw"
                            if(a.line2 == "") then
                                a.line2 = "0/"..node.draw_how_many
                            end
                        end

                        if(node.draw_step ~= nil and i > 1) then
                            --technically draw_total and draw_how_many are slightly redundent,
                            --but could theoretically support wierd spells later on more easily
                            action_sprites[i-1].line2 = node.draw_step.."/"..node.draw_total
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

                need_to_remake_cards = false
            else
                if(not need_to_remake_cards) then
                    clear_card_sprites()
                    clear_action_sprites()
                    need_to_remake_cards = true
                end
            end

            tree_window.func = function(window)
                draw_trees(-window.x_scroll, 0)
            end

            cast_state_window.func = function(window)
                root_cast_states = {}
                for i, t in ipairs(action_trees) do
                    table.insert(root_cast_states, t.c)
                end
                draw_cast_states(root_cast_states, -window.x_scroll, 8)
            end

            config_window.func = function(window)
                draw_config(-window.x_scroll, 0, window.x, window.y)
            end

            draw_windows(gui)
        end
    end
end
