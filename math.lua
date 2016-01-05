Point = {}
Vector = {}
Quaternion = {}

function Point.new(lat, lon)
    if lon == nil then
        if lat == nil then error("invalid latitude " .. debug.traceback()) end
        if lat.type == "Vector" then
            return lat:toPoint()
        elseif lat.latitude ~= nil and lat.longitude ~= nil then
            return Point.new(tonumber(lat.latitude), tonumber(lat.longitude))
        end
    end

    local out = {}
    out.lat = lat
    out.lon = lon
    out.toVector = Point.toVector
    out.tV = Point.toVector
    out.xtk = Point.xtk
    out.toString = Point.toString
    out.type = "Point"
    out.dist = Point.dist
    setmetatable(out, Point)
    return out
end

function Point.toVector(self)
    local phi = math.rad(self.lat)
    local lam = math.rad(self.lon)
    return Vector.new({
        x=math.cos(phi)*math.cos(lam),
        y=math.cos(phi)*math.sin(lam),
        z=math.sin(phi)})
end

function Point.toString( pt )
    return "{".. pt.lat .. ", ".. pt.lon .."}"
end

function Point.__pow(pt, unit)
    unit.latitude = pt.lat
    unit.longitude = pt.lon
    return unit
end

function Point.__div(a, b) -- {dist =, bearing =} from a to b IN RADIANS
    local lat1 = a.lat
    local lon1 = a.lon
    local lat2 = b.lat
    local lon2 = b.lon

    local ph1 = math.rad(lat1)
    local ph2 = math.rad(lat2)
    local la1 = math.rad(lon1)
    local la2 = math.rad(lon2)
    local dph = ph2 - ph1
    local dl = la2 - la1

    local a = math.sin(dph/2) * math.sin(dph/2) +
            math.cos(ph1) * math.cos(ph2) *
            math.sin(dl/2) * math.sin(dl/2)


    local y = math.sin(dl) * math.cos(ph2);
    local x = math.cos(ph1)*math.sin(ph2) -
        math.sin(ph1)*math.cos(ph2)*math.cos(dl);

    return {dist = 2 * math.atan2(math.sqrt(a), math.sqrt(1-a)), bearing = math.atan2(y,x)}
end

function Point.dist(a, b) -- dist from a to b IN RADIANS
    local lat1 = a.lat
    local lon1 = a.lon
    local lat2 = b.lat
    local lon2 = b.lon

    local ph1 = math.rad(lat1)
    local ph2 = math.rad(lat2)
    local la1 = math.rad(lon1)
    local la2 = math.rad(lon2)
    local dph = ph2 - ph1
    local dl = la2 - la1

    local a = math.sin(dph/2) * math.sin(dph/2) +
            math.cos(ph1) * math.cos(ph2) *
            math.sin(dl/2) * math.sin(dl/2)

    return 2 * math.atan2(math.sqrt(a), math.sqrt(1-a))
end

function Point._mul(a, dat)
    local lat = math.asin( math.sin(a.lat)*math.cos(dat.distance/6371) +
                    math.cos(a.lat)*math.sin(dat.distance/6371)*math.cos(dat.heading) );
    local lon = a.lon + math.atan2(math.sin(brng)*math.sin(dat.distance/6371)*math.cos(a.lat),
                         math.cos(dat.distance/6371)-math.sin(a.lat)*math.sin(lat));
    return Point.new(lat, lon)
end

function Point.xtk(x,y,z) -- ANGULAR
    return math.asin(math.sin((x/z).dist) * math.sin((x/z).bearing - (x/y).bearing))
end

function Vector.new(x,y,z)
    if y == nil and z == nil then -- start doing conversions
        if x.type == "Point" then 
            return x:toVector()
        elseif x.type == "Vector" then
            return Vector.new(x.x, x.y, x.z)
        elseif x.x ~= nil and x.y ~= nil and x.z ~= nil then
            return Vector.new(x.x, x.y, x.z)
        end
    end

    local out = {}
    out.x = tonumber(x)
    out.y = tonumber(y)
    out.z = tonumber(z)
    out.type = "Vector"
    out.toPoint = Vector.toPoint
    out.tP = Vector.toPoint
    out.gcTo = Vector.gcTo
    out.norm = Vector.norm
    out.intersect = Vector.intersect
    out.dot = Vector.dot
    out.angle = Vector.angle
    out.length = Vector.length
    setmetatable(out, Vector)
    return out
