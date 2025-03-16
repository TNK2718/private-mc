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

------------------------------------------------------------
-- Octree-based color quantization implementation
------------------------------------------------------------
local Octree = {}
Octree.__index = Octree

function Octree.new(maxDepth, maxColors)
  local self = setmetatable({}, Octree)
  self.maxDepth = maxDepth or 8
  self.maxColors = maxColors or 16
  self.root = { sum_r = 0, sum_g = 0, sum_b = 0, pixel_count = 0, children = {}, level = 0 }
  self.leaves = {}    -- Final leaves (palette candidates)
  self.levels = {}    -- Node list for each level
  for i = 0, self.maxDepth do
    self.levels[i] = {}
  end
  table.insert(self.levels[0], self.root)
  return self
end

function Octree:insertColor(r, g, b)
  local function insertNode(node, r, g, b, level, octree)
    node.sum_r = node.sum_r + r
    node.sum_g = node.sum_g + g
    node.sum_b = node.sum_b + b
    node.pixel_count = node.pixel_count + 1
    if level == octree.maxDepth then
      if not node.isLeaf then
        node.isLeaf = true
        table.insert(octree.leaves, node)
      end
    else
      local shift = 8 - level
      local bit_r = math.floor(r / 2^(shift)) % 2
      local bit_g = math.floor(g / 2^(shift)) % 2
      local bit_b = math.floor(b / 2^(shift)) % 2
      local index = bit_r * 4 + bit_g * 2 + bit_b + 1
      if not node.children then node.children = {} end
      if not node.children[index] then
        node.children[index] = { sum_r = 0, sum_g = 0, sum_b = 0, pixel_count = 0, children = {}, level = level, isLeaf = false }
        table.insert(octree.levels[level], node.children[index])
      end
      insertNode(node.children[index], r, g, b, level + 1, octree)
    end
  end
  insertNode(self.root, r, g, b, 1, self)
end

-- When the number of leaves exceeds maxColors, merge lower-level nodes to reduce the number of leaves
function Octree:reduce()
  for level = self.maxDepth - 1, 0, -1 do
    local nodes = self.levels[level]
    if nodes then
      for _, node in ipairs(nodes) do
        if node.children then
          local leafChildren = {}
          for _, child in ipairs(node.children) do
            if child and child.isLeaf then
              table.insert(leafChildren, child)
            end
          end
          if #leafChildren > 0 then
            for _, child in ipairs(leafChildren) do
              node.sum_r = node.sum_r + child.sum_r
              node.sum_g = node.sum_g + child.sum_g
              node.sum_b = node.sum_b + child.sum_b
              node.pixel_count = node.pixel_count + child.pixel_count
              for i, leaf in ipairs(self.leaves) do
                if leaf == child then
                  table.remove(self.leaves, i)
                  break
                end
              end
            end
            node.children = nil
            if not node.isLeaf then
              node.isLeaf = true
              table.insert(self.leaves, node)
            end
            if #self.leaves <= self.maxColors then
              return
            end
          end
        end
      end
    end
  end
end

function Octree:getPalette()
  local palette = {}
  for _, leaf in ipairs(self.leaves) do
    local avg_r = leaf.sum_r / leaf.pixel_count
    local avg_g = leaf.sum_g / leaf.pixel_count
    local avg_b = leaf.sum_b / leaf.pixel_count
    table.insert(palette, { r = avg_r, g = avg_g, b = avg_b })
  end
  return palette
end

-- Find the nearest leaf (palette entry) in the Octree for the given color and return its index
function Octree:getColorIndex(r, g, b)
  local node = self.root
  for level = 1, self.maxDepth do
    if node.isLeaf or not node.children then
      break
    end
    local shift = 8 - level
    local bit_r = math.floor(r / 2^(shift)) % 2
    local bit_g = math.floor(g / 2^(shift)) % 2
    local bit_b = math.floor(b / 2^(shift)) % 2
    local index = bit_r * 4 + bit_g * 2 + bit_b + 1
    if node.children[index] then
      node = node.children[index]
    else
      break
    end
  end
  for i, leaf in ipairs(self.leaves) do
    if leaf == node then
      return i
    end
  end
  return 1
end

------------------------------------------------------------
-- Use Octree for the compute_optimal_palette implementation
------------------------------------------------------------
local function compute_optimal_palette(image, width, height, get_pixel)
  local octree = Octree.new(8, 16)
  for y = 1, height do
    for x = 1, width do
      local pixel = get_pixel(x, y)
      local r, g, b = pixel.r, pixel.g, pixel.b
      if r <= 1 and g <= 1 and b <= 1 then
        r = math.floor(r * 255 + 0.5)
        g = math.floor(g * 255 + 0.5)
        b = math.floor(b * 255 + 0.5)
      end
      octree:insertColor(r, g, b)
    end
  end
  while #octree.leaves > 16 do
    octree:reduce()
  end
  local palette = octree:getPalette()
  return palette, octree
end

local function set_palette(palette, monitor)
  local new_palette = {}
  for i, centroid in ipairs(palette) do
    -- monitor.setPaletteColor expects values in the range 0 to 1, so convert them
    monitor.setPaletteColor(2^(i - 1), centroid.r / 255, centroid.g / 255, centroid.b / 255)
    new_palette[i] = {r = centroid.r, g = centroid.g, b = centroid.b}
  end
  return new_palette
end

local function convertcc(image, width, height, get_pixel, palette, octree)
  local text_representation = ""
  for y = 1, height do
    for x = 1, width do
      local pixel = get_pixel(x, y)
      local r, g, b = normalize_pixel(pixel)
      local nearest_index
      if octree then
        nearest_index = octree:getColorIndex(r, g, b)
      else
        nearest_index = find_nearest_color_in_palette(r, g, b, palette)
      end
      local char = index_to_char[nearest_index] or "?"
      text_representation = text_representation .. char
    end
    text_representation = text_representation .. "\n"
  end
  return text_representation
end

local function process_image(path, target_width, target_height, monitor)
  local image = png(path)
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
  local temp_palette, octree = compute_optimal_palette(image, width, height, get_pixel)
  local palette = set_palette(temp_palette, monitor)
  return convertcc(image, width, height, get_pixel, palette, octree)
end

return {
  process_image = process_image,
  convertcc = convertcc,
}
