SceneManager = { units = {}, maxDist = 0, watchers = {} }

local function persist_manager()
 local outp = {}
 for guid,_ in pairs(SceneManager.units) do
  table.insert(outp, guid)
 end
 KeyStore.ScenManager = {units = outp}
end

function SceneManager.restore(manager)
 local unitList = {}
 local restored = KeyStore.ScenManager
 if restored == nil then return end
 for _,v in pairs(restored.units) do
  local unit = ScenEdit_GetUnit({GUID=v})
  if unit ~= nil then unitList[v] = unit end
 end
 manager.units = unitList
end

function SceneManager.register(manager, unit)
 if unit == nil then return end
 manager.units[unit.guid] = unit
 persist_manager()
end

function SceneManager.watch(manager, distance, fn)
  if distance > manager.maxDist then manager.maxDist = distance end
  table.insert(manager.watchers, {fn,distance})
end

function SceneManager.tick(manager)
 local unitPos = {}

 local toRemove = {}
 for k,_ in pairs(manager.units) do
 	if ScenEdit_GetUnit({GUID=k}) == nil then table.insert(toRemove, k) end
 end
 for _,v in pairs(toRemove) do manager.units[v] = nil end
 persist_manager()

 for _,u in pairs(manager.units) do
  table.insert(unitPos, {u,Point.new(u)})
  if u.behaviour ~= nil and u.behaviour.update ~= nil then
    u.behaviour.update(u)
  end
 end

 function handle_approach(u1, u2, distance)
    local u1 =  u1[1]
    local u2 =  u2[1]
    if u1.behaviour == nil then return end
    if u1.behaviour.approach_handlers ~= nil then
      local handlers = u1.behaviour.approach_handlers[u2.side]
      if handlers ~= nil then
        for dist,handler in pairs(handlers) do
          if distance < dist then
            handler(u1, u2)
          end
        end
      end
    end
  end

 for i=1,#unitPos do
  for j=(i+1),#unitPos do
   local u1 = unitPos[i]
   local u2 = unitPos[j]
   if u1 ~= u2 then
    local distance = ((u1)[2]:dist(u2[2])) * 6387.1
    handle_approach(u1, u2, distance)
    handle_approach(u2, u1, distance)
   end
  end
 end
end

function SceneManager.clear(manager)
	manager.units = {}
	persist_manager()
end

function SceneManager.status(manager)
	local count = 0
	for _ in pairs(manager.units) do count = count + 1 end
	print("Manager watching "..(count).." units")
end

FSM = { machines = {} }

FSM_meta = {}

--transition_table is of the form
--state_name = {action, {event1=state1, ...}}
function FSM.new(name, initial, transition_table)
	local out = {}
	out.name = name
	out.table = transition_table
	out.state = initial
	out.observers = {}
	function out.set(fsm, newstate)
		fsm.state = newstate -- no action
		return fsm
	end
	function out.fire(fsm, name, meta)
		print("transitioning to " .. name)
		local newname = fsm.table[fsm.state][2][name]
		local ns = fsm.table[newname]
		if (ns == nil) then
			print("Invalid transition: " .. name)
			print("Current state: " .. fsm.state)
			print(debug.traceback())
		end
		local call = {}
		call[1] = fsm
		for i,v in ipairs(meta) do
			call[i+1] = v
		end
		ns[1](table.unpack(call))
		fsm.state = newname
		for _,v in pairs(fsm.observers) do
			v(fsm)
		end
	end
	function out.observe(fsm, observer)
		table.insert(fsm.observers, observer)
	end
	FSM.machines[name] = out
	out.clone = FSM.clone
	setmetatable(out, FSM_meta)
	return out
end

function FSM:clone()
	local out = {}
	out.name = self.name
	out.table = self.table
	out.state = self.state
	out.observers = {}
	out.set = self.set
	out.fire = self.fire
	out.observe = self.observe
	out.clone = self.clone
	setmetatable(out, FSM_meta)
	return out
end

function FSM_meta.__marshal(machine)
	return "FSM",machine.name .. ":" .. machine.state
end

function KeyStore.demarshallers.mrsh_FSM(stored)
	local name,state = string.match(stored,"(.*):(.*)")
	print("Restoring " .. name)
	return FSM.machines[name]:clone():set(state)
end

TimerEvents = { events = {} }

function TimerEvents:register(delay, fun)
	self.events[ScenEdit_CurrentTime() + delay] = fun
	KeyStore.TimerEvents = self.events
end

function TimerEvents:restore()
	self.events = KeyStore.TimerEvents or {}
end

function TimerEvents:tick()
	local toRemove = {}
	for t,fn in pairs(self.events) do
		if t < ScenEdit_CurrentTime() then
			table.insert(toRemove, t)
			fn()
		end
	end	
	for _,v in pairs(toRemove) do
		self.events[v] = nil
	end
end

FnManager = { functions = {}, closures = {}, gen = 0}

function FnManager:register(name, fun)
	self.functions[name] = fun
end