end

function Point.intersect(a1, a2, b1, b2)
    local a = a1:tV() * a2:tV()
    local b = b1:tV() * b2:tV()

    local a1 = a * a1:tV()
    local a2 = a * a2:tV()
    local b1 = b * b1:tV()
    local b2 = b * b2:tV()

    local axb = (a * b):norm()
    local a1 = axb:dot(a1)
    local a2 = axb:dot(a2)
    local b1 = axb:dot(b1)
    local b2 = axb:dot(b2)

    local eps = 1E-8
    if a1 > -eps and a2 < eps and b1 > -eps and b2 < eps then
        return (axb):tP()
    elseif a1 < eps and a2 > -eps and b1 < eps and b2 > -eps then
        return (-axb):tP()
    end
    return nil
end


function Vector.toPoint(self)
    return Point.new({
        latitude = math.deg(math.atan2(self.z, math.sqrt(self.x*self.x + self.y * self.y))),
        longitude = math.deg(math.atan2(self.y, self.x))
    })
end

function Vector.__mul(a,b)
    return Vector.new({
        x = a.y * b.z - a.z * b.y,
        y = a.z * b.x - a.x * b.z,
        z = a.x * b.y - a.y * b.x
    })
end

function Vector.__add(a,b)
    return Vector.new(a.x + b.x, a.y + b.y, a.z + b.z)
end

function Vector.__div(a,s)
    return Vector.new(a.x / s, a.y / s, a.z / s)
end

function Vector.__unm(v)
    return Vector.new(-v.x, -v.y, -v.z)
end

function Vector.norm(vec)
    return vec/math.sqrt(vec.x*vec.x + vec.y*vec.y + vec.z * vec.z)
end

function Vector.angle(v1, v2)
   return math.acos(v1:dot(v2)/(v1:length() * v2:length()))
end

function Vector.length(v)
    return math.sqrt(v.x * v.x + v.y * v.y + v.z * v.z)
end

function Vector.dot(v1, v2)
  return v1.x * v2.x + v1.y * v2.y + v1.z * v2.z
end

function Quaternion.new(x, y, z, w)
    if x ~= nil and y == nil and z == nil and w == nil then -- start doing conversions
        if x.type == "Point" then 
            return Quaternion.fromLatLon(x.lat, x.lon)
        elseif x.type == "Vector" then
            return Quaternion.fromEuler(x.x, x.y, x.z)
        elseif x.type == "Quaternion" then
            return Quaternion.new(x.x, x.y, x.z, x.w)
        end
    end

    local q = { x = x or 0, y = y or 0, z = z or 0, w = w or 1 }
 
    local metatab = {}
    setmetatable( q, metatab )
    metatab.__add = Quaternion.add
    metatab.__sub = Quaternion.sub
    metatab.__unm = Quaternion.unm
    metatab.__mul = Quaternion.mul
    q.toLatLon = Quaternion.toLatLon
    q.dot = Quaternion.dot
    q.toPoint = Quaternion.toPoint
    q.conj = Quaternion.conj
    q.norm = Quaternion.norm
    q.dot = Quaternion.dot
    q.type = "Quaternion"
    return q
end

function Quaternion.fromLatLon(lat,lon)
    local lat = math.rad(lat)
    local lon = math.rad(lon)
    
    local clat = math.cos(lat/2);
    local clon = math.cos(lon/2);
    local slat = math.sin(lat/2);
    local slon = math.sin(lon/2);

    local qw = clat * clon;
    local qx = clat * slon;
    local qy = slat * clon;
    local qz = 0.0 - slat * slon;

    return Quaternion.new(qx, qy, qz, qw);
end

function Quaternion.fromEuler(x,y,z)
    local cx = math.cos(x/2);
    local cy = math.cos(y/2);
    local cz = math.cos(z/2);
    local sx = math.sin(x/2);
    local sy = math.sin(y/2);
    local sz = math.sin(z/2);

    local qw = (cx * cy * cz) + (sx * sy * sz);
    local qx = (sx * cy * cz) - (cx * sy * sz);
    local qy = (cx * sy * cz) + (sx * cy * sz);
    local qz = (cx * cy * sz) - (sx * sy * cz);

    return Quaternion.new(qx, qy, qz, qw);
