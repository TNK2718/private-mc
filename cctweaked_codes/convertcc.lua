local png = require "png"

local index_to_char = {"0", "1", "2", "3", "4", "5", "6", "7", "8", "9", "a", "b", "c", "d", "e", "f"}

local function normalize_pixel(pixel)
  local r, g, b = pixel.r, pixel.g, pixel.b
  if r <= 1 and g <= 1 and b <= 1 then
    r = math.floor(r * 255 + 0.5)
    g = math.floor(g * 255 + 0.5)
    b = math.floor(b * 255 + 0.5)
  end
  return r, g, b
end

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
  return {r = r, g = g, b = b, a = 1}
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

local function find_nearest_color_in_palette(r, g, b, palette)
  local best_index, best_dist = nil, math.huge
  for i, pal in ipairs(palette) do
    local dr = r - pal.r
    local dg = g - pal.g
    local db = b - pal.b
    local dist = dr * dr + dg * dg + db * db
    if dist < best_dist then
      best_dist = dist
      best_index = i
    end
  end
  return best_index
end

local function convertcc(image, width, height, get_pixel, palette)
  local text_representation = ""
  for y = 1, height do
    for x = 1, width do
      local pixel = get_pixel(x, y)
      local r, g, b = normalize_pixel(pixel)
      local nearest_index = find_nearest_color_in_palette(r, g, b, palette)
      local char = index_to_char[nearest_index] or "?"
      text_representation = text_representation .. char
    end
    text_representation = text_representation .. "\n"
  end
  return text_representation
end

local function kmeans(samples, K, max_iter)
  local centroids = {}
  local assignments = {}
  local n = #samples
  for i = 1, K do
    local idx = math.random(n)
    centroids[i] = {r = samples[idx].r, g = samples[idx].g, b = samples[idx].b}
  end
  for iter = 1, max_iter do
    for i, sample in ipairs(samples) do
      local best_idx, best_dist = nil, math.huge
      for j, centroid in ipairs(centroids) do
        local dr = sample.r - centroid.r
        local dg = sample.g - centroid.g
        local db = sample.b - centroid.b
        local d = dr * dr + dg * dg + db * db
        if d < best_dist then
          best_dist = d
          best_idx = j
        end
      end
      assignments[i] = best_idx
    end
    local new_centroids = {}
    local counts = {}
    for i = 1, K do
      new_centroids[i] = {r = 0, g = 0, b = 0}
      counts[i] = 0
    end
    for i, sample in ipairs(samples) do
      local idx = assignments[i]
      new_centroids[idx].r = new_centroids[idx].r + sample.r
      new_centroids[idx].g = new_centroids[idx].g + sample.g
      new_centroids[idx].b = new_centroids[idx].b + sample.b
      counts[idx] = counts[idx] + 1
    end
    local changed = false
    for i = 1, K do
      if counts[i] > 0 then
        local nr = new_centroids[i].r / counts[i]
        local ng = new_centroids[i].g / counts[i]
        local nb = new_centroids[i].b / counts[i]
        if nr ~= centroids[i].r or ng ~= centroids[i].g or nb ~= centroids[i].b then
          changed = true
        end
        centroids[i] = {r = nr, g = ng, b = nb}
      end
    end
    if not changed then break end
    sleep(0)
  end
  return centroids
end

local function compute_optimal_palette(image, width, height, get_pixel)
  local samples = {}
  for y = 1, height do
    for x = 1, width do
      local pixel = get_pixel(x, y)
      samples[#samples + 1] = {r = pixel.r, g = pixel.g, b = pixel.b}
    end
  end
  local K = 16
  local max_iter = 100
  local palette = kmeans(samples, K, max_iter)
  return palette
end

local function set_palette(palette, monitorSide)
  local monitor = peripheral.wrap(monitorSide)
  local new_palette = {}
  for i, centroid in ipairs(palette) do
    monitor.setPaletteColor(2^(i - 1), centroid.r, centroid.g, centroid.b)
    local nr = math.floor(centroid.r * 255 + 0.5)
    local ng = math.floor(centroid.g * 255 + 0.5)
    local nb = math.floor(centroid.b * 255 + 0.5)
    new_palette[i] = {r = nr, g = ng, b = nb}
  end
  return new_palette
end

local function process_image(path, target_width, target_height, monitorSide)
  local image = png(path)
  sleep(0) -- Yield to allow other tasks to run
  local get_pixel, width, height
  if target_width and target_height then
    width = target_width
    height = target_height
    get_pixel = get_resized_pixel_getter_bicubic(image, target_width, target_height)
  else
    width = image.width
    height = image.height
    get_pixel = function(x, y) return image:get_pixel(x, y) end
  end
  sleep(0)
  local temp_palette = compute_optimal_palette(image, width, height, get_pixel)
  sleep(0)
  local palette = set_palette(temp_palette, monitorSide)
  local imageText = convertcc(image, width, height, get_pixel, palette)
  return imageText, palette
end

return {
  process_image = process_image,
  convertcc = convertcc,
  set_palette = set_palette,
}
