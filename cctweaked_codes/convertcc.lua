local png = require "png"

local base_palette = {
  {240,240,240}, {242,178,51}, {229,127,216}, {153,178,242},
  {222,222,108}, {127,204,25}, {242,178,204}, {76,76,76},
  {153,153,153}, {76,153,178}, {178,102,229}, {37,49,146},
  {127,102,76}, {87,166,78}, {204,76,76}, {25,25,25}
}

local color_to_char = {
  ["240,240,240"] = "0",
  ["242,178,51"]   = "1",
  ["229,127,216"]  = "2",
  ["153,178,242"]  = "3",
  ["222,222,108"]  = "4",
  ["127,204,25"]   = "5",
  ["242,178,204"]  = "6",
  ["76,76,76"]     = "7",
  ["153,153,153"]  = "8",
  ["76,153,178"]   = "9",
  ["178,102,229"]  = "a",
  ["37,49,146"]    = "b",
  ["127,102,76"]   = "c",
  ["87,166,78"]    = "d",
  ["204,76,76"]    = "e",
  ["25,25,25"]     = "f"
}

local function color_key(color)
  return string.format("%d,%d,%d", color[1], color[2], color[3])
end

local function normalize_pixel(pixel)
  local r, g, b = pixel.r, pixel.g, pixel.b
  if r <= 1 and g <= 1 and b <= 1 then
    r = math.floor(r * 255 + 0.5)
    g = math.floor(g * 255 + 0.5)
    b = math.floor(b * 255 + 0.5)
  end
  return r, g, b
end

local function find_nearest_color(r, g, b)
  local best_color, best_dist = nil, math.huge
  for _, pal in ipairs(base_palette) do
    local dr = r - pal[1]
    local dg = g - pal[2]
    local db = b - pal[3]
    local dist = dr * dr + dg * dg + db * db
    if dist < best_dist then
      best_dist = dist
      best_color = pal
    end
  end
  return best_color
end

local function convertcc(image, width, height, get_pixel)
  local text_representation = ""
  for y = 1, height do
    for x = 1, width do
      local pixel = get_pixel(x, y)
      local r, g, b = normalize_pixel(pixel)
      local nearest = find_nearest_color(r, g, b)
      local key = color_key(nearest)
      local char = color_to_char[key] or "?"
      text_representation = text_representation .. char
    end
    text_representation = text_representation .. "\n"
  end
  return text_representation
end

-- nearest neighbor interpolation

local function get_resized_pixel_getter(image, target_width, target_height)
  local src_width = image.width
  local src_height = image.height
  return function(x, y)
    local src_x = math.floor((x - 0.5) * src_width / target_width + 0.5)
    local src_y = math.floor((y - 0.5) * src_height / target_height + 0.5)
    if src_x < 1 then src_x = 1 end
    if src_x > src_width then src_x = src_width end
    if src_y < 1 then src_y = 1 end
    if src_y > src_height then src_y = src_height end
    return image:get_pixel(src_x, src_y)
  end
end

--

-- bicubic interpolation

local function clamp(x, lower, upper)
  return math.max(lower, math.min(upper, x))
end

local function cubicInterpolate(p0, p1, p2, p3, t)
  return p1 + 0.5 * t * (p2 - p0 + t * (2 * p0 - 5 * p1 + 4 * p2 - p3 + t * (3 * (p1 - p2) + p3 - p0)))
end

local function getBicubicPixel(image, x, y)
  local width, height = image.width, image.height
  local ix = math.floor(x)
  local iy = math.floor(y)
  local dx = x - ix
  local dy = y - iy

  local function getChannel(channel)
    local arr = {}
    for m = -1, 2 do
      local row = clamp(iy + m, 1, height)
      local col0 = clamp(ix - 1, 1, width)
      local col1 = clamp(ix, 1, width)
      local col2 = clamp(ix + 1, 1, width)
      local col3 = clamp(ix + 2, 1, width)
      local p0 = image:get_pixel(col0, row)[channel]
      local p1 = image:get_pixel(col1, row)[channel]
      local p2 = image:get_pixel(col2, row)[channel]
      local p3 = image:get_pixel(col3, row)[channel]
      arr[m + 2] = cubicInterpolate(p0, p1, p2, p3, dx)
    end
    return cubicInterpolate(arr[1], arr[2], arr[3], arr[4], dy)
  end

  local r = getChannel("r")
  local g = getChannel("g")
  local b = getChannel("b")
  local a = 1
  return {r = r, g = g, b = b, a = a}
end

local function get_resized_pixel_getter_bicubic(image, target_width, target_height)
  local src_width = image.width
  local src_height = image.height
  return function(x, y)
    local src_x = (x - 0.5) * src_width / target_width + 0.5
    local src_y = (y - 0.5) * src_height / target_height + 0.5
    return getBicubicPixel(image, src_x, src_y)
  end
end

--

local function process_image(path, target_width, target_height)
  local image = png(path)
  local get_pixel, width, height
  if target_width and target_height then
    width = target_width
    height = target_height
    -- get_pixel = get_resized_pixel_getter(image, target_width, target_height)
    get_pixel = get_resized_pixel_getter_bicubic(image, target_width, target_height)

  else
    width = image.width
    height = image.height
    get_pixel = function(x, y) return image:get_pixel(x, y) end
  end
  return convertcc(image, width, height, get_pixel)
end

return {
  process_image = process_image,
  convertcc = convertcc,
}
