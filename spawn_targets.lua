local function rpget(num) return Point.new(ScenEdit_GetReferencePoint({side="PLAN", name="RP-".. num})) end

local rps = {2713, 2714, 2715, 2712}
for k,v in ipairs(rps) do
  rps[k] = rpget(v)
end

local tris = Polygon.triangulate(rps)

local function getpt() return Polygon.random(math.random,tris) end

for i=1,4 do
  local unit = ScenEdit_AddUnit(getpt() ^{type="ship", dbid=1474, side="Target", name="Target #"..i, autodetectable="true"})
  unit.behaviour = gunnery_target_behaviour
  unit.destroyed_score = 1
end

ScemEdit_SpecialMessage("PLAN", "The gunnery targets have been deployed. To best demonstrate your ships capabilities, destroy them as quickly as possible.")