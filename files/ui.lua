mx = 0
my = 0
gx = 0
gy = 0

bound_x_min = 0
bound_y_min = 0
bound_x_max = 0
bound_y_max = 0

local drag_mx = 0
local drag_my = 0

local max_x
local max_y
window_active = false
other_window_blocking = false
inner_window_hovered = false

--Constant settings windows
local drag_bar_height = 9
local window_min_width = 10
local window_min_height = 10

gui_selected = nil
new_gui_selected = nil

local named_gui_id = 100000
gui_id = 0
local gui_ids = {}
function get_id(name, n_ids)
    n_ids = n_ids or 1
    if(name ~= nil) then
        if(gui_ids[name] ~= nil) then
            prev_gui_id = gui_ids[name]
            return gui_ids[name]
        end
        named_gui_id = named_gui_id+n_ids
        gui_ids[name] = named_gui_id
        prev_gui_id = named_gui_id
        return named_gui_id
    end
    gui_id = gui_id+1
    prev_gui_id = gui_id
    return gui_id
end

function start_gui(gui)
    -- GuiStartFrame(gui)
    -- GuiOptionsAdd(gui, GUI_OPTION.NoPositionTween);
    gui_id = 0
end

z_global = 0
function z_set_global(gui, z)
    z_global = z
    GuiZSet(gui, z)
end

function z_set_next_relative(gui, z)
    GuiZSetForNextWidget(gui, z_global+z)
end

function z_set_relative(gui, z)
    GuiZSetForNextWidget(gui, z_global+z)
end

interactive = true
global_interactive = true
function set_interactive(gui, new_interactive)
    interactive = new_interactive
    if(interactive and global_interactive) then
        GuiOptionsRemove(gui, GUI_OPTION.NonInteractive)
    else
        GuiOptionsAdd(gui, GUI_OPTION.NonInteractive)
    end
end

local last_widget_hidden = false
local last_widget_x = 0
local last_widget_y = 0
local last_widget_width = 0
local last_widget_height = 0

function get_previous_widget_info_bounded(gui)
    if(last_widget_hidden) then
        return false, false, false, last_widget_x, last_widget_y, last_widget_width, last_widget_height
    end
    local clicked, right_clicked, hovered, x, y, width, height = GuiGetPreviousWidgetInfo(gui)
    if(inner_window_hovered and not other_window_blocking and (clicked or right_clicked)) then
        window_active = true
    elseif(not inner_window_hovered or not interactive or other_window_blocking) then
        clicked = false
        right_clicked = false
        hovered = false
    end
    return clicked, right_clicked, hovered, x, y, width, height
end

function get_previous_widget_info(gui)
    local clicked, right_clicked, hovered, x, y, width, height = GuiGetPreviousWidgetInfo(gui)
    if(inner_window_hovered and not other_window_blocking and (clicked or right_clicked)) then
        window_active = true
    elseif(not inner_window_hovered or not interactive or other_window_blocking) then
        clicked = false
        right_clicked = false
        hovered = false
    end
    return clicked, right_clicked, hovered, x, y, width, height
end

function gui_image_bounded(gui, id, x, y, sprite_filename, alpha, scale, scale_y, rotation, rect_animation_playback_type, rect_animation_name)
    -- default values
    alpha = alpha or 1
    scale = scale or 1
    scale_y = scale_y or 0
    rotation = rotation or 0
    rect_animation_playback_type = rect_animation_playback_type or GUI_RECT_ANIMATION_PLAYBACK.PlayToEndAndHide
    rect_animation_name = rect_animation_name or ""

    local y_scale = scale_y == 0 and scale or scale_y

    bound_x_min = bound_x_min or 0
    bound_y_min = bound_y_min or 0
    bound_x_max = bound_x_max or gw
    bound_y_max = bound_y_max or gh

    local c = math.cos(rotation)
    local s = math.sin(rotation)
    local w, h = GuiGetImageDimensions(gui, sprite_filename)
    w = w*scale
    h = h*y_scale
    local x_min = x + math.min(w*c, 0) + math.min(-h*s, 0)
    local y_min = y + math.min(h*c, 0) + math.min(w*s, 0)
    local x_max = x + math.max(w*c, 0) + math.max(-h*s, 0)
    local y_max = y + math.max(h*c, 0) + math.max(w*s, 0)

    if(bound_x_min <= x_max and x_min <= bound_x_max
       and bound_y_min <= y_max and y_min <= bound_y_max) then
        GuiImage(gui, id, x, y, sprite_filename, alpha, scale, scale_y, rotation, rect_animation_playback_type, rect_animation_name)
        last_widget_hidden = false
    else
        last_widget_hidden = true
        last_widget_x = x
        last_widget_y = y
        last_widget_width = w
        last_widget_height = h
    end
