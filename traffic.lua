-- ======================================================================
-- Copyright (c) 2012 RapidFire Studio Limited 
-- All Rights Reserved. 
-- http://www.rapidfirestudio.com

-- Permission is hereby granted, free of charge, to any person obtaining
-- a copy of this software and associated documentation files (the
-- "Software"), to deal in the Software without restriction, including
-- without limitation the rights to use, copy, modify, merge, publish,
-- distribute, sublicense, and/or sell copies of the Software, and to
-- permit persons to whom the Software is furnished to do so, subject to
-- the following conditions:

-- The above copyright notice and this permission notice shall be
-- included in all copies or substantial portions of the Software.

-- THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
-- EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
-- MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
-- IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
-- CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
-- TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
-- SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
-- ======================================================================

function a_star ( start, goal, neighbors, dist, he )
  function lowest_f_score ( set, f_score )
    local lowest = 1/0
    local bestNode = nil
    for _, node in ipairs ( set ) do
      local score = f_score [ node ]
      if score < lowest then
        lowest, bestNode = score, node
      end
    end
    return bestNode
  end

  function unwind_path ( flat_path, map, current_node )
    if map [ current_node ] then
      table.insert ( flat_path, 1, map [ current_node ] ) 
      return unwind_path ( flat_path, map, map [ current_node ] )
    else
      return flat_path
    end
  end
  function remove_node ( set, theNode )

    for i, node in ipairs ( set ) do
      if node == theNode then 
        set [ i ] = set [ #set ]
        set [ #set ] = nil
        break
      end
    end	
  end


  function not_in ( set, theNode )
    for _, node in ipairs ( set ) do
      if node == theNode then return false end
    end
    return true
  end
  
	local closedset = {}
	local openset = { start }
	local came_from = {}

	local g_score, f_score = {}, {}
	g_score [ start ] = 0
	f_score [ start ] = g_score [ start ] + he ( start, goal )

	while #openset > 0 do
	
		local current = lowest_f_score ( openset, f_score )
		if current == goal then
			local path = unwind_path ( {}, came_from, goal )
			table.insert ( path, goal )
			return path
		end

		remove_node ( openset, current )		
		table.insert ( closedset, current )
		
		local neighbors = neighbors ( current )
		for _, neighbor in ipairs ( neighbors ) do 
			if not_in ( closedset, neighbor ) then
			
				local tentative_g_score = g_score [ current ] + dist ( current, neighbor )
				 
				if not_in ( openset, neighbor ) or tentative_g_score < g_score [ neighbor ] then 
					came_from 	[ neighbor ] = current
					g_score 	[ neighbor ] = tentative_g_score
					f_score 	[ neighbor ] = g_score [ neighbor ] + he ( neighbor, goal )
					if not_in ( openset, neighbor ) then
						table.insert ( openset, neighbor )
					end
				end
			end
		end
	end
	return nil -- no valid path
end

-- END COPYRIGHT SECTION

function irand()
 return (rand()%100)/100
--  return math.random()
end

civ_side_name = "Civillian traffic"

function RP_slerp(rp1, rp2, amount) 
 local rpq1 = Quaternion.fromPos(ScenEdit_GetReferencePoint({side=civ_side_name, name=rp1}))
 local rpq2 = Quaternion.fromPos(ScenEdit_GetReferencePoint({side=civ_side_name, name=rp2}))
 return Quaternion.slerp(amount, rpq1, rpq2)
end

function get_pos(wp)
  local irp = ScenEdit_GetReferencePoint({side=civ_side_name, name=wp})
  if irp == nil then print(debug.traceback()) end
  return {irp.latitude, irp.longitude}
end

function wrand(table)
  local total = 0
  for k,v in pairs(table) do
   total = v[1] + total
  end
  local num = irand()*total
  local running = 0
  for k,v in pairs(table) do
   running = v[1] + running
   if running >= num then return v[2] end
  end
  return 1/0
end

function trand(table)
  return table[math.floor(irand() * #table)]
end


Waypoint = {}

function Waypoint.new(center, passage)
  local out = {}
  out.center = get_pos(center)
  out.passage = passage
  out.connections = {}
  out.path = Waypoint.path
  out.type = "waypoint"
  return out
end

local gcd = function(p1,p2)
  local R = 6371; 
  local lat1,lon1 = p1[1],p1[2]
  local lat2,lon2 = p2[1],p2[2]
  local dLat = math.rad(lat2-lat1);
  local dLon = math.rad(lon2-lon1);
  local lat1 = math.rad(lat1);
  local lat2 = math.rad(lat2);

  local a = math.sin(dLat/2) * math.sin(dLat/2) +
          math.sin(dLon/2) * math.sin(dLon/2) * math.cos(lat1) * math.cos(lat2); 
  local c = 2 * math.atan2(math.sqrt(a), math.sqrt(1-a)); 
  return R * c;
end

function Waypoint.heuristic(wp1, wp2)
  local extra = 0
  if wp1.type == "port" then extra = 10000000 end
  return gcd(wp1.center, wp2.center) + extra
end

function Waypoint.distance(wp1, wp2)
  local extra = 0
  if wp2.type == "port" then extra = 10000000 end
  return gcd(wp1.center, wp2.center) + extra
end

function Waypoint.neighbors(p)
  print(p==nil)
  return p.connections
end

function Waypoint.path(p)
  local out = {}
  local num = irand()
  for k,v in pairs(p.passage) do
    table.insert(out, RP_slerp(v[1],v[2],num))
  end
  return out
end

-- Port traffic schema
-- {{frequency, {destination, shipdist}}, ...}

Port = {}
function Port.new(name, sourcerate, traffic, out_wps, types, spawn, sink, center)
 local out = {}
 out.name = name
 out.traffic = traffic
 out.source = spawn
 out.dest = sink
 out.center = get_pos(center)
 out.sourcerate = sourcerate
 
 out.connections = out_wps
 
 out.spawn = Port.spawn
 out.path = Port.sink
 
 out.type = "port"
 return out
end

function Port.spawn(p, toSpawn) -- {destination, shipdist}
  local dest = toSpawn[1]
  local shipType = wrand(toSpawn[2])
  if shipType == nil then print(toSpawn) end

  local start = RP_slerp(p.source[1], p.source[2], irand()):toLatLon()
  print(start)
  
  return ScenEdit_AddUnit({name=trand(shipType[2]) .. " : " .. p.name .. "->" .. dest.name, dbid=shipType[1], type="Ship", side=civ_side_name, latitude=start[1], longitude=start[2]})
end

function Port.sink(p)
  return {RP_slerp(p.dest[1], p.dest[2], irand())}
end


Traffic = {}
function Traffic.new(ports)
  local out = {}
  out.ports = ports
  
  out.sources = {}
  out.sinks = {}
  for k,v in pairs(ports) do
    local total = 0
    if (v.sourcerate > 0) then table.insert(out.sources, {v.sourcerate,v}) end
  end
  
  out.generate = Traffic.generate
  return out
end

function Traffic.generate(traff)
  function append(a,b)
    for k,v in pairs(b) do
      table.insert(a,v)
    end
  end
  local source = wrand(traff.sources)
  local routeInfo = wrand(source.traffic)
  print(source==nil)
  local channel = a_star(source, routeInfo[1], Waypoint.neighbors, Waypoint.heuristic, Waypoint.distance)
  if channel ~= nil then
    print("ch" .. tostring(#channel))
  end
  local sourcePort = table.remove(channel, 1)
  
  local ship = sourcePort:spawn(routeInfo)
  local route = {}
  for k,v in pairs(channel) do
    append(route, v:path())
  end
  
  local converted = {}
  for k,v in pairs(route) do
    local llp = v:toLatLon()
    table.insert(converted, {latitude=llp[1], longitude=llp[2]})
  end
  print(converted)
  ship.course = converted
  return ship, converted
end



shipnames = {"KOTA SATRIA",
"JRS CARINA",
"PRIAMOS",
"CMA CGM RHONE",
"CSCL TOKYO",
"CMA CGM PARSIFAL",
"MILD WALTZ",
"CARPATHIA",
"CAP CORAL",
"OOCL QINGDAO",
"PERFORMANCE",
"WAN HAI 233",
"SEOUL TRADER",
"EVER DELUXE",
"MOL NALA",
"COSCO KIKU",
"HANSA SALZBURG",
"COSCO WELLINGTON",
"HANJIN UNITED KINGDOM",
"BLUE MOON",
"COSCO THAILAND",
"FS SANAGA",
"MAERSK COTONOU",
"SINOTRANS QINGDAO",
"HANJIN SAN DIEGO",
"BLUE MOON",
"EVER LUNAR",
"KOTA LAMBANG",
"WAN HAI 202",
"OOCL NOVOROSSIYSK",
"YM INTELLIGENT",
"JJ TOKYO",
"SHANGHAI SUPER EXPRESS",
"MSC RANIA",
"DONGJIN VENUS",
"PRAGUE EXPRESS",
"COSCO ROTTERDAM",
"FORMOSA CONTAINER NO.5",
"HS ONORE",
"SITC SHANDONG",
"FORMOSA CONTAINER NO.5",
"MAERSK STOCKHOLM",
"SITC TOKYO",
"APL SINGAPORE",
"BAGAN STAR",
"QIU JIN",
"OPTIMA",
"XIN NING BO",
"WAN HAI 232",
"VENUS C",
"MALLECO",
"SITC XIAMEN",
"YM INAUGURATION",
"HYUNDAI VLADIVOSTOK",
"LUNG MUN",
"HANJIN LONG BEACH",
"DA PING",
"APL BOSTON",
"NYK VIRGO",
"RELIANCE",
"UNI CHART",
"MSC JOANNA",
"SUNNY CALLA",
"CARSTEN MAERSK",
"VIRA BHUM",
"WAN HAI 516",
"MSC AMALFI",
"SINOKOR AKITA",
"WAN HAI 503",
"SAFMARINE NOMAZWE",
"TS JAPAN",
"IRENES RELIANCE",
"LILA BHUM",
"MOL ENTERPRISE",
"NYK DANIELLA",
"HEUNG-A JANICE",
"WAN HAI 213",
"FENGYUNHE",
"COSCO COLOMBO",
"EASLINE BUSAN",
"MAERSK CADIZ",
"SAIGON BRIDGE",
"HANSA RAVENSBURG",
"HANJIN HAIPHONG",
"KAETHE P",
"STADT ROSTOCK",
"SHANGHAI EXPRESS",
"HYUNDAI ADVANCE",
"SITC NINGBO",
"XIU HE",
"CMA CGM MIMOSA",
"XIN TIAN JIN",
"KOTA CARUM",
"ELEONORA MAERSK",
"YM ENLIGHTENMENT",
"HANJIN MARSEILLES",
"EASTERN EXPRESS",
"KUO WEI",
"GLORY OCEAN",
"CMA CGM VERDI",
"CLEMENTINE MAERSK",
"GUSTAV MAERSK",
"SINOTRANS SHANGHAI",
"X-PRESS KARAKORAM",
"HONGKONG BRIDGE",
"XIN MING ZHOU 20",
"MAERSK EMDEN",
"BANI BHUM",
"AL RIFFA",
"BUDAPEST BRIDGE",
"PERTH BRIDGE",
"ZIM VIRGINIA",
"STAR EXPRESS",
"JJ STAR",
"MSC MAEVA",
"MAERSK WIESBADEN",
"BENITA SCHULTE",
"ZIM RIO GRANDE",
"THALASSA PATRIS",
"RHL AUDACIA",
"QI MEN",
"JPO PISCES",
"SINOTRANS QINGDAO",
"MOL GARLAND",
"VEGA SKY",
"ITAL UNICA",
"CHUN JIN",
"MITRA BHUM",
"BERMUDIAN EXPRESS",
"TALLAHASSEE",
"MILD JAZZ",
"MILD CHORUS",
"YM ORCHID",
"MEDAEGEAN",
"COSCO KAOHSIUNG",
"SINOTRANS HONG KONG",
"HARUKA",
"CSCL OSAKA",
"MAULLIN",
"ISTRIAN EXPRESS",
"MARCARRIER",
"NORTHERN GRANDOUR",
"CSCL OCEANIA",
"MSC TERESA",
"SHANGHAI SUPER EXPRESS",
"CMA CGM CORTE REAL",
"UASC YAS",
"COSCO  SPAIN",
"BRITAIN",
"HANJIN NHAVA SHEVA",
"MSC ALTAIR",
"WAN HAI 511",
"MARCONNECTICUT",
"YM UNIFORMITY",
"SANTA BELINA",
"CSAV LEBU",
"SITC OSAKA",
"SKY EVOLUTION",
"RHL CONSCIENTIA",
"MATZ MAERSK",
"SITC YOKKAICHI",
"WISDOM GRACE",
"CSCL NAGOYA",
"EVER UNION",
"TIAN BAO HE",
"HANJIN EUROPE",
"KMTC NINGBO",
"LANTAU BAY",
"RESURGENCE",
"CSCL MONTEVIDEO",
"SINOTRANS DALIAN",
"STAR UNIX",
"SCI CHENNAI",
"COSCO NETHERLANDS",
"HANJIN MAR",
"MARCONNECTICUT",
"CARDONIA",
"SITC HONGKONG",
"SITC SHANGHAI",
"HYUNDAI PREMIUM",
"WAN HAI 206",
"CMA CGM COLUMBA",
"CCL NINGBO",
"KAPITAN MASLOV",
"CMA CGM SWORDFISH",
"WENDE",
"CMA CGM VIVALDI",
"MILD SONATA",
"LANTAU BEACH",
"SITC JAKARTA",
"SITC NAGOYA",
"ASIAN STAR",
"MSC GAIA",
"CSAV TRAIGUEN",
"TOKYO TRADER",
"JJ NAGOYA",
"LOUDS ISLAND",
"CAPE MAHON",
"RACHA BHUM",
"SINOTRANS TIANJIN",
"XIN XIA MEN",
"HANJIN ROME",
"GLORY FORTUNE",
"O.M.AUTUMNI",
"KOTA GAYA",
"SKY LOVE",
"NYK DENEB",
"BLUE OCEAN",
"VALOR",
"SEA-LAND COMET",
"SITC MANILA",
"UNDARUM",
"MELL SOLOMON",
"YUEHE",
"KYOTO TOWER",
"DONG FANG FU",
"SINOKOR VLADIVOSTOK",
"EASLINE SHANGHAI",
"ANNIKA",
"CMA CGM MELISANDE",
"NORTHERN VIGOUR",
"CSCL YOKOHAMA",
"CSCL TOKYO",
"HASCO QINGDAO",
"GANTA BHUM",
"EVER LOGIC",
"JRS CARINA",
"RBD BOREA",
"COSCO SURABAYA",
"YM MATURITY",
"EVER SMART",
"COSCO EUROPE",
"MSC MELATILDE",
"COLUMBINE MAERSK",
"SILVER FERN",
"HANJIN DURBAN",
"JAKARTA TOWER",
"TORRES STRAIT",
"HE YANG",
"COSCO KIKU",
"XIN YAN TAI",
"EVER DEVELOP",
"MILD WALTZ",
"COSCO AQABA",
"ZHONG WAI YUN QUAN ZHOU",
"KIEL EXPRESS",
"MOL DESTINY",
"APL TEMASEK",
"SASCO AVACHA",
"YM NEW JERSEY",
"CAP ARNAUTI",
"OOCL EUROPE",
"YM HORIZON",
"MAERSK ALTAIR",
"EVER CHAMPION",
"HYUNDAI SPRINTER",
"MEDBOTHNIA",
"WAN HAI 202",
"KOTA LUMBA",
"QIU JIN",
"COSCO RAN",
"YM WEALTH",
"SITC KAOHSIUNG",
"APL HOLLAND",
"COSCO TIANJIN",
"FORMOSA CONTAINER NO.5",
"SAJIR",
"VENUS C",
"BUSAN TRADER",
"COSCO SAOPAULO",
"COSCO SHANGHAI  ",
"OPTIMA",
"HANJIN VIENNA",
"TEXAS",
"SHABGOUN",
"VAN MANILA",
"JJ TOKYO",
"DONGJIN VENUS",
"MATAQUITO",
"KARIN RAMBOW",
"SITC ZHEJIANG",
"SHANGHAI SUPER EXPRESS",
"NYK FUTAGO",
"XIANG MING",
"SAN FRANCISCO EXPRESS",
"SAFMARINE CHILKA",
"WMS AMSTERDAM",
"SITC XIAMEN",
"AKARI",
"ZIM VANCOUVER",
"CSCL SYDNEY",
"ZIM IBERIA",
"LUNG MUN",
"SEOUL TOWER",
"HYUNDAI BRIDGE",
"MSC VANCOUVER",
"A.P. MOLLER",
"OOCL WASHINGTON",
"RUBINA SCHULTE",
"NORTHERN PRIORITY",
"SVEND MAERSK",
"YM IDEALS",
"SITC SHANDONG",
"HANJIN GENEVA",
"RHL CONCORDIA",
"WAN HAI 235",
"COSCO NEW YORK",
"LILA BHUM",
"MAERSK SANTANA",
"UNI CHART",
"SUNRISE SURABAYA",
"COSCO KOBE",
"CMA CGM BLUE WHALE",
"ALDI WAVE",
"APL PHOENIX",
"COSCO DURBAN",
"EASLINE BUSAN",
"MAUNALEI",
"FPMC CONTAINER 8",
"SUNNY DAISY",
"WAN HAI 507",
"DA PING",
"MAERSK CONAKRY",
"WAN HAI 211",
"OSG ALPHA",
"CMA CGM NABUCCO",
"CMA CGM LA SCALA",
"WELLINGTON STRAIT",
"FESCO DIOMID",
"FESCO ALMATHEA",
"MAERSK EDINBURGH",
"MAERSK JURONG",
"HYUNDAI SPEED",
"HYUNDAI GRACE",
"STAR SKIPPER",
"MOL SPARKLE",
"SEROJA LIMA",
"HYUNDAI PROGRESS",
"PANCON SUCCESS",
"GLORY OCEAN",
"CMA CGM ROSSINI",
"SITC NINGBO",
"GUTHORM MAERSK",
"OOCL CHINA",
"VALDIVIA",
"XIN DA LIAN",
"JJ STAR",
"MOL INTEGRITY",
"ANL WANGARATTA",
"KOTA LIHAT",
"SINOTRANS DALIAN",
"KUO WEI",
"JEJU ISLAND",
"ANL WYONG",
"MOL PARAMOUNT",
"SITC HOCHIMINH",
"VAN HARMONY",
"DOLPHIN II",
"PAUL RUSS",
"CSCL ZEEBRUGGE",
"SUZANNE",
"XIN MING ZHOU 20",
"CAPE NEMO",
"THALASSA HELLAS",
"KOTA CANTIK",
"VECCHIO BRIDGE",
"ARGOS",
"HANSA LUDWIGSBURG",
"CMA CGM AFRICA FOUR",
"XIN MEI ZHOU",
"QI MEN",
"HANJIN ROTTERDAM",
"WESERWOLF",
"KOTA LUKIS",
"CSCL OSAKA",
"EVER SHINE",
"MILD JAZZ",
"CHUN JIN",
"COSCO ANTWERP",
"HANJIN SPAIN",
"MARCARRIER",
"APL VANDA",
"HYUNDAI TENACITY",
"SITC LAEM CHABANG",
"SHANGHAI SUPER EXPRESS",
"MILD CHORUS",
"COSCO ITALY",
"MSC EVA",
"YM GREEN",
"SINOTRANS SHANGHAI",
"YM BAMBOO",
"HANJIN LONG BEACH",
"UASC JEDDAH",
"MEDAEGEAN",
"BALTIMORE BRIDGE",
"CSCL NEPTUNE",
"CAP SAN SOUNIO",
"MARCONNECTICUT",
"ALTAIR SKY",
"SWANSEA",
"MSC BRUXELLES",
"MITRA BHUM",
"WIDE CHARLIE",
"MOL ADVANTAGE",
"KOTA LEMBAH",
"PRIORITY",
"SINOTRANS HONG KONG",
"SUNNY LOTUS",
"HANJIN SAO PAULO",
"ST. JOHN",
"MSC RENEE",
"CMA CGM CHRISTOPHE COLOMB",
"TALLAHASSEE",
"HANJIN HARMONY",
"SITC HONGKONG",
"STAR CLIPPER",
"MSC FABIOLA",
"TALLAHASSEE",
"CARPATHIA",
"MAERSK LETICIA",
"HS WAGNER",
"OSAKA TOWER",
"CSCL CALLAO",
"SINOTRANS BEIJING",
"LANTAU BAY",
"YM ULTIMATE",
"MAERSK DHAHRAN",
"TRIDENT",
"MADISON MAERSK",
"FSL BUSAN",
"ASIAN ZEPHYR",
"COSCO  SPAIN",
"SKY EVOLUTION",
"TS SINGAPORE",
"CSCL YOKOHAMA",
"KMTC NINGBO",
"HANSA SIEGBURG",
"EVER ULTRA",
"KMTC SHENZHEN",
"MAERSK SOFIA",
"HANSA DUBURG",
"HAMMONIA PESCARA",
"XIN LOS ANGELES",
"ISARA BHUM",
"ITAL USODIMARE",
"WENDE",
"VLADIVOSTOK",
"CMA CGM MARLIN",
"JRS CANIS",
"CMA CGM CASSIOPEIA",
"SINOTRANS TIANJIN",
"LANTAU BEACH",
"SKY LOVE",
"MALTE RAMBOW",
"DONG FANG FU",
"EASLINE SHANGHAI",
"HANJIN PARIS",
"O.M.AUTUMNI",
"NYK DELPHINUS",
"CMA CGM HUGO",
"KUO CHANG",
"SITC YOKKAICHI",
"CSCL TOKYO",
"ASIAN STAR",
"MAERSK GIRONDE",
"SITC BANGKOK",
"UASC JILFAR",
"CMA CGM ALMAVIVA",
"GLORY FORTUNE",
"EUGEN MAERSK",
"CMA CGM FAUST",
"JJ NAGOYA",
"SINOKOR VLADIVOSTOK",
"DA QING HE",
"CCL NINGBO",
"KMTC JAKARTA",
"ANNIKA",
"SITC LIANYUNGANG",
"CSCL SUMMER",
"MILD SONATA",
"HASCO QINGDAO",
"OLYMPIA",
"HYUNDAI PRIVILEGE",
"UNDARUM",
"BLUE OCEAN",
"CSCL NAGOYA",
"CAROLINE MAERSK",
"LINDAUNIS",
"SITC MANILA",
"KOTA PERMASAN",
"EVER LUCID",
"ITAL MATTINA",
"MSC INES",
"JRS CARINA",
"ANNA—LISA",
"PERSEUS ",
"JPO TUCANA",
"BALEARES",
"OOCL NINGBO",
"MSC BARI",
"HANJIN KINGSTON",
"HE YANG",
"COSCO KIKU",
"GUANG DONG BRIDGE",
"MCC SEOUL",
"MAERSK LAMANAI",
"WAN HAI 233",
"ITAL LAGUNA",
"MILD WALTZ",
"COSCO PACIFIC",
"OOCL DUBAI",
"O.M. AGARUM",
"NYK ATLAS",
"XIN YA ZHOU",
"KUO TAI",
"MARCLOUD",
"XIN BEI LUN",
"EVER LOYAL",
"YM COSMOS",
"YM INTELLIGENT",
"WAN HAI 202",
"WMS AMSTERDAM",
"JJ TOKYO",
"LU HE",
"NORTHERN DIVINITY",
"SITC TOKYO",
"ABYAN",
"COSCO RAN",
"FORMOSA CONTAINER NO.5",
"HANJIN NAMU",
"DONGJIN VENUS",
"MEDBOTHNIA",
"YM KAOHSIUNG",
"SHANGHAI SUPER EXPRESS",
"MONI RICKMERS",
"MAIPO",
"YM FOUNTAIN",
"WIDE ALPHA",
"NORDLUCHS",
"MSC PINA",
"MAERSK SEMBAWANG",
"ANNA MAERSK",
"MAERSK CAPE TOWN",
"SITC XIAMEN",
"MSC ESTHI",
"BLUE MOON",
"XIANG MING",
"WAN HAI 262",
"XIN FU ZHOU",
"ZIM SAO PAOLO",
"QIU JIN",
"UMM SALAL",
"APL HONG KONG",
"HANJIN CHENNAI",
"BAGAN STAR",
"VENUS C",
"MUSE",
"APL JAPAN",
"OPTIMA",
"KOTA LUMBA",
"HYUNDAI ADVANCE",
"LUNG MUN",
"YM INAUGURATION",
"VIENNA EXPRESS",
"HANJIN HAMBURG",
"HANJIN CALIFORNIA",
"DA PING",
"SITC ZHEJIANG",
"NORTHERN GUILD",
"KOTA LANGSAR",
"COSCO GENOA",
"RJ PFEIFFER",
"OOCL TOKYO",
"CSAV TRAIGUEN",
"RELIANCE",
"MSC AGRIGENTO",
"SUNNY CALLA",
"HANJIN COPENHAGEN",
"EASLINE BUSAN",
"HEUNG-A JANICE",
"SOVEREIGN MAERSK",
"UNI CHART",
"CSAV LUMACO",
"GERD MAERSK",
"SINOKOR AKITA",
"SFL AVON",
"LILA BHUM",
"MAERSK LAUNCESTON",
"FENGYUNHE",
"STADT ROSTOCK",
"KMTC SINGAPORE",
"AMBASSADOR BRIDGE",
"MAERSK CABINDA",
"RHL CALLIDITAS",
"FESCO KOREA ",
"MSC ARIANE",
"MSC ARIANE",
"CMA CGM CENDRILLON",
"HANJIN QINGDAO",
"CALA PINGUINO",
"HAMMONIA GALICIA",
"JJ STAR",
"COSCO IZMIR",
"CMA CGM STRAUSS",
"ZIM SAN FRANCISCO",
"OOCL CHICAGO",
"GLORY OCEAN",
"HYUNDAI FUTURE",
"CSCL MARS",
"OOCL CHONGQING",
"SITC NINGBO",
"THALASSA TYHI",
"EVER RESPECT",
"CHILOE ISLAND",
"KUO WEI",
"ANTHEA",
"MAERSK EFFINGHAM",
"SITC OSAKA",
"SITC HAIPHONG",
"DAINTY RIVER",
"BALLENITA",
"KOTA CEPAT",
"CHASTINE MAERSK",
"NYK LEO",
"HYUNDAI GLOBAL",
"EVER APEX",
"ZIM COLOMBO",
"SINOTRANS SHANGHAI",
"EASTERN EXPRESS",
"E.R. MALMO",
"MAERSK SANA",
"KYOTO EXPRESS",
"XIN MING ZHOU 20",
"CSCL SANTIAGO",
"STAR PIONEER",
"MTT PULAU PINANG",
"OOCL YOKOHAMA",
"YM ELIXIR",
"CMA CGM PUGET",
"QI MEN",
"RBD BOREA",
"CMA CGM JASPER",
"MILD CHORUS",
"COSCO ASIA",
"MITRA BHUM",
"SKY HOPE",
"NORDOCELOT",
"NYK TRITON",
"SINOTRANS QINGDAO",
"MSC RENEE",
"TALLAHASSEE",
"VEGA SKY",
"EVER CONQUEST",
"SHANGHAI SUPER EXPRESS",
"APL SENTOSA",
"SINOTRANS HONG KONG",
"MILD JAZZ",
"COSCO BELGIUM",
"MSC DANIT",
"YM EVOLUTION",
"MEDAEGEAN",
"JOGELA",
"SITC LAEM CHABANG",
"EVER UBERTY",
"JEBEL ALI",
"BANGKOK BRIDGE",
"CHUN JIN",
"MARCARRIER",
"MOL PARTNER",
"BRIGHT LAEM CHABANG",
"CSCL OSAKA",
"XIN CHI WAN",
"MSC LUCIANA",
"WAN HAI 513",
"NORDCHEETAH",
"SEROJA ENAM",
"CMA CGM LAPEROUSE",
"SEROJA ENAM",
"MARCONNECTICUT",
"MOL PREMIUM",
"XIN BEIJING",
"COSCO ITALY",
"LANTAU BAY",
"ARABIAN EXPRESS",
"CSCL SAN JOSE",
"YM INTERACTION",
"KMTC SHENZHEN",
"CONTRAIL SKY",
"CSCL TOKYO",
"YM INTERACTION",
"SITC KWANGYANG",
"NORTHERN VIGOUR",
"HANJIN CHENNAI",
"SINOTRANS DALIAN",
"SKY EVOLUTION",
"EVER EAGLE",
"ZIM LOS ANGELES",
"HONOLULU BRIDGE",
"MARCONNECTICUT",
"MAERSK DENPASAR",
"HYUNDAI HARMONY",
"CCL NINGBO",
"KMTC QINGDAO",
"MAERSK ELBA",
"MAKITA",
"SITC HOCHIMINH",
"SITC SHANGHAI",
"EVER EXCEL",
"STAR EXPRESS",
"HANJIN AFRICA",
"MOGENS MAERSK",
"MAERSK SHEERNESS",
"HELENA SCHULTE",
"CMA CGM VIRGINIA",
"WENDE",
"KAPITAN MASLOV",
"CMA CGM THALASSA",
"SAN PEDRO",
"LANTAU BEACH",
"HANJIN BUDAPEST",
"HASCO QINGDAO",
"BLUE OCEAN",
"HYUNDAI UNITY",
"UNDARUM",
"EVER LIBERAL",
"SINOKOR VLADIVOSTOK",
"ANNIKA",
"KENO ",
"DONG FANG FU",
"GLORY FORTUNE",
"SITC BUSAN",
"CSCL NAGOYA",
"CAP CAMPBELL",
"MSC MARIA SAVERIA",
"SKY LOVE",
"CORNELIUS MAERSK",
"JITRA BHUM",
"MILD SONATA",
"UASC UMM QASR",
"EASLINE SHANGHAI",
"O.M.AUTUMNI",
"SITC FANGCHENG",
"SITC MANILA",
"JJ NAGOYA",
"WILLIAM STRAIT",
"SINOTRANS TIANJIN",
"NYK REMUS",
"SEA-LAND INTREPID",
"CSAV TYNDALL",
"CSCL YOKOHAMA",
"CSCL AUTUMN",
"CAPE MORETON",
"PERSEUS ",
"YELLOW MOON",
"ASIAN STAR",
"CMA CGM ORFEO",
"SUNSHINE BANDAMA",
"KOTA GUNAWAN",
"ISTRIAN EXPRESS",
"JRS CARINA",
"HE YANG",
"COSCO MALAYSIA",
"YM HORIZON",
"EVER DIADEM",
"MARE LYCIUM",
"YM GREAT",
"HYUNDAI STRIDE",
"XIN QING DAO",
"NILEDUTCH GIRAFFE",
"EVER LEADER",
"ZHONG WAI YUN QUAN ZHOU",
"OOCL NETHERLANDS",
"MCC KYOTO",
"THANLWIN STAR",
"COSCO JAPAN",
"HANJIN ATLANTA",
"HANJIN GWANSEUM",
"MILD WALTZ",
"COSCO KIKU",
"MSC PALOMA",
"STADT MARBURG",
"SASCO AVACHA",
"WAN HAI 202",
"MEDBOTHNIA",
"COSCO AUCKLAND",
"OPTIMA",
"MSC ROMA",
"MUSE",
"XIANG MING",
"CHINA STAR",
"COSCO SINGAPORE",
"NYK ATHENA",
"MAERSK SEMAKAU",
"TUCAPEL",
"SITC KOBE",
"COSCO RAN",
"AKARI",
"CSCL PACIFIC OCEAN",
"ZARDIS",
"JJ TOKYO",
"OOCL SEOUL",
"VENUS C",
"MAERSK DANANG",
"SITC XIAMEN",
"CSCL MELBOURNE",
"DONGJIN VENUS",
"TOKYO TRADER",
"GRASMERE MAERSK",
"HS MOZART",
"SAIGON BRIDGE",
"ZIM SHEKOU",
"QIU JIN",
"FORMOSA CONTAINER NO.5",
"SHANGHAI SUPER EXPRESS",
"HANJIN TAIPEI",
"WMS AMSTERDAM",
"KOTA LAZIM",
"CHUAN HE",
"MSC SINDY",
"YM SEATTLE",
"NORTHERN DEMOCRAT",
"HAMMONIA THRACIUM",
"WAN HAI 232",
"ENSENADA EXPRESS",
"APL THAILAND",
"LUNG MUN",
"HYUNDAI PROGRESS",
"HANJIN LONG BEACH",
"NYK DEMETER",
"DA PING",
"APL NEW YORK",
"NYK ISABEL",
"TS JAPAN",
"SVENDBORG MAERSK",
"WAN HAI 215",
"COSCO FOS",
"MSC ALGECIRAS",
"WAN HAI 235",
"LILA BHUM",
"UNI CHART",
"MSC INES",
"EBBA MAERSK",
"FPMC CONTAINER 8",
"NORDLUCHS",
"WAN HAI 601",
"CMA CGM CHATEAU DIF",
"SUNNY DAISY",
"MAERSK VIRGINIA",
"WAN HAI 512",
"GUNDE MAERSK",
"HOLSATIA",
"PACIFIC LINK",
"EASLINE BUSAN",
"YM IDEALS",
"MAERSK CABO VERDE",
"HANJIN AMSTERDAM",
"CSCL NEW YORK",
"WAN HAI 502",
"MAERSK JURONG",
"MANUKAI",
"OSG ALPHA",
"GERDA MAERSK",
"GREEN ACE",
"NAGOYA TOWER",
"COPIAPO",
"MAERSK SOFIA",
"RHL ASTRUM",
"CMA CGM MIMOSA",
"NYK LYNX",
"ZIM ASIA ",
"CSCL HOUSTON",
"STAR UNIX",
"HANJIN GREECE",
"SITC NINGBO",
"THALASSA ELPIDA",
"CSCL MERCURY",
"XIN CHANG SHA",
"XIN MING ZHOU 20",
"MAERSK ENFIELD",
"HAMMONIA IONIUM",
"XIN DA YANG ZHOU",
"KUO WEI",
"XIN QIN HUANG DAO",
"HYUNDAI DREAM",
"SITC HAKATA",
"EVER LUCENT",
"SINOTRANS QINGDAO",
"PANCON SUCCESS",
"SUZANNE",
"SARAH SCHULTE",
"GLORY OCEAN",
"CMA CGM CHOPIN",
"JJ STAR",
"HAMMONIA GALLICUM",
"YM PORTLAND",
"DONAU TRADER",
"HYUNDAI HIGHWAY",
"HYUNDAI GLORY",
"BANI BHUM",
"ZIM SHANGHAI",
"HANSA LUDWIGSBURG",
"ANNA—LISA",
"APL GERMANY",
"QI MEN",
"CHUN JIN",
"COSCO FRANCE",
"MARCARRIER",
"CAUTIN",
"ALTAIR SKY",
"CSCL KINGSTON",
"CSCL URANUS",
"SINOTRANS SHANGHAI",
"MUNKEBO MAERSK",
"SEADREAM",
"SINOTRANS HONG KONG",
"BRIGHT LAEM CHABANG",
"CSCL OSAKA",
"APL RAFFLES",
"MILD JAZZ",
"COSCO PRINCE RUPERT",
"BAY BRIDGE",
"KOTA LEGIT",
"EVER ENVOY",
"MITRA BHUM",
"BERMUDIAN EXPRESS",
"HARUKA",
"MILD CHORUS",
"MARCONNECTICUT",
"CARDIFF",
"MSC LA SPEZIA",
"SHANGHAI SUPER EXPRESS",
"MEDAEGEAN",
"SUNNY LOTUS",
"MSC LAUREN",
"HANJIN NHAVA SHEVA",
"CMA CGM MARCO POLO",
"TALLAHASSEE",
"MSC BETTINA",
"SITC YOKKAICHI",
"HANJIN KOREA",
"LANTAU BAY",
"NOBLE MATAR",
"RESURGENCE",
"SITC HONGKONG",
"CSCL PANAMA",
"ASIAN ZEPHYR",
"XIN SHANGHAI",
"COSCO BELGIUM",
"TALLAHASSEE",
"HANSA SIEGBURG",
"HANJIN GREECE",
"SINOTRANS BEIJING",
"MARIBO MAERSK",
"KOTA LAGU",
"CSCL NAGOYA",
"MSC BENEDETTA",
"HANJIN MARINE",
"CARDONIA",
"YM UBERTY",
"WAN HAI 206",
"HANJIN MARINE",
"SKY EVOLUTION",
"SITC OSAKA",
"HAMMONIA THRACIUM",
"STAR SKIPPER",
"GERNER MAERSK",
"SINOTRANS DALIAN",
"KMTC QINGDAO",
"WENDE",
"EVER ULYSSES",
"JRS CORVUS",
"EVER UTILE",
"CMA CGM MUSCA",
"CMA CGM TARPON",
"MILD SONATA",
"SKY LOVE",
"BLUE OCEAN",
"KYOTO TOWER",
"SITC KWANGYANG",
"SITC MANILA",
"DONG FANG FU",
"NAJADE",
"HANJIN MALTA",
"SUSAN MAERSK",
"CSCL YELLOW SEA",
"LANTAU BEACH",
"VEGA LUPUS",
"SEA-LAND LIGHTNING",
"HASCO QINGDAO",
"E.R. DALLAS",
"CSAV TOCONAO",
"UNDARUM",
"VALUE",
"LOUDS ISLAND",
"EASLINE SHANGHAI",
"CMA CGM TITUS",
"O.M.AUTUMNI",
"HYUNDAI HIGHNESS",
"KOTA GANTENG",
"CSCL TOKYO",
"ASIAN STAR",
"PERSEUS ",
"SINOTRANS TIANJIN",
"SINOKOR VLADIVOSTOK",
"CMA CGM TANCREDI",
"SITC QINGDAO",
"HANJIN BELAWAN",
"EVER LUCKY",
"ANNIKA",
"GLORY FORTUNE",
"GANTA BHUM",
"JJ NAGOYA",
"MSC CAMILLE",
"MANULANI",
"CSCL YOKOHAMA",
"RBD JUTLANDIA",
"JRS CARINA",
"VLADIVOSTOK",
"HANJIN NORFOLK",
"JPO VOLANS",
"COSCO VIETNAM",
"MSC ROSA M",
"KARMEN",
"APL ENGLAND",
"MILD WALTZ",
"AUGUSTA KONTOR",
"TIGER",
"FS SANAGA",
"EVER DELIGHT",
"MAERSK WIESBADEN",
"GOLDEN GATE BRIDGE",
"WAN HAI 233",
"CCL NINGBO",
"MOL QUALITY",
"COSCO KIKU",
"EVER LEGION",
"COSCO BEIJING",
"MSC SONIA",
"HANJIN MARSEILLES",
"KOBE EXPRESS",
"SHANTAR",
"MERATUS JAYAPURA",
"GSL AFRICA",
"HAMMONIA ISTRIA",
"COSCO WELLINGTON",
"COSCO KOREA",
"HE YANG",
"RDO CONCERT",
"WMS AMSTERDAM",
"HANJIN LONG BEACH",
"HANJIN NEW YORK",
"YM INTELLIGENT",
"WAN HAI 202",
"IMARA",
"BUSAN EXPRESS",
"ANL WODONGA",
"SITC XIAMEN",
"XIANG MING",
"SHANGHAI SUPER EXPRESS",
"NYK TERRA",
"SITC SHANDONG",
"FSL SANTOS",
"DONGJIN VENUS",
"ALBERT MAERSK",
"WAN HAI 213",
"FOLEGANDROS",
"AL QIBLA",
"MAERSK SINGAPORE",
"MEDBOTHNIA",
"VAN MANILA",
"TOUSKA",
"ZIM GENOVA",
"SEROJA EMPAT",
"APL PHILIPPINES",
"TENO",
"JJ TOKYO",
"COSCO XIAMEN",
"BAGAN STAR",
"SKAGEN MAERSK",
"NYK ARGUS",
"QIU JIN",
"JPO ATAIR",
"KOTA LATIF",
"VENUS C",
"MALTE RAMBOW",
"MOL PROMISE",
"MUSE",
"LUNG MUN",
"KOTA LAWA",
"HYUNDAI FUTURE",
"HYUNDAI TACOMA",
"RELIANCE",
"UNI CHART",
"VIRA BHUM",
"YM LOS ANGELES",
"HANJIN NEWPORT"}


local LaotieshanWE = Waypoint.new("RP-709", {{"RP-74","RP-686"},{"RP-669","RP-687"}})
local LaotieshanEW = Waypoint.new("RP-710", {{"RP-670","RP-688"},{"RP-71","RP-685"}})
local QinhuangdaoLaotieshan = Waypoint.new("RP-713",{{"RP-696", "RP-695"}})
local DalianDandong = Waypoint.new("RP-716",{{"RP-714", "RP-715"}})

local LaotieshanChannelNorthernBohaiSea = Waypoint.new("RP-809",{{"RP-575", "RP-576"}})
local NorthernBohaiSea = Waypoint.new("RP-813",{{"RP-812", "RP-811"}})

local DalianDandong2a = Waypoint.new("RP-903",{{"RP-901", "RP-902"}})
local DalianDandong2b = Waypoint.new("RP-905",{{"RP-904", "RP-906"}})

local TianjinQinhuangdaoa = Waypoint.new("RP-966",{{"RP-965", "RP-967"}})
local TianjinQinhuangdaob = Waypoint.new("RP-960",{{"RP-959", "RP-961"}})
local TianjinQinhuangdaoc = Waypoint.new("RP-963",{{"RP-962", "RP-964"}})

local LaotieshanChannelTSS = Waypoint.new("RP-857",{{"RP-855", "RP-856"}})

local ChengshanCapeTSSNS = Waypoint.new("RP-1038", {{"RP-1033","RP-1032"},{"RP-1035","RP-1034"},{"RP-1037","RP-1036"}})
local ChengshanCapeTSSSN = Waypoint.new("RP-1030", {{"RP-627","RP-628"},{"RP-1027","RP-1031"},{"RP-67","RP-68"}}) 

local ChangshanChannelTSSEW = Waypoint.new("RP-1246", {{"RP-705","RP-706"},{"RP-704","RP-581"},{"RP-707","RP-708"}})
local ChangshanChannelTSSWE = Waypoint.new("RP-1247", {{"RP-699","RP-700"}, {"RP-582","RP-701"}, {"RP-703", "RP-702"}})

local YellowSea = Waypoint.new("RP-1209",{{"RP-1210","RP-1208"}})
local YellowSeaS = Waypoint.new("RP-1309",{{"RP-1310","RP-1308"}})

local test_ship_type = {{1,{2027,shipnames}}}

function scale_rates(factor, table)
 local output = {}
 for k,v in pairs(table) do
  output[k * factor] = v
 end
 return output
end

local tianjin_dom_ship_types = {
{1,{2357,shipnames}},
{2,{2359,shipnames}},
{1,{2358,shipnames}},
{1,{1002,shipnames}},
{2,{1317,shipnames}},
{11,{774,shipnames}},
{8,{2026,shipnames}},
{1,{222,shipnames}},
{4,{1001,shipnames}}
}

local tianjin_intl_ship_types = {
{4,{1374,shipnames}},
{12,{775,shipnames}},
{2,{773,shipnames}},
{26,{2023,shipnames}},
{1,{1006,shipnames}},
{1,{2034,shipnames}},
{4,{2027,shipnames}},
{2,{144,shipnames}},
{5,{2028,shipnames}},
{1,{275,shipnames}}
}

local Qinhuangdao = Port.new("Qinhuangdao", 46, {}, {QinhuangdaoLaotieshan, LaotieshanChannelNorthernBohaiSea, TianjinQinhuangdaoc}, test_ship_type, {"RP-668", "RP-667"}, {"RP-666","RP-665"}, "RP-717")
local Dandong = Port.new("Dandong", 18, {}, {DalianDandong, DalianDandong2b}, test_ship_type, {"RP-683", "RP-684"}, {"RP-1108","RP-1107"}, "RP-1109")
local Yingkou = Port.new("Yingkou", 81, {}, {NorthernBohaiSea},  test_ship_type, {"RP-631","RP-632"}, {"RP-574","RP-573"}, "RP-808")
local Tianjin = Port.new("Tianjin", 162, {}, {LaotieshanChannelTSS, TianjinQinhuangdaoa, ChangshanChannelTSSWE},  test_ship_type, {"RP-625","RP-626"}, {"RP-75","RP-78"}, "RP-850")
local Dalian = Port.new("Dalian", 155, {}, {DalianDandong2a, LaotieshanEW, ChengshanCapeTSSNS}, test_ship_type, {"RP-678","RP-677"}, {"RP-675","RP-676"}, "RP-907")
local SCS = Port.new("SCS", 250, {}, {ChengshanCapeTSSSN, YellowSea, YellowSeaS}, test_ship_type, {"RP-656","RP-655"}, {"RP-656","RP-655"}, "RP-1025")

table.insert(Tianjin.traffic, {5, {SCS, tianjin_intl_ship_types}})
table.insert(Tianjin.traffic, {1, {Qinhuangdao, tianjin_dom_ship_types}})
table.insert(Tianjin.traffic, {1, {Dandong, tianjin_dom_ship_types}})
table.insert(Tianjin.traffic, {1, {Yingkou, tianjin_dom_ship_types}})
table.insert(Tianjin.traffic, {1, {Dalian, tianjin_dom_ship_types}})

table.insert(SCS.traffic, {1, {Tianjin, tianjin_intl_ship_types}})
table.insert(SCS.traffic, {1, {Qinhuangdao, tianjin_intl_ship_types}})
table.insert(SCS.traffic, {1, {Yingkou, tianjin_intl_ship_types}})
table.insert(SCS.traffic, {1, {Dalian, tianjin_intl_ship_types}})

table.insert(Dalian.traffic, {5, {SCS, tianjin_intl_ship_types}})
table.insert(Dalian.traffic, {1, {Qinhuangdao, tianjin_dom_ship_types}})
table.insert(Dalian.traffic, {1, {Dandong, tianjin_dom_ship_types}})
table.insert(Dalian.traffic, {1, {Yingkou, tianjin_dom_ship_types}})
table.insert(Dalian.traffic, {1, {Tianjin, tianjin_dom_ship_types}})

table.insert(Yingkou.traffic, {5, {SCS, tianjin_intl_ship_types}})
table.insert(Yingkou.traffic, {1, {Qinhuangdao, tianjin_dom_ship_types}})
table.insert(Yingkou.traffic, {1, {Dandong, tianjin_dom_ship_types}})
table.insert(Yingkou.traffic, {1, {Dalian, tianjin_dom_ship_types}})
table.insert(Yingkou.traffic, {1, {Tianjin, tianjin_dom_ship_types}})

table.insert(Qinhuangdao.traffic, {5, {SCS, tianjin_intl_ship_types}})
table.insert(Qinhuangdao.traffic, {1, {Dalian, tianjin_dom_ship_types}})
table.insert(Qinhuangdao.traffic, {1, {Dandong, tianjin_dom_ship_types}})
table.insert(Qinhuangdao.traffic, {1, {Yingkou, tianjin_dom_ship_types}})
table.insert(Qinhuangdao.traffic, {1, {Tianjin, tianjin_dom_ship_types}})

table.insert(Dandong.traffic, {1, {Dalian, tianjin_dom_ship_types}})
table.insert(Dandong.traffic, {1, {Qinhuangdao, tianjin_dom_ship_types}})
table.insert(Dandong.traffic, {1, {Yingkou, tianjin_dom_ship_types}})
table.insert(Dandong.traffic, {1, {Tianjin, tianjin_dom_ship_types}})

table.insert(YellowSeaS.connections, SCS)

table.insert(LaotieshanWE.connections, DalianDandong)
table.insert(LaotieshanWE.connections, Dalian)
table.insert(LaotieshanWE.connections, ChengshanCapeTSSNS)
table.insert(LaotieshanEW.connections, LaotieshanChannelTSS)

table.insert(ChangshanChannelTSSWE.connections, ChengshanCapeTSSNS)
table.insert(ChangshanChannelTSSWE.connections, Dalian)
table.insert(ChangshanChannelTSSWE.connections, DalianDandong)
table.insert(ChangshanChannelTSSEW.connections, QinhuangdaoLaotieshan)
table.insert(ChangshanChannelTSSEW.connections, LaotieshanChannelNorthernBohaiSea)
table.insert(ChangshanChannelTSSEW.connections, Tianjin)
table.insert(ChangshanChannelTSSEW.connections, LaotieshanWE)

table.insert(LaotieshanChannelTSS.connections, QinhuangdaoLaotieshan)
table.insert(LaotieshanChannelTSS.connections, LaotieshanChannelNorthernBohaiSea)
table.insert(LaotieshanChannelTSS.connections, Tianjin)
table.insert(LaotieshanChannelTSS.connections, LaotieshanWE)

table.insert(DalianDandong2a.connections, DalianDandong2b)
table.insert(DalianDandong2a.connections, Dalian)
table.insert(DalianDandong2b.connections, DalianDandong2a)
table.insert(DalianDandong2b.connections, Dandong)

table.insert(TianjinQinhuangdaoa.connections, Tianjin)
table.insert(TianjinQinhuangdaoa.connections, TianjinQinhuangdaob)
table.insert(TianjinQinhuangdaob.connections, TianjinQinhuangdaoa)
table.insert(TianjinQinhuangdaob.connections, TianjinQinhuangdaoc)
table.insert(TianjinQinhuangdaoc.connections, TianjinQinhuangdaob)
table.insert(TianjinQinhuangdaoc.connections, Qinhuangdao)

table.insert(DalianDandong.connections, Dandong)
table.insert(DalianDandong.connections, LaotieshanEW)
table.insert(DalianDandong.connections, ChengshanCapeTSSNS)
table.insert(QinhuangdaoLaotieshan.connections, Qinhuangdao)
table.insert(QinhuangdaoLaotieshan.connections, LaotieshanChannelTSS)
table.insert(NorthernBohaiSea.connections, Yingkou)
table.insert(NorthernBohaiSea.connections, LaotieshanChannelNorthernBohaiSea)
table.insert(LaotieshanChannelNorthernBohaiSea.connections, NorthernBohaiSea)
table.insert(LaotieshanChannelNorthernBohaiSea.connections, LaotieshanChannelTSS)
table.insert(LaotieshanChannelNorthernBohaiSea.connections, Qinhuangdao)
 
table.insert(ChengshanCapeTSSNS.connections, SCS)
table.insert(ChengshanCapeTSSSN.connections, LaotieshanEW)
table.insert(ChengshanCapeTSSSN.connections, Dalian)
table.insert(ChengshanCapeTSSSN.connections, DalianDandong) 
table.insert(ChengshanCapeTSSSN.connections, ChangshanChannelTSSEW)

table.insert(YellowSea.connections, SCS)
table.insert(YellowSea.connections, DalianDandong)
table.insert(DalianDandong.connections, YellowSea)

traffic = Traffic.new({Qinhuangdao, Dandong, Yingkou, Tianjin, Dalian, SCS})