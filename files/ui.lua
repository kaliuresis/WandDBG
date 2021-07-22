mx = 0
my = 0
local drag_mx = 0
local drag_my = 0

local max_x
local max_y

--Constant settings windows
local drag_bar_height = 9
local window_min_width = 10
local window_min_height = 10

local named_gui_id = 100000
gui_id = 0
local gui_ids = {}
function get_id(name, n_ids)
    n_ids = n_ids or 1
    if(name ~= nil) then
        if(gui_ids[name] ~= nil) then
            return gui_ids[name]
        end
        named_gui_id = named_gui_id+n_ids
        gui_ids[name] = named_gui_id
        return named_gui_id
    end
    gui_id = gui_id+1
    return gui_id
end

function start_gui(gui)
    -- GuiStartFrame(gui)
    -- GuiOptionsAdd(gui, GUI_OPTION.NoPositionTween);
    gui_id = 0
end

function draw_line(gui, x1, y1, x2, y2, thickness, alpha, end_spacing, arrow_size, arrow_pos)
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
    GuiImage(gui, get_id(), x1+dx*end_spacing+x_off, y1+dy*end_spacing+y_off, sprite,
             alpha, thickness, length-2*end_spacing, rotation)

    if(arrow_size) then
        local x0 = lerp(x1, x2, arrow_pos)+dx*arrow_size/2
        local y0 = lerp(y1, y2, arrow_pos)+dy*arrow_size/2
        local xt, yt = complexx(-arrow_size, arrow_size/2, dx,dy)
        draw_line(gui, x0, y0, x0+xt, y0+yt, thickness, alpha)
        xt, yt = complexx(-arrow_size, -arrow_size/2, dx,dy)
        draw_line(gui, x0, y0, x0+xt, y0+yt, thickness, alpha)
    end
end

function draw_spline(gui, x0, y0, x1, y1, x2, y2, x3, y3, thickness, alpha, end_spacing, arrow_size, arrow_pos, segment_spacing)
    segment_spacing = segment_spacing or 0.05
    arrow_pos = arrow_pos or 0.5
    local x = x0
    local y = y0
    local drew_arrow = false
    for t = segment_spacing,1+0.5*segment_spacing,segment_spacing do
        local new_x = bezier(x0, x1, x2, x3, t)
        local new_y = bezier(y0, y1, y2, y3, t)

        if(not drew_arrow and t >= 1-1.5*segment_spacing) then
            draw_line(gui, x, y, new_x, new_y, thickness, alpha, end_spacing, arrow_size, arrow_pos)
            drew_arrow = true
        else
            draw_line(gui, x, y, new_x, new_y, thickness, alpha, end_spacing)
        end
        x = new_x
        y = new_y
    end
end

function test_drag(gui, id)
    GuiOptionsAddForNextWidget(gui, GUI_OPTION.IsDraggable)
    GuiOptionsAddForNextWidget(gui, GUI_OPTION.NoPositionTween)
    local test_x = mx-8
    local test_y = my-8
    GuiButton(gui, get_id("drag_test"), test_x, test_y, "     ")
    local clicked, right_clicked, hovered, text_x, text_y, width, height = GuiGetPreviousWidgetInfo(gui)
    if(math.abs(text_x-test_x) > 4 or math.abs(text_y-test_y) > 4) then
        -- window.x = window.x+text_x-test_x-11
        -- window.y = window.y+text_y-test_y-9
        return true
    else
        return false
    end
end

function make_window(base_id, base_x, base_y, width, height)
    return {id = base_id,
            x = ModSettingGet(mod_name.."."..base_id.."_x") or base_x,
            y = ModSettingGet(mod_name.."."..base_id.."_y") or base_y,
            width = ModSettingGet(mod_name.."."..base_id.."_width") or width,
            height = ModSettingGet(mod_name.."."..base_id.."_height") or height,
            show = ModSettingGet(mod_name.."."..base_id.."_show") or true,
            hovered_frames=0,
            x_scroll = 0}
end

function start_window(gui, window)
    if(not window.show) then return false end

    if(window.grabbed==-1) then
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
        if(window.grabbed == i) then
            sx = (i+1)%4>=2 and 1 or -1
            sy =       i>=2 and 1 or -1
        end
    end
    for i=0,3 do
        if(window.grabbed == i+4) then
            if(i%2 == 0) then
                sx = (i+1)%4>=2 and 1 or -1
            else
                sy =       i>=2 and 1 or -1
            end
        end
    end

    if(window.grabbed ~= nil and 0 <= window.grabbed and window.grabbed < 8) then
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

    if(window.grabbed==nil) then
        window.dragging = false
    -- else
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
    GuiOptionsAdd(gui, GUI_OPTION.Layout_NoLayouting)
    GuiBeginScrollContainer(gui, get_id(window.id), window.x, window.y, width, window.height, false)
    GuiOptionsRemove(gui, GUI_OPTION.Layout_NoLayouting)
    GuiZSetForNextWidget(gui, 0.5)
    if(window.grabbed ~= nil) then GuiOptionsAdd(gui, GUI_OPTION.NonInteractive) end
    GuiBeginScrollContainer(gui, get_id(window.id.."inner"), 0, drag_bar_height-2, width-8-2, height, true)
    GuiOptionsRemove(gui, GUI_OPTION.NonInteractive)
    max_x = 0
    max_y = 0
    return true
