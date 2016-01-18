require('mobdebug').on()
local traceback = ""
local status, err = xpcall(function() 
SceneManager:restore() -- restore the scene data from the store
TimerEvents:restore()
FnManager:restore()

FnManager:register("boardingDone", function (unit_id)
	ScenEdit_GetUnit({guid=unit_id}).transgressor:fire("done", {unit_id})
end)

FnManager:register("capture", function (unit_id)
	local unit = ScenEdit_GetUnit({guid=unit_id})
	ScenEdit_SetUnitSide({side=unit.side, name = unit.name, newside = "PLAN"})
	unit.transgressor:fire("captured", {unit_id})
end)

transgressor_FSM = FSM.new("transgressor", "initial", {
	initial={function () end, {transgressing="invader"}},
	invader={function (fsm, unit_id) ScenEdit_AssignUnitToMission(unit_id, "Illegal Fishing")  end, {intercepted = "boarding"}},
	boarding={function (fsm, unit_id) 
		local unit = ScenEdit_GetUnit({guid=unit_id})
		if unit.transgressions == nil then
			unit.transgressions = 0
		end
		unit.transgressions = unit.transgressions + 1
		ScenEdit_SpecialMessage(ScenEdit_PlayerSide(), communicating_message)
		TimerEvents:register(5*60, FnManager:make("boardingDone", {unit_id}))
	end, {done = "obeying", captured="captured"}},
	obeying={function (fsm, unit_id) 
		print("Obeying")
		ScenEdit_SpecialMessage(ScenEdit_PlayerSide(), returning_message)
		ScenEdit_AssignUnitToMission(unit_id, "Legal Fishing") 
	end, {home = "initial"}},
	captured={function () end, {}} -- absorbing
})


local function inside(unit, RPs) -- RPs in clockwise order
	local pts = {}
	for i,v in ipairs(RPs) do
	 pts[i] = Point.new(ScenEdit_GetReferencePoint({side="LuaLogic", name=v}))
	end
	return Polygon.inside(pts, Point.new(unit))
end

fisheries_behaviour = Behaviours:behaviour({
	name = "fisheries_patrol",
	approach_handlers = {
		["NK Fisheries"] = {
			[.5] = function (self, other)
				local fsm = other.transgressor
				local NKEEZ = {"RP-2561", "RP-2419", "RP-2418", "RP-2417", "RP-2416", "RP-2415", "RP-2564", "RP-2563", "RP-2562"}
				if fsm ~= nil and fsm.state == "invader" and not inside(other, NKEEZ) then
					fsm:fire("intercepted", {other.guid})
				elseif inside(self, NKEEZ) then
					ScenEdit_SpecialMessage(ScenEdit_PlayerSide(), inside_NK_EEZ)
				end
			end
		}
	}
})

gunnery_target_behaviour = Behaviours:behaviour({
  name = "gunnery_target_behaviour",
  destroyed_handler = function (self)
    local oldscore = ScenEdit_GetScore("PLAN")
    ScenEdit_SetScore("PLAN", oldscore + self.destroyed_score, "Destroyed target " .. self.name)
    if KeyStore.GunneryTargetsDestroyed == nil then KeyStore.GunneryTargetsDestroyed = 0 end
    KeyStore.GunneryTargetsDestroyed = KeyStore.GunneryTargetsDestroyed + 1
  end
})


-- must go at end
Units.init()
end, function () traceback = debug.traceback() end)

if not status then
 ScenEdit_SpecialMessage(ScenEdit_PlayerSide(), "Error at " ..traceback:gsub("\n", "<br>"))
end

local state = os.time()
local mod = math.pow(2,32)
function rng()
 state = (state * 1664525 + 1013904223)%mod
 return state/mod
end

-- aircraft accidents
local pts = {2620, 2621, 2622, 2623, 2624, 2600,2601, 2602, 2603,2604,2605, 2606, 2607, 2608, 2609, 2610, 2611, 2612, 2613, 2614, 2615, 2616, 2617, 2618, 2619}
local area = {}
for k,v in ipairs(pts) do
	area[k] = Point.new(ScenEdit_GetReferencePoint({side="LuaLogic", name="RP-"..v}))
end

local function point_in_AOE()
	return Polygon.random(rng, Polygon.triangulate(area))
end

local function circle_around(side, point, error, radius, number, naming)
	local center = (Quaternion.fromEuler(rng()*error,0,0)*Quaternion.fromEuler(0,0,rng() * 2 * math.pi)) * Quaternion.new(point)
	-- debug, real center ScenEdit_AddReferencePoint(point ^ {side=side, name = naming(0)})
	local angle = Quaternion.fromEuler(radius,0,0)
	local rps = {}
	for i=1,number do
		rp = ScenEdit_AddReferencePoint((angle * center):toPoint() ^ {side=side, name = naming(i)})
		angle = angle * Quaternion.fromEuler(0,0,2*math.pi/number)
		table.insert(rps, rp.guid)
	end
	return rps
end