end

function draw_line(gui, x1, y1, x2, y2, thickness, color, alpha, end_spacing, arrow_size, arrow_pos)
    thickness = thickness or 1
    end_spacing = end_spacing or 0
    arrow_pos = arrow_pos or 0.5
    color = color or "white"
    alpha = alpha or 1
    local sprite = base_dir .. "files/ui_gfx/line_dot_"..color..".png"
    local dx = (x2-x1)
    local dy = (y2-y1)
    local length = math.sqrt(dx*dx+dy*dy)
    dx = dx/length
    dy = dy/length
    local rotation = math.atan2(-dx, dy)
    local x_off, y_off = complexx(-0.5*thickness, 0.5*thickness, dx, dy)
    gui_image_bounded(gui, get_id(), x1+dx*end_spacing+x_off, y1+dy*end_spacing+y_off, sprite,
                      alpha, thickness, length+0.5*thickness-2*end_spacing, rotation)

    if(arrow_size) then
        local x0 = lerp(x1, x2, arrow_pos)+dx*arrow_size/2
        local y0 = lerp(y1, y2, arrow_pos)+dy*arrow_size/2
        local xt, yt = complexx(-arrow_size, arrow_size/2, dx,dy)
        draw_line(gui, x0, y0, x0+xt, y0+yt, thickness, color, alpha)
        xt, yt = complexx(-arrow_size, -arrow_size/2, dx,dy)
        draw_line(gui, x0, y0, x0+xt, y0+yt, thickness, color, alpha)
    end
end

function draw_box(gui, x, y, width, height, thickness, color, alpha)
    draw_line(gui, x, y, x+width, y, thickness, color, alpha)
    draw_line(gui, x+width, y, x+width, y+height, thickness, color, alpha)
    draw_line(gui, x+width, y+height, x, y+height, thickness, color, alpha)
    draw_line(gui, x, y+height, x, y, thickness, color, alpha)
end

function draw_spline(gui, x0, y0, x1, y1, x2, y2, x3, y3, thickness, color, alpha, end_spacing, arrow_size, arrow_pos, segment_spacing)
    segment_spacing = segment_spacing or 0.05
    arrow_pos = arrow_pos or 0.5
    local x = x0
    local y = y0
    local drew_arrow = false
    for t = segment_spacing,1+0.5*segment_spacing,segment_spacing do
        local new_x = bezier(x0, x1, x2, x3, t)
        local new_y = bezier(y0, y1, y2, y3, t)

        if(not drew_arrow and t >= 1-1.5*segment_spacing) then
            draw_line(gui, x, y, new_x, new_y, thickness, color, alpha, end_spacing, arrow_size, arrow_pos)
            drew_arrow = true
        else
            draw_line(gui, x, y, new_x, new_y, thickness, color, alpha, end_spacing)
        end
        x = new_x
        y = new_y
    end
end

function test_drag(gui, id)
    if(other_window_blocking) then return false end
    GuiOptionsAddForNextWidget(gui, GUI_OPTION.IsDraggable)
    GuiOptionsAddForNextWidget(gui, GUI_OPTION.NoPositionTween)
    local test_x = mx-8
    local test_y = my-8

    local old_interactive = interactive
    set_interactive(gui, true)
    GuiButton(gui, get_id("drag_test"), test_x, test_y, "     ")
    set_interactive(gui, old_interactive)
    local clicked, right_clicked, hovered, text_x, text_y, width, height = GuiGetPreviousWidgetInfo(gui)
    window_active = window_active or clicked
    if(math.abs(text_x-test_x) > 4 or math.abs(text_y-test_y) > 4) then
        -- window.x = window.x+text_x-test_x-11
        -- window.y = window.y+text_y-test_y-9
        return true
    else
        return false
    end
end

local windows = {}
local grabbed = nil

function make_window(base_id, base_x, base_y, width, height, show, title)
    show = show or true
    local window = {id = base_id,
                    title = title,
                    default_x = base_x,
                    default_y = base_y,
                    default_width = width,
                    default_height = height,
                    x = ModSettingGet(mod_name.."."..base_id.."_x") or base_x,
                    y = ModSettingGet(mod_name.."."..base_id.."_y") or base_y,
                    width = ModSettingGet(mod_name.."."..base_id.."_width") or width,
                    height = ModSettingGet(mod_name.."."..base_id.."_height") or height,
                    -- x = base_x,
                    -- y = base_y,
                    -- width = width,
                    -- height = height,
                    show = ModSettingGet(mod_name.."."..base_id.."_show"),
                    hovered_frames=0,
                    x_scroll = 0,
                    x_scroll_target = 0,
                    y_scroll = 0}
    if(window.show == nil) then
        window.show = show
    end
    table.insert(windows, window)
    return window
