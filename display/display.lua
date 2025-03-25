local convertcc = require("convertcc")

function drawPx(x, y, color, mon)
  mon.setBackgroundColor(color)
  mon.setCursorPos(x, y)
  mon.write(" ")
end

print("Image Display v0.0.1")

local url = ...
local savedImageFilename = "imageText.txt"
local savedPaletteFilename = "palette.txt"
local imageText = ""
local palette = nil

print("Detecting monitor...")
local p_dirs = peripheral.getNames()
local monitorSide = ""
for i = 1, #p_dirs do
  local periType = peripheral.getType(p_dirs[i])
  if periType == "monitor" then
    monitorSide = p_dirs[i]
    print("Monitor found on " .. monitorSide .. " side!")
    break
  end
end

local mon = peripheral.wrap(monitorSide)
mon.setTextScale(0.5)

if url ~= nil then
  print("Downloading image from " .. url .. "...")
  local response = http.get(url)
  if response.getResponseCode() ~= 200 then
    error("Failed to download image, code: " .. tostring(response.getResponseCode()))
  end

  local temp_filename = "temp.png"
  local file = fs.open(temp_filename, "wb")
  file.write(response.readAll())
  file.close()

  local width, height = mon.getSize()
  imageText, palette = convertcc.process_image(temp_filename, width, height, monitorSide)

  print("Saving imageText and palette...")
  local saveFile = fs.open(savedImageFilename, "w")
  saveFile.write(imageText)
  saveFile.close()

  local paletteFile = fs.open(savedPaletteFilename, "w")
  paletteFile.write(textutils.serialize(palette))
  paletteFile.close()
else
  print("Reading imageText and palette from file...")
  local file = fs.open(savedImageFilename, "r")
  imageText = file.readAll()
  file.close()
  
  local pFile = fs.open(savedPaletteFilename, "r")
  palette = textutils.unserialize(pFile.readAll())
  pFile.close()
  
  convertcc.set_palette(palette, monitorSide)
end

local hex_table = {
  ["0"] = 1,  ["1"] = 2,    ["2"] = 4,    ["3"] = 8,
  ["4"] = 16, ["5"] = 32,   ["6"] = 64,   ["7"] = 128,
  ["8"] = 256,["9"] = 512,  ["a"] = 1024, ["b"] = 2048,
  ["c"] = 4096,["d"] = 8192,["e"] = 16384,["f"] = 32768
}
local crrX = 1
local crrY = 1
for i = 1, #imageText do
  local char = string.sub(imageText, i, i)
  if char == "\n" then
    crrY = crrY + 1
    crrX = 1
  else
    local colorValue = hex_table[char]
    drawPx(crrX, crrY, colorValue, mon)
    crrX = crrX + 1
  end
end

print("Done!")