local fnMt = {}

function fnMt.__call(self, ...)
	local fn = FnManager.functions[self.fnName]
	local closure = FnManager.closures[self.iid]
	local call = {}
	for i,v in ipairs(closure) do
		call[i] = v
	end

	return fn(table.unpack(closure), ...)
end

function fnMt.__marshal(self)
	return "fnFunc",self.iid..":"..self.fnName
end

function KeyStore.demarshallers.mrsh_fnFunc(data)
	local out = {}
	out.fnName, out.iid = string.match(data, "(.*):(.*)")
	out.iid = tonumber(out.iid)
	setmetatable(out, fnMt)
	return out
end

function FnManager:make(name, argument)
	local iid = self.gen
	self.gen = self.gen + 1
	local out = {}
	out.fnName = name
	out.iid = iid
	self.closures[iid] = argument
	setmetatable(out, fnMt)
	KeyStore.FnManager = {closures = self.closures, gen = self.gen}
	return out
end

function FnManager:restore()
	local persisted = KeyStore.FnManager
	if persisted == nil then return end
	self.closures = persisted.closures
	self.gen = persisted.gen
end

Units = { assoc = {} }

local dummy = ScenEdit_AddUnit({type="Ship",name="Dummy",dbid=2553,side="PlayerSide",latitude=0,longitude=0})
local unitmt = getmetatable(dummy)
ScenEdit_DeleteUnit({guid=dummy.guid})

function Units.init()
	local known = KeyStore.Units
	for _,v in pairs(known) do
		local value = KeyStore["Unit_" .. v]
		for property,iv in pairs(value) do
			if type(iv) == "table" and iv.observe ~= nil then iv:observe(function (nv) setValue(unit, property, nv) end) end
		end
		Units.assoc[v] = value
	end
end

local function persist(unit)
	local known = {}
	for k,_ in pairs(Units.assoc) do
		table.insert(known, k)
	end
	KeyStore.Units = known

	KeyStore["Unit_" .. unit] = Units.assoc[unit]
end

local oldIndex = unitmt.__index
function unitmt.__index(unit, property)
	local old = oldIndex(unit, property)
	if old ~= nil and old ~= property then return old end
	local prop = Units.assoc[unit.guid] or {}
	return prop[property]
end

local oldSetValue = unitmt.__newindex
local function setValue(unit, property, value)
	if not pcall(function() oldSetValue(unit, property, value) end) then
		local prop = Units.assoc[unit.guid] or {}
		prop[property] = value
		Units.assoc[unit.guid] = prop
		persist(unit.guid)
	end
end

function unitmt.__newindex(unit, property, value)
	setValue(unit, property, value)
	if type(value) ~= "table" then return end
	if value.observe ~= nil then value:observe(function (nv) setValue(unit, property, nv) end) end
end

Behaviours = { behaviours = {} }

function Behaviours:init()
end

local behmt = {}

function behmt.__marshal(behaviour)
	return "behaviour", behaviour.name
end 

function KeyStore.demarshallers.mrsh_behaviour(strval)
	return Behaviours.behaviours[strval]
end

function Behaviours:behaviour(obj)
	setmetatable(obj, behmt)
	self.behaviours[obj.name] = obj
	return obj
end

local function explode(d,p)
  local t, ll
  t={}
  ll=0
  if(#p == 1) then return {p} end
    while true do
      l=string.find(p,d,ll,true) -- find the next d in the string
      if l~=nil then -- if "not not" found then..
        table.insert(t, string.sub(p,ll,l-1)) -- Save it in our array.
        ll=l+1 -- save just after where we found it for searching next time.
      else
        table.insert(t, string.sub(p,ll)) -- Save what's left in our array.
        break -- Break at end, as it should be, according to the lua manual.
      end
    end
  return t
end

local function compose(beh1, beh2) 
	if beh1 == nil then return beh2 end
	if beh2 == nil then return beh1 end

	local outname = beh1.name .. "|" .. beh2.name
	local outapproach = {}
	for k,v in pairs(beh1.approach_handlers) do
		if beh2.approach_handlers[k] == nil then
			outapproach[k] = v
		else
			outapproach[k] = function(self, other)
				v(self, other)
				if ScenEdit_GetUnit({guid=other.guid}) == nil then return end
				beh2[k](self, other)
			end
		end
	end
	for k,v in pairs(beh2.approach_handlers) do
		if beh1.approach_handlers[k] == nil then outapproach[k] = v end
	end
	return {name = outname, approach_handlers = outapproach}
end

local compbh = {}

function compbh.__marshal(behaviour)
	return "comp_behaviour", behaviour.name
end 

function KeyStore.demarshallers.mrsh_comp_behaviour(strval)
	local initb = nil
	for _,v in pairs(explode(strval)) do
		initb = compose(initb, Behaviours.behaviours[v])
	end
	return initb
end

function Behaviours:composite(beh1, beh2)
	local out = compose(beh1, beh2)
	setmetatable(out, compbh)
	return out
end