end

function start_window(gui, window, order)
    if(not window.show) then
        ModSettingSet(mod_name.."."..window.id.."_show", window.show)
        return false
    end

    z_set_global(gui, -100*(#windows-order))

    if(grabbed == window.id..-1) then
        if(not window.dragging) then
            drag_mx = mx-window.x
            drag_my = my-window.y
        end
        window.x = mx-drag_mx
        window.y = my-drag_my
        window.dragging = true
    end

    local sx = 0
    local sy = 0
    for i=0,3 do
        if(grabbed == window.id..i) then
            sx = (i+1)%4>=2 and 1 or -1
            sy =       i>=2 and 1 or -1
        end
    end
    for i=0,3 do
        if(grabbed == window.id..i+4) then
            if(i%2 == 0) then
                sx = (i+1)%4>=2 and 1 or -1
            else
                sy =       i>=2 and 1 or -1
            end
        end
    end

    if(grabbed ~= nil) then
        local grabbed_number = tonumber(string.match(grabbed, "[-0-9]+$"))
        if(grabbed_number ~= nil and grabbed == window.id..grabbed_number and 0 <= grabbed_number and grabbed_number < 8) then
            if(not window.dragging) then
                drag_mx = mx-sx*window.width
                drag_my = my-sy*window.height
                window.scale_mx = mx-window.x
                window.scale_my = my-window.y
            end

            if(sx ~= 0) then
                window.width = math.max(sx*(mx-drag_mx), window_min_width)
                if(sx == -1) then
                    window.x = math.min(mx-window.scale_mx, drag_mx-window.scale_mx-window_min_width)
                end
            end

            if(sy ~= 0) then
                window.height = math.max(sy*(my-drag_my), window_min_height)
                if(sy == -1) then
                    window.y = math.min(my-window.scale_my, drag_my-window.scale_my-window_min_height)
                end
            end
            window.dragging = true
        end
    end

    if(grabbed==nil) then
        window.dragging = false
    -- else
        window.x = clamp(window.x, 0, gw)
        window.y = clamp(window.y, 0, gh)
        ModSettingSet(mod_name.."."..window.id.."_x", window.x)
        ModSettingSet(mod_name.."."..window.id.."_y", window.y)
        ModSettingSet(mod_name.."."..window.id.."_width", window.width)
        ModSettingSet(mod_name.."."..window.id.."_height", window.height)
        ModSettingSet(mod_name.."."..window.id.."_show", window.show)
    end

    local width = window.width
    local height = window.height-drag_bar_height
    if(window.x_scroll_active) then
        height = height-8
    end

    -- local box_x0 = window.x+4 +20-2
    -- local box_y0 = window.y+20+drag_bar_height-2+4
    -- local box_x1 = window.x+4 +width-8-2 - 20
    -- local box_y1 = box_y0+height-40
    -- draw_line(gui, box_x0, box_y0, box_x1, box_y0, 0.5)
    -- draw_line(gui, box_x1, box_y1, box_x1, box_y0, 0.5)
    -- draw_line(gui, box_x1, box_y1, box_x0, box_y1, 0.5)
    -- draw_line(gui, box_x0, box_y0, box_x0, box_y1, 0.5)

    GuiOptionsAdd(gui, GUI_OPTION.Layout_NoLayouting)
    GuiBeginScrollContainer(gui, get_id(window.id), window.x, window.y, width, window.height, false)
    z_set_next_relative(gui, -1.0)
    GuiText(gui, window.x, window.y-2, window.title)
    GuiOptionsRemove(gui, GUI_OPTION.Layout_NoLayouting)
    z_set_next_relative(gui, 0.5)
    set_interactive(gui, grabbed == nil)
    GuiBeginScrollContainer(gui, get_id(window.id.."inner"), 0, drag_bar_height-2, width-8-2, height, true)
    max_x = 0
    max_y = 0

    local lx = window.x-1
    local ly = window.y+drag_bar_height-2-1
    local ux = window.x+window.width+6
    local uy = window.y+drag_bar_height+height+6
    inner_window_hovered = (lx <= mx and mx < ux and ly <= my and my < uy)

    set_interactive(gui, not other_window_blocking)

    local clicked, right_clicked, hovered, sx, sy, swidth, sheight = GuiGetPreviousWidgetInfo(gui)
    if(not other_window_blocking and (clicked or right_clicked)) then
        window_active = true
    end

    local dot_sprite = base_dir .. "files/ui_gfx/line_dot_white.png"
    GuiImage(gui, get_id(), 0, 0, dot_sprite, 0, 1, 0, 0)
    local _, __, ___, x0, y0, w0, h0 = GuiGetPreviousWidgetInfo(gui)
    scroll_y = (window.y+drag_bar_height-2)-y0+4

    local margin_x = 3
    local margin_y = 3
    -- local margin_x = -20
    -- local margin_y = -20
    bound_x_min = -margin_x-2
    bound_y_min = scroll_y - margin_y
    bound_x_max = width-8-2 + margin_x
    bound_y_max = scroll_y + height + margin_y

    window.y_scroll = scroll_y

    return true
end

function extend_max_bound(x, y)
    max_x = math.max(x, max_x)
    max_y = math.max(y, max_y)
end

function end_window(gui, window, order)
    bound_x_min = 0
    bound_y_min = 0
    bound_x_max = gw
    bound_y_max = gh
    set_interactive(gui, true)

    if(not window.show) then return end
    GuiLayoutEnd(gui, 0, 0, true, 0, 0)
    GuiEndScrollContainer(gui)
    GuiEndScrollContainer(gui)

    if(max_x > window.width) then
        local x_scroll_max = max_x-window.width
        window.x_scroll = math.min(window.x_scroll, x_scroll_max)
        window.x_scroll_target = math.min(window.x_scroll_target, x_scroll_max)
        GuiColorSetForNextWidget(gui,1,1,1,0)
        local new_x_scroll = GuiSlider(gui, get_id(window.id.."_horizontal_scrollbar"), window.x-2.25, window.y+window.height-4, "",
                                              window.x_scroll, 0, x_scroll_max, 0, 0, " ", window.width-4)
        if(math.abs(new_x_scroll-window.x_scroll) > 1) then
            window.x_scroll_target = new_x_scroll
        end
        window.x_scroll = lerp(window.x_scroll, window.x_scroll_target, 0.3)
        local clicked, right_clicked, hovered, x, y, width, height = GuiGetPreviousWidgetInfo(gui)
        if(not other_window_blocking and (clicked or right_clicked)) then
            window_active = true
        end
        window.x_scroll_active = true
    else
        window.x_scroll = 0
        window.x_scroll_active = false
    end

    GuiImageNinePiece(gui, get_id(window.id.."_move_bar"),
                      window.x, window.y, window.width+4, drag_bar_height-2)

    if(window.hovered_frames <= 0) then
        window.hovered = nil
    end
    window.hovered_frames = window.hovered_frames-1

    local lx = window.x-1
    local ly = window.y-1
    local cy = window.y+drag_bar_height
    local ux = window.x+window.width+6
    local uy = window.y+window.height+6
    local resize_tolerance = 2
    local edge_hovered = {}
    edge_hovered[0] = (math.abs(mx-lx) < resize_tolerance
                           and ly-resize_tolerance < my and my < uy+resize_tolerance)
    edge_hovered[1] = (math.abs(my-ly) < resize_tolerance
                           and lx-resize_tolerance < mx and mx < ux+resize_tolerance)
    edge_hovered[2] = (math.abs(mx-ux) < resize_tolerance
                           and ly-resize_tolerance < my and my < uy+resize_tolerance)
    edge_hovered[3] = (math.abs(my-uy) < resize_tolerance
                           and lx-resize_tolerance < mx and mx < ux+resize_tolerance)

    local window_hovered = (lx <= mx and mx < ux and ly <= my and my < uy)

    -- Debug lines for checking alignment
    -- GuiZSet(gui, -1.0)
    -- draw_line(gui, lx,ly,ux,ly, 1.0, "white", 1.0, 0)
    -- draw_line(gui, ux,ly,ux,uy, 1.0, "white", 1.0, 0)
    -- draw_line(gui, ux,uy,lx,uy, 1.0, "white", 1.0, 0)
    -- draw_line(gui, lx,uy,lx,ly, 1.0, "white", 1.0, 0)

    -- draw_line(gui, lx,cy,ux,cy, 1.0, "white", 1.0, 0)

    -- draw_line(gui, ux-9,ly,ux-9,cy, 1.0, "white", 1.0, 0)

    -- draw_line(gui, lx,my,ux,my, 1.0, "white", 1.0, 0)
    -- draw_line(gui, mx,ly,mx,uy, 1.0, "white", 1.0, 0)
    -- GuiZSet(gui, 0.0)

    local corner_hovered = false
    for i=0,3 do
        if(edge_hovered[i] and edge_hovered[(i+1)%4]) then
            if(window.hovered==nil or window.hovered==i) then
                window.hovered = i
                window.hovered_frames = 2
            end
            corner_hovered = true
        end
    end
    if(not corner_hovered) then
        for i=0,3 do
            if(edge_hovered[i]) then
                if(window.hovered==nil or window.hovered==i+4) then
                    window.hovered = i+4
                    window.hovered_frames = 2
                end
                corner_hovered = true
            end
        end
    end

    for i=0,3 do
        if(grabbed == window.id..i or (window.hovered==i and grabbed==nil)) then
            -- draw_line(gui, mx, my, mx+4, my+4,1,"white",1,0,5,1)
            -- draw_line(gui, mx, my, mx-4, my-4,1,"white",1,0,5,1)

            z_set_next_relative(gui, -1.0)
            local resize_sprite = base_dir.."files/ui_gfx/resize.png"
            local im_w, im_h = GuiGetImageDimensions(gui, resize_sprite)
            local ix = mx+(i%2==1 and 2.5 or -5.5)-0.25
            local iy = my+(i%2==1 and -5.5 or -2.5)-0.25
            local angle = i%2==1 and math.pi/4 or -math.pi/4
            GuiImage(gui, get_id(window.id.."_resize_icon"), ix, iy, resize_sprite, 1, 1, 0, angle)

            if(test_drag(gui, window.id.."_corner_"..i)) then
                grabbed = window.id..i
            else
                grabbed = nil
            end
        end
    end
    for i=0,3 do
        if(grabbed == window.id..i+4 or (window.hovered==i+4 and grabbed==nil)) then
            z_set_next_relative(gui, -1.0)
            local resize_sprite = base_dir.."files/ui_gfx/resize.png"
            local ix = mx+(i%2==1 and -2.25 or 5.5)
            local iy = my+(i%2==1 and -6 or -2.5)
            local angle = i%2==1 and 0 or math.pi/2
            GuiImage(gui, get_id(window.id.."_resize_icon"), ix, iy, resize_sprite, 1, 1, 0, angle)

            if(test_drag(gui, window.id.."_edge_"..i)) then
                grabbed = window.id..i+4
            else
                grabbed = nil
            end
        end
    end

    if(not corner_hovered
           and (window.hovered == nil or window.hovered == -1)
           and (lx <= mx and mx < ux-9 and ly <= my and my < cy))
    then
        window.hovered = -1
        window.hovered_frames = 2
    end

    if(grabbed == window.id..-1 or (window.hovered==-1 and grabbed==nil)) then
        if(test_drag(gui, window.id.."_drag")) then
            grabbed = window.id..-1
        else
            grabbed = nil
        end
    end

    z_set_next_relative(gui, -1.0)
    local close_window_sprite = base_dir.."files/ui_gfx/close.png"
    local im_w, im_h = GuiGetImageDimensions(gui, close_window_sprite)
    local close_pressed = GuiImageButton(gui, get_id(window.id.."_close_button"),
                                         window.x+window.width-math.floor(im_w/2), window.y, "", close_window_sprite)
    GuiTooltip(gui, "close", "")
    if(close_pressed) then
        window.show = false
    end

    if(not other_window_blocking and window_hovered) then
        other_window_blocking = true
    end
end

top_window = -1

function draw_windows(gui)
    other_window_blocking = false
    for i,window in ipairs(windows) do
        window_active = false
        if(start_window(gui, window, i) and window.func ~= nil) then
            window.func(window)
        end
        end_window(gui, window)
        window.index = i
        --technically not right, since one window's id can be a substring of another's but good enough
        if(window_active or grabbed ~= nil and string.sub(grabbed,1,#window.id) == window.id) then
            gui_selected = new_gui_selected
            new_gui_selected = nil
            top_window = i
            other_window_blocking = true
        end
    end

    if(top_window ~= -1 and top_window ~= 1) then
        table.insert(windows, 1, table.remove(windows, top_window))
        top_window = -1
    end
    set_interactive(gui, true)
end

function reset_windows()
    for i,window in ipairs(windows) do
        window.x = window.default_x
        window.y = window.default_y
        window.width = window.default_width
        window.height = window.default_height
    end
end


function do_window_show_hide_button(gui, window, x, y, icon)
    local pressed = GuiImageButton(gui, get_id((window.id).."show_hide_button"), x, y, "", icon)
    local tooltip = "Show "..window.title
    if(window.show) then
        tooltip = "Hide "..window.title
    end
    GuiTooltip(gui, tooltip, "")
    if(pressed) then
        window.show = not window.show
        top_window = window.index
    end
end
