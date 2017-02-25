local arcFns = {}
local arcMt = {__index = arcFns}
function Arc() 
  local ot = {}
  setmetatable(ot, arcMt)
  return ot
end

local arcSetFns = {}
local arcSetMt = {__index=arcSetFns}
function arcSetMt:__add(other)
  local incl = {}
  for _, d in pairs(self) do
    incl[d] = true
  end
  for _, d in pairs(other) do
    incl[d] = true
  end
  local out = {}
  for d, _ in pairs(incl) do
    table.insert(out, d)
  end
  setmetatable(out, arcSetMt)
  return out
end

--[[
local box = "█"
local rels = {
  SB1 = {4,1}, 
  SB2 = {5,1}, 
  SMF1 = {6,2}, 
  SMF2 = {6,3}, 
  SMA1 = {6,4}, 
  SMA2 = {6,5}, 
  SS1 = {5,6}, 
  SS2 = {4,6}, 
  PS1 = {3,6}, 
  PS2 = {2,6}, 
  PMA1 = {1,5}, 
  PMA2 = {1,4}, 
  PMF1 = {1,3}, 
  PMF2 = {1,2}, 
  PB1 = {2,1}, 
  PB2 = {3,1}
}
function arcSetMt:__tostring()
  local out = {{},{},{},{},{},{}}
  for i = 1,6 do
    for j = 1,6 do
      out[i][j] = " "
    end
  end
  for _,d in pairs(self) do
    local x,y = table.unpack(rels[d])
    out[y][x] = box
  end
  for k,v in pairs(out) do
    out[k] = table.concat(out[k],"")
  end
  return table.concat(out, "\n")
end
]]
function arcSetMt:__tostring()
  return "Arc: " .. table.concat(self, " ")
end



local names = {"SB1", "SB2", "SMF1", "SMF2", "SMA1", "SMA2", "SS1", "SS2", "PS1", "PS2", "PMA1", "PMA2", "PMF1", "PMF2", "PB1", "PB2"}
local cardinal = {}
local angles = {}

local da = 2*math.pi/#names
for i=1,#names do
  local angle = da*(i-1) + da/2
  cardinal[angle] = names[i]
  angles[names[i]] = angle
end

local sweepFns = { }
local sweepMt = {__index = sweepFns }
arcFns.from = function(self, direction)
  assert(type(self) == "table", "from must be called as Arc():from(...)")
  local ot = { from = math.rad(direction) }
  setmetatable(ot, sweepMt)
  return ot
end

local function normalize_direction(angle)
  if angle > 2*math.pi then return math.fmod(angle, 2*math.pi) end
  if angle < 0 then return 2*math.pi + math.fmod(angle, 2*math.pi) end
  return angle
end

function sweepFns:to(direction)
  assert(type(self.from) == "number", "From direction must be numeric degrees")
  local from = normalize_direction(self.from)
  local to = normalize_direction(math.rad(direction))
  if to < from then to = to + 2*math.pi end
  
  local out = {}
  for i=1,#names do
    local angle = angles[names[i]]
    if from - angle > 0 then angle = angle + 2*math.pi end
    if to > angle then 
      table.insert(out, names[i])
    end
  end
  setmetatable(out, arcSetMt)
  return out
end

local vnames = {"SB1", "SB2", "SMF1", "SMF2", "SMA1", "SMA2", "SS1", "SS2", "PS1", "PS2", "PMA1", "PMA2", "PMF1", "PMF2", "PB1", "PB2"}
setmetatable(vnames, arcSetMt)
arcFns.all = function(self) 
  assert(type(self) == "table", "all must be called as Arc():all()")
  return vnames 
end
local forward = Arc():from(270):to(90)
arcFns.forward = function(self) 
  assert(type(self) == "table", "forward must be called as Arc():forward()")
  return forward 
end
local backward = Arc():from(90):to(270)
arcFns.backward = function(self) 
  assert(type(self) == "table", "backward must be called as Arc():backward()")
  return backward 
end
local port = Arc():from(180):to(0)
arcFns.port = function(self) 
  assert(type(self) == "table", "port must be called as Arc():port()")
  return port 
end
local starboard = Arc():from(0):to(180)
arcFns.starboard = function(self) 
  assert(type(self) == "table", "starboard must be called as Arc():starboard()")
  return starboard 
end
