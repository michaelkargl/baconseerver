-- https://basalt.madefor.cc/references/main.html
local basalt = require('basalt')

-- @summary draws a horizontal line
-- @param canvas <basalt_canvas>
-- @param pos <vector2> xy line origin
-- @param length <vector2> length of the vertical line
-- @param color <colors> optional
-- @param bg_color <colors> optional
-- @param edge_char <char> optional characters at the beginning and end
-- @example draw_hline(main:getCanvas(), vector.new(1,2,3), 10)
function draw_hline(canvas, pos, length, color, bg_color, corner_char)
    if color == nil then color = colors.black end
    if bg_color == nil then bg_color = colors.white end
    if corner_char == nil then corner_char = '-' end

    local left = pos
    local right = vector.new(left.x + length, left.y, 0)

    -- line
    canvas:line(
        left.x + string.len(corner_char),
        left.y,
        right.x - string.len(corner_char),
        right.y,
        '-',
        color,
        bg_color)
    -- edges
    canvas:text(left.x, left.y, corner_char, color, bg_color)
    canvas:text(right.x, right.y, corner_char, color, bg_color)
end

-- @summary draws a vertical line
-- @param canvas <basalt_canvas>
-- @param pos <vector2> xy line origin
-- @param height <vector2> length of the vertical line
-- @param color <colors> optional
-- @param bg_color <colors> optional
-- @param edge_char <char> optional characters at the beginning and end
-- @example draw_vline(main:getCanvas(), vector.new(1,2,3), 10)
function draw_vline(canvas, pos, height, color, bg_color, edge_char)
    if color == nil then color = colors.black end
    if bg_color == nil then bg_color = colors.white end
    if edge_char == nil then edge_char = '|' end

    local top = pos
    local bottom = vector.new(top.x, top.y + height, 0)

    -- line
    canvas:line(
        top.x,
        top.y + string.len(edge_char),
        bottom.x,
        bottom.y - string.len(edge_char),
        '|',
        color,
        bg_color)
    -- edges
    canvas:text(top.x, top.y, edge_char, color, bg_color)
    canvas:text(bottom.x, bottom.y, edge_char, color, bg_color)
end

-- @summary draws a rectangular borderr
-- @param canvas <basalt_canvas>
-- @param pos <vector2> top-left origin
-- @param size <vector2> size x, y
-- @param color <colors> optional
-- @param bg_color <colors> optional
-- @example draw_frame(main:getCanvas(), vector.new(1,2,3), vector.new(4,5,6))
function draw_frame(canvas, pos, size, color, bg_color)
    -- default values
    if color == nil then color = colors.black end
    if bg_color == nil then bg_color = colors.white end
    local corner_char = '+'
    
    local top_left = vector.new(pos.x, pos.y, 0)
    local top_right = vector.new(pos.x + size.x, pos.y, 0)
    local bottom_left = vector.new(pos.x, pos.y + size.y, 0)
 
    -- left, right
    draw_vline(canvas, top_left, size.y, color, bg_color, corner_char)
    draw_vline(canvas, top_right, size.y, color, bg_color, corner_char)
    -- top, bottom
    draw_hline(canvas, top_left, size.x, color, bg_color, corner_char)
    draw_hline(canvas, bottom_left, size.x, color, bg_color, corner_char)
end