end

function Quaternion.fromPos(table)
    return Quaternion.fromLatLon(table.latitude, table.longitude)
end

function Quaternion.add( p, q )
    if type( p ) == "number" then
    return Quaternion.new( q.x, q.y, q.z, q.w+p )
    elseif type( q ) == "number" then
    return Quaternion.new( p.x, p.y, p.z, p.w + q )
    else
    return Quaternion.new( p.x+q.x, p.y+q.y, p.z+q.z, p.w+q.w )
    end
end
 
function Quaternion.sub( p, q )
    if type( p ) == "number" then
    return Quaternion.new( q.x, q.y, q.z, p-q.w )
    elseif type( q ) == "number" then
    return Quaternion.new( p.x, p.y, p.z, p.w-p )
    else
    return Quaternion.new( p.x-q.x, p.y-q.y, p.z-q.z, p.w-q.w )
    end
end
 
function Quaternion.unm( p )
    return Quaternion.new( -p.x, -p.y, -p.z, -p.w )
end
 
function Quaternion.mul( p, q )
    if type( p ) == "number" then
    return Quaternion.new( p*q.x, p*q.y, p*q.z, p*q.w )
    elseif type( q ) == "number" then
    return Quaternion.new( p.x*q, p.y*q, p.z*q, p.w*q )
    else
    return Quaternion.new((p.w * q.x) + (p.x * q.w) + (p.y * q.z) - (p.z * q.y),
                            (p.w * q.y) + (p.y * q.w) + (p.z * q.x) - (p.x * q.z),
                            (p.w * q.z) + (p.z * q.w) + (p.x * q.y) - (p.y * q.x),
                            (p.w * q.w) - (p.x * q.x) - (p.y * q.y) - (p.z * q.z))
    end
end
 
function Quaternion.conj( p )
    return Quaternion.new( -p.x, -p.y, -p.z, p.w )
end
 
function Quaternion.norm( p )
    return math.sqrt( p.x^2 + p.y^2 + p.z^2 + p.w^2 )
end

function Quaternion.dot( p, q )
    return p.x * q.x + p.y * q.y + p.z * q.z + p.w * q.w 
end

function Quaternion.toLatLon( q1 )  
    local latRadians = math.asin((2.0 * q1.y * q1.w) - (2.0 * q1.x * q1.z));
    local lonRadians = math.atan2((2.0 * q1.y * q1.z) + (2.0 * q1.x * q1.w),
                                   (q1.w * q1.w) - (q1.x * q1.x) - (q1.y * q1.y) + (q1.z * q1.z));
    return {math.deg(latRadians), math.deg(lonRadians)}
end

function Quaternion.toPoint( q )
    local ll = q:toLatLon()
    return Point.new({latitude = ll[1], longitude = ll[2]})
end
 
function Quaternion.print( p )
    print( string.format( "w:%f + x:%f + y:%f + z:%f\n", p.w, p.x, p.y, p.z) )
end

function Quaternion.slerp(amount, value1, value2)
    if (amount < 0.0) then
        return value1;
    elseif (amount > 1.0) then
        return value2;
    end

    local dot = value1:dot(value2);
    local x2 = 0
    local y2 = 0
    local z2 = 0
    local w2 = 0
    if (dot < 0.0) then
        dot = 0.0 - dot;
        x2 = 0.0 - value2.x;
        y2 = 0.0 - value2.y;
        z2 = 0.0 - value2.z;
        w2 = 0.0 - value2.w;
    else
        x2 = value2.x;
        y2 = value2.y;
        z2 = value2.z;
        w2 = value2.w;
    end

    local t1
    local t2

    local EPSILON = 0.0001;
    if ((1.0 - dot) > EPSILON) then
        local angle = math.acos(dot);
        local sinAngle = math.sin(angle);
        t1 = math.sin((1.0 - amount) * angle) / sinAngle;
        t2 = math.sin(amount * angle) / sinAngle;
    else
        t1 = 1.0 - amount;
        t2 = amount;
    end

    return Quaternion.new(
        (value1.x * t1) + (x2 * t2),
        (value1.y * t1) + (y2 * t2),
        (value1.z * t1) + (z2 * t2),
        (value1.w * t1) + (w2 * t2));
