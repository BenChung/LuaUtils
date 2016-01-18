local status,err = pcall(function()
SceneManager:tick()
TimerEvents:tick()

local prob = .001
for _,boat in pairs(KeyStore.NK_boats) do
 if math.random() < prob then 
  local fsm = ScenEdit_GetUnit({GUID=boat}).transgressor
  if fsm == nil then
   fsm = transgressor_FSM:clone()
   ScenEdit_GetUnit({GUID=boat}).transgressor = fsm
  end
  if fsm.state == "initial" then
   ScenEdit_AssignUnitToMission(boat, "Illegal Fishing") 
   ScenEdit_GetUnit({GUID=boat}).transgressor:fire("transgressing", {boat})
  end
 end
end

local accident_probability = .001
if rng() < accident_probability then
  cause_accident()
end

end)

if not status then print("encountered error: " .. err) end