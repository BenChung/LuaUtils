local function demarshal(value)
	local slen,val = string.match(value,"([0-9]+):(.*)")
	local nlen = tonumber(slen)
	local demarshal_name = string.sub(val,1,nlen)
	local demarshaller = KeyStore.demarshallers[demarshal_name]
                if demarshaller == nil then
                 ScenEdit_SpecialMessage(ScenEdit_PlayerSide(), "Error from " .. demarshal_name)
               end
	return demarshaller(string.sub(val,nlen+1))
end

KeyStore = { 
	keys = {
	}, 
	demarshallers = {
		prim_str = function(strval) return strval end,
		prim_num = function(strval) return tonumber(strval) end,
		prim_nil = function(strval) return nil end,
		prim_bool= function(strval) return strval=="true" end,
		prim_func= function(strval) return nil end,
		prim_tab = function(strval)
			local istr = strval
			local outt = {}
			while istr:len() > 0 do
				local kslen,rval = string.match(istr,"([0-9]+):(.*)")
				local klen = tonumber(kslen)
				local keyStr = string.sub(rval,1,klen)
				local key = demarshal(keyStr)
				local vslen,vval = string.match(string.sub(rval,klen+1),"([0-9]+):(.*)")
				local vlen = tonumber(vslen)
				local value = demarshal(string.sub(vval,1,vlen))
				outt[key] = value
				istr = string.sub(vval,vlen+1)
			end
			return outt
		end
	} 
}

--metatable
local persister = {}

local function contains(t, e)
  for i = 1,#t do
    if t[i] == e then return true end
  end
  return false
end

function persister.__index(table, key)
	local result = ScenEdit_GetKeyValue(key)

	if result == "" then
		return nil
	end

	if (string.sub(result,1,1) == ":") then
		--unmarshalled
		return string.sub(result,2)
	else
		return demarshal(result)
	end
end



function persister.__newindex(_table,key,value)
	function marshal(value)
		local function marshalTable( table )
			-- format: keylen:key .. vallen:value
			local outp = ""
			for key,value in pairs(table) do
				local mk = marshal(key)
				local mv = marshal(value)
				outp = outp .. mk:len() .. ":" .. mk .. mv:len() .. ":" .. mv
			end 
			return outp
		end
		local mt = getmetatable(value)
		local name,marshalled = nil,nil
		if mt == nil or (mt ~= nil and mt.__marshal == nil) then
			if type(value) == "string" then
				name,marshalled = "prim_str",value
			elseif type(value) == "number" then
				name,marshalled = "prim_num",tostring(value)
			elseif type(value) == "nil" then
				name,marshalled = "prim_nil",""
			elseif type(value) == "boolean" then
				name,marshalled = "prim_bool",tostring(value)
			elseif type(value) == "function" then
				name,marshalled = "prim_func","" --TODO
			elseif type(value) == "table" then
				name,marshalled = "prim_tab",marshalTable(value)
			else
				name,marshalled = "prim_str",tostring(value) --default to str
			end
		end

		if mt ~= nil and mt.__marshal ~= nil then
			name,marshalled = mt.__marshal(value)
			name = "mrsh_" .. name
		end
		return string.len(name) .. ":" .. name .. marshalled
	end

	if contains(_table.keys,key) then
		ScenEdit_SetKeyValue(key,marshal(value))
	else
		table.insert(_table.keys, key)
		ScenEdit_SetKeyValue(key,marshal(value))
	end
end

function persister.__call(table, key, demarshaller)
	table.demarshallers["mrsh_" .. key] = demarshaller
end

setmetatable(KeyStore, persister)