end

local last = os.time()

function rand()
  last = (1664525*last + 1013904223) % 4294967296
  return last
end

Polygon = {}

function Polygon.triangulate(poly) -- assume poly is {point, point, ...} in clockwise order
	function findEar(poly)
		--find all concave vertices
		local last1c = poly[#poly]
		local last2c = poly[#poly-1]

		local concave = {}
		for _,v in pairs(poly) do
			if Point.xtk(last2c,v,last1c) > 0 and tri == nil then --concave
				table.insert(concave, last1c)
			end
			last2c = last1c
			last1c = v
		end


		local last1 = poly[#poly]
		local last2 = poly[#poly-1]

		local lst = {}
		local tri = nil
		for _,v in pairs(poly) do
			if Point.xtk(last2,v,last1) < 0 and tri == nil then --convex
				local e = poly[#poly]

				local ear = true
				for _,con in ipairs(concave) do
					if Point.xtk(last2,v,con) < 0 then 
						ear = false 
						break 
					end
				end
				if ear then 
					tri = {last2,last1,v}
				else
					table.insert(lst, last1)
				end
			else
				table.insert(lst, last1)
			end
			last2 = last1
			last1 = v
		end
		return tri, lst
	end

	local iter = poly
	local tris = {}
	while #iter > 3 do
		local tri, ilst = findEar(iter)
		iter = ilst
		table.insert(tris, tri)
	end
	table.insert(tris, iter)
	return tris
end

function Polygon.area(tri) -- angular area
	local a = (tri[1]:tV()*tri[2]:tV()):angle(tri[1]:tV()*tri[3]:tV())
	local b = (tri[2]:tV()*tri[1]:tV()):angle(tri[2]:tV()*tri[3]:tV())
	local c = (tri[3]:tV()*tri[1]:tV()):angle(tri[3]:tV()*tri[2]:tV())
	return a + b + c - math.pi
end

function Polygon.random(rf,tris) -- rf() between 0 and 1
	function wrand( inp ) -- {{weight,value}}
		local total = 0
		for _,v in pairs(inp) do
			total = total + v[1]
		end
		local sel = rf() * total
		total = 0
		for _,v in pairs(inp) do
			total = total + v[1]
			if total > sel then return v[2] end
		end
	end
	local wtris = {}
	for _,v in pairs(tris) do
		table.insert(wtris, {Polygon.area(v), v})
	end
	local tri = wrand(wtris)

	-- we know the triangle, now we just need to compute a random point in it
	-- compute two basis quaternions, weight them, then apply them
	local c = Quaternion.new(tri[1]):conj()

	local b1 = Quaternion.new(tri[2]) * c
	local b2 = Quaternion.new(tri[3]) * c
	local id = Quaternion.new()

	-- now compute two new random numbers and normalize the vector
	local a = rf()
	local b = rf()
	if a+b > 1 then
		a = 1-a
		b = 1-b
	end

	-- compute triangle point
	return (Quaternion.slerp(a,id,b1) * Quaternion.slerp(b,id,b2) * c:conj()):toPoint()
end

function Polygon.inside( poly, point )
	if #poly < 3 then return false end
	-- determine vector from 2nd point of poly to point
	local a = poly[2]:toVector() * (point:toVector())
	local l1 = poly[2]:toVector() * (poly[1]:toVector())
	local l2 = poly[2]:toVector() * (poly[3]:toVector())

	local intersections = 0
	local last = poly[#poly]
	for i,nxt in pairs(poly) do
		if i ~= 2 and i ~= 3 then
			if Point.intersect(poly[2], point, last, nxt) then 
				intersections = intersections + 1 end
		end
		last = nxt
	end

	local angle = l1:angle(l2)
	local desired = 0
	if l1:dot(poly[3]:toVector()) > 0 then -- small angle is the desired
		print("small")
		if l1:angle(a) <= angle or l2:angle(a) <= angle then -- point inside
			desired = 0
		else
			desired = 1
		end
	else -- large angle is the desired
		local sum = l1:angle(a) + l2:angle(a)
		if angle - 0.0001 < sum and sum < angle + 0.0001 then -- point inside
			print("in")
			desired = 1
		else
			desired = 0
		end
	end

	return intersections % 2 == desired
end