function make_AOU()
	local angular_size = 5/6371
	local aou_size = #(KeyStore.AOU)
	local center = point_in_AOE()
	local circle = circle_around("PLAN", center, angular_size, angular_size, 8, 
		function(num) return "Search zone " .. (aou_size + 1) .. " RP " .. num end)
	return center, circle
end

false_alarm_cleared_fn = FnManager:register("false_alarm_cleared", function (rps)
	ScenEdit_SpecialMessage("PLAN", false_alarm_cleared)
	for _,v in pairs(rps) do
		ScenEdit_DeleteReferencePoint({side="PLAN", guid = v}) -- clear the RPs that define the AOU
	end
end)

-- You did something wrong checks

light_aircraft_too_long = FnManager:register("light_aircraft_survivors_missed", function (rps, wreckage_guid, raft_guid)
	for _,v in pairs(rps) do
		ScenEdit_DeleteReferencePoint({side="PLAN", guid = v}) -- clear the RPs that define the AOU
	end

	if raft_guid == nil and ScenEdit_GetUnit({guid=wreckage_guid}) ~= nil then
		SceneEdit_SetScore("PLAN", ScenEdit_GetScore("PLAN") + missed_aircraft, "Missed aircraft wreckage")
		ScenEdit_SpecialMessage("PLAN", light_aircraft_survivors_missed)
		ScenEdit_DeleteUnit({guid=wreckage_guid})
		return
	end

	if raft_guid ~= nil and ScenEdit_GetUnit({guid=raft_guid}) ~= nil and ScenEdit_GetUnit({guid=wreckage_guid}) == nil then
		SceneEdit_SetScore("PLAN", ScenEdit_GetScore("PLAN") + missed_aircraft*2, "Missed known survivors")
		ScenEdit_SpecialMessage("PLAN", light_aircraft_known_survivors_missed)
		ScenEdit_DeleteUnit({guid=raft_guid})
		return
	end

	if raft_guid ~= nil and ScenEdit_GetUnit({guid=raft_guid}) ~= nil and ScenEdit_GetUnit({guid=wreckage_guid}) ~= nil then
		SceneEdit_SetScore("PLAN", ScenEdit_GetScore("PLAN") + missed_aircraft, "Missed known survivors")
		ScenEdit_SpecialMessage("PLAN", light_aircraft_survivors_missed)
		ScenEdit_DeleteUnit({guid=raft_guid})
		ScenEdit_DeleteUnit({guid=wreckage_guid})
		return
	end
end
)

airliner_wreckage_missed = FnManager:register("airliner_wreckage_missed", function (rps, wreckage_guid, raft_list)
	for _,v in pairs(rps) do
		ScenEdit_DeleteReferencePoint({side="PLAN", guid = v}) -- clear the RPs that define the AOU
	end

	if raft_guid == nil and ScenEdit_GetUnit({guid=wreckage_guid}) ~= nil then
		SceneEdit_SetScore("PLAN", ScenEdit_GetScore("PLAN") + missed_aircraft, "Missed aircraft wreckage")
		ScenEdit_SpecialMessage("PLAN", airliner_wreckage_missed)
		ScenEdit_DeleteUnit({guid=wreckage_guid})
		return
	end

	local missed = 0
	for _,raft_guid in pairs(raft_list) do
		if ScenEdit_GetUnit({guid=raft_guid}) ~= nil then
			missed = missed + 1
			ScenEdit_DeleteUnit({guid=raft_guid})
		end
	end

	if raft_list ~= nil and ScenEdit_GetUnit({guid=wreckage_guid}) == nil and missed > 0 then
		SceneEdit_SetScore("PLAN", ScenEdit_GetScore("PLAN") + missed_aircraft*2*missed, "Missed known survivors")
		ScenEdit_SpecialMessage("PLAN", airliner_wreckage_missed .. "<br/>Missing " .. missed .. " rafts.")
		return
	end

	if raft_list ~= nil and ScenEdit_GetUnit({guid=wreckage_guid}) ~= nil and missed == 0 then
		SceneEdit_SetScore("PLAN", ScenEdit_GetScore("PLAN") + missed_aircraft, "Missed wreckage")
		ScenEdit_SpecialMessage("PLAN", airliner_everything_missed)
		ScenEdit_DeleteUnit({guid=wreckage_guid})
		return
	end
end)

-- Rescue behaviour

local function message_with_pts(message, pts, reason)
  ScenEdit_SpecialMessage(message)
  ScenEdit_SetScore("PLAN", ScenEdit_GetScore("PLAN") + pts, "reason") 
end

local wreckage = 5
local survivors = 10

