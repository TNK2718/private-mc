rednet.open("back")

-- Find server ID
local serverID = rednet.lookup("stockpile")
if not serverID then
    print("Stockpile server not found.")
    rednet.close("back")
  return
end

-- Get storage inventory list
local adjacentsNames = {
    "front",
    "back",
    "left",
    "right",
    "top",
    "bottom"
}
local invs = {}
for _, p in ipairs(peripheral.getNames()) do
  if peripheral.hasType(p, "inventory") then
    -- Don't count adjacent inventories as storage
    local isAdjacent = false
    for _, name in ipairs(adjacentsNames) do
      if p == name then
        isAdjacent = true
        break
      end
    end

    if not isAdjacent and p:find("item_silo") then
        table.insert(invs, p)
    end
  end
end

-- Reset units
local command = "unit.set('all', nil)"
rednet.send(serverID, command, "stockpile")
print("Sending command: " .. command)

-- Get response
local senderID, message, protocol = rednet.receive("stockpile", 10)
if message then
  print("Got response:")
  if type(message) == "table" then
    print(textutils.serialize(message))
  else
    print(message)
  end
else
  print("No response.")
end

-- Send unit.set command
local command = "unit.set('all', " .. textutils.serialize(invs) .. ")"
rednet.send(serverID, command, "stockpile")
print("Sending command: " .. command)

-- Get response
local senderID, message, protocol = rednet.receive("stockpile", 10)
if message then
  print("Got response:")
  if type(message) == "table" then
    print(textutils.serialize(message))
  else
    print(message)
  end
else
  print("No response.")
end

-- Send unit.is_io command
local command = "unit.is_io('all', false)"
rednet.send(serverID, command, "stockpile")
print("Sending command: " .. command)

-- Get response
local senderID, message, protocol = rednet.receive("stockpile", 10)
if message then
  print("Got response:")
  if type(message) == "table" then
    print(textutils.serialize(message))
  else
    print(message)
  end
else
  print("No response.")
end

rednet.close("back")