end

function extend_max_bound(x, y)
    max_x = math.max(x, max_x)
    max_y = math.max(y, max_y)
end

function end_window(gui, window)
    if(not window.show) then return end
    GuiLayoutEnd(gui, 0, 0, true, 0, 0)
    GuiEndScrollContainer(gui)
    GuiEndScrollContainer(gui)

    if(max_x > window.width) then
        local x_scroll_max = max_x-window.width
        window.x_scroll = math.min(window.x_scroll, x_scroll_max)
        GuiColorSetForNextWidget(gui,1,1,1,0)
        window.x_scroll = GuiSlider(gui, get_id(window.id.."_horizontal_scrollbar"), window.x-3, window.y+window.height-4, "",
                                    window.x_scroll, 0, x_scroll_max, 0, 0, "", window.width-4)
        window.x_scroll_active = true
    else
        window.x_scroll = 0
        window.x_scroll_active = false
    end

    local drag_bar_x = window.x
    local drag_bar_y = window.y
    GuiImageNinePiece(gui, get_id(window.id.."_move_bar"),
                      drag_bar_x, drag_bar_y, window.width+4, drag_bar_height-2)

    if(window.hovered_frames <= 0) then
        window.hovered = nil
    end
    window.hovered_frames = window.hovered_frames-1

    local lx = window.x-1
    local ly = drag_bar_y-1
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

    -- Debug lines for checking alignment
    -- GuiZSet(gui, -1.0)
    -- draw_line(gui, lx,ly,ux,ly, 1.0, 1.0, 0)
    -- draw_line(gui, ux,ly,ux,uy, 1.0, 1.0, 0)
    -- draw_line(gui, ux,uy,lx,uy, 1.0, 1.0, 0)
    -- draw_line(gui, lx,uy,lx,ly, 1.0, 1.0, 0)

    -- draw_line(gui, lx,cy,ux,cy, 1.0, 1.0, 0)

    -- draw_line(gui, ux-9,ly,ux-9,cy, 1.0, 1.0, 0)

    -- draw_line(gui, lx,my,ux,my, 1.0, 1.0, 0)
    -- draw_line(gui, mx,ly,mx,uy, 1.0, 1.0, 0)
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
        if(window.grabbed == i or (window.hovered==i and window.grabbed==nil)) then
            -- draw_line(gui, mx, my, mx+4, my+4,1,1,0,5,1)
            -- draw_line(gui, mx, my, mx-4, my-4,1,1,0,5,1)

            GuiZSetForNextWidget(gui, -1.0)
            local resize_sprite = base_dir.."files/ui_gfx/resize.png"
            local im_w, im_h = GuiGetImageDimensions(gui, resize_sprite)
            local ix = mx+(i%2==1 and 2.5 or -5.5)-0.25
            local iy = my+(i%2==1 and -5.5 or -2.5)-0.25
            local angle = i%2==1 and math.pi/4 or -math.pi/4
            GuiImage(gui, get_id(window.id.."_resize_icon"), ix, iy, resize_sprite, 1, 1, 0, angle)

            if(test_drag(gui, window.id.."_corner_"..i)) then
                window.grabbed = i
            else
                window.grabbed = nil
            end
        end
    end
    for i=0,3 do
        if(window.grabbed == i+4 or (window.hovered==i+4 and window.grabbed==nil)) then
            GuiZSetForNextWidget(gui, -1.0)
            local resize_sprite = base_dir.."files/ui_gfx/resize.png"
            local ix = mx+(i%2==1 and -2.25 or 5.5)
            local iy = my+(i%2==1 and -6 or -2.5)
            local angle = i%2==1 and 0 or math.pi/2
            GuiImage(gui, get_id(window.id.."_resize_icon"), ix, iy, resize_sprite, 1, 1, 0, angle)

            if(test_drag(gui, window.id.."_edge_"..i)) then
                window.grabbed = i+4
            else
                window.grabbed = nil
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

    if(window.grabbed==-1 or (window.hovered==-1 and window.grabbed==nil)) then
        if(test_drag(gui, window.id.."_drag")) then
            window.grabbed = -1
        else
            window.grabbed = nil
        end
    end

    GuiZSetForNextWidget(gui, -1.0)
    local close_window_sprite = base_dir.."files/ui_gfx/close.png"
    local im_w, im_h = GuiGetImageDimensions(gui, close_window_sprite)
    local close_pressed = GuiImageButton(gui, get_id(window.id.."_close_button"),
                                         window.x+window.width-math.floor(im_w/2), window.y, "", close_window_sprite)
    GuiTooltip(gui, "close", "")
    if(close_pressed) then
        window.show = false
    end
end