rescue_behaviour = Behaviours:behaviour({
	name = "rescue_behaviour",
	approach_handlers = {
		["Wreckage"] = {
			[.2] = function (self, other)
				if other.type == "light aircraft" then
					if other.kind == "wreckage" then
            message_with_pts(light_aircraft_wreckage_found, wreckage, "Picked up light aircraft wreckage")
					elseif other.kind == "raft" then
            message_with_pts(light_aircraft_survivors_rescued, survivors, "Picked up light aircraft survivors")
					end
				elseif other.type == "airliner" then
					if other.kind == "wreckage" then
            message_with_pts(airliner_wreckage_found, wreckage, "Picked up light aircraft wreckage")
					elseif other.kind == "raft" then
            message_with_pts(airliner_survivors_found, survivors, "Picked up airliner survivors")
					end
				end
			end
		}
	}
})

local accident_types = {
	{50, {type = "false_alarm", action = function () 
		ScenEdit_SpecialMessage("PLAN", false_alarm_message)
		local center, circle = make_AOU()
		TimerEvents:register(5*60, FnManager:make("false_alarm_cleared", {circle})) -- 1 hour to clear
	end}}, -- comments
	{10, {type = "light_down", action = function ()
		ScenEdit_SpecialMessage("PLAN", light_aircraft_down_message)
		local center, circle = make_AOU()
		
		local wreckage = ScenEdit_AddUnit(center ^ {
			name = "Light Aircraft Wreckage",
			type = "ship",
			dbid = 347,
			side = "Wreckage"
		})
		SceneManager:register(wreckage)
		TimerEvents:register(5*60, FnManager:make("light_aircraft_survivors_missed", {circle, wreckage.guid})) -- 1 hour to clear
	end}},
	{10, {type = "light_down", action = function ()
		ScenEdit_SpecialMessage("PLAN", light_aircraft_down_message)
		local center, circle = make_AOU()
		
		local raft = ScenEdit_AddUnit(center ^ {
			name = "Lifeboat",
			type = "ship",
			dbid = 2553,
			side = "Wreckage"
		})
		local drift = 100/6371
		local course = ((Quaternion.fromEuler(rng()*drift,0,0)*Quaternion.fromEuler(0,0,rng() * 2 * math.pi)) * Quaternion.new(center)):toPoint()
		raft.course = {course ^ {}}
		raft.type = "light aircraft"
		raft.kind = "raft"
		SceneManager:register(raft)

		local wreckage = ScenEdit_AddUnit(center ^ {
			name = "Light Aircraft Wreckage",
			type = "ship",
			dbid = 347,
			side = "Wreckage"
		})
		wreckage.type = "airliner"
		wreckage.kind = "wreckage"
		SceneManager:register(wreckage)
		TimerEvents:register(5*60, FnManager:make("light_aircraft_survivors_missed", {circle, wreckage.guid, raft.guid})) -- 1 hour to clear
	end}},
	{5, {type = "airliner_down", action = function () 
			ScenEdit_SpecialMessage("PLAN", airliner_down_message)
			local center, circle = make_AOU()
			local wreckage = ScenEdit_AddUnit(center ^ {
				name = "Wreckage",
				type = "ship",
				dbid = 347,
				side = "Wreckage"
			})
			wreckage.type = "airliner"
			wreckage.kind = "wreckage"
			SceneManager:register(wreckage)
			TimerEvents:register(5*60, FnManager:make("airliner_wreckage_missed", {circle, wreckage.guid})) -- 1 hour to clear
		end}},
	{1, {type = "airliner_down_survivors", action = function ()
			ScenEdit_SpecialMessage("PLAN", airliner_down_message)
			local center, circle = make_AOU()
			local wreckage = ScenEdit_AddUnit(center ^ {
				name = "Wreckage",
				type = "ship",
				dbid = 347,
				side = "Wreckage"
			})
			wreckage.type = "airliner"
			wreckage.kind = "wreckage"
			SceneManager:register(wreckage)

			rafts = {}
			for i=1,math.random(2,6) do
				local raft = ScenEdit_AddUnit(center ^ {
					name = "Lifeboat",
					type = "ship",
					dbid = 2553,
					side = "Wreckage"
				})
				local drift = 100/6371
				local course = ((Quaternion.fromEuler(rng()*drift,0,0)*Quaternion.fromEuler(0,0,rng() * 2 * math.pi)) * Quaternion.new(center)):toPoint()
				raft.course = {course ^ {}}
				raft.type = "airliner"
				raft.kind = "raft"
				SceneManager:register(raft)
				table.insert(rafts, raft.guid)
			end

			TimerEvents:register(5*60, FnManager:make("airliner_wreckage_missed", {circle, wreckage.guid, rafts})) -- 1 hour to clear
		end}},
}


function cause_accident(eventIndex)  -- cause an accident in the scenario
	local function wrand( inp ) -- {{weight,value}}
		local total = 0
		for _,v in pairs(inp) do
			total = total + v[1]
		end
		local sel = rng() * total
		total = 0
		for _,v in pairs(inp) do
			total = total + v[1]
			if total > sel then return v[2] end
		end
	end
  test(eventIndex)

	local event = 0
	if eventIndex == nil then
		event = wrand(accident_types)
	else
		event = accident_types[eventIndex][2]
	end
	event.action() -- more clever handling later?
	print("Encountered event " .. event.type)
end