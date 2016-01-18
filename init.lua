package.path = "C:\\Users\\Ben Chung\\AppData\\Roaming\\LuaRocks\\share\\lua\\5.2\\?.lua;C:\\Users\\Ben Chung\\AppData\\Roaming\\LuaRocks\\share\\lua\\5.2\\?\\init.lua"
package.cpath = "C:\\Users\\Ben Chung\\AppData\\Roaming\\LuaRocks\\lib\\lua\\5.2\\?.dll"

local debug = require('mobdebug')
debug.start("localhost")
debug.checkcount = 1
debug.verbose = true
debug.coro()

load_file("D:\\CMANO-Reinst\\Lua\\TamKung\\math.lua")
load_file("D:\\CMANO-Reinst\\Lua\\TamKung\\keystore.lua")
load_file("D:\\CMANO-Reinst\\Lua\\TamKung\\sceneutils.lua")
load_file("D:\\CMANO-Reinst\\Lua\\TamKung\\traffic.lua")
load_file("D:\\CMANO-Reinst\\Lua\\TamKung\\strings.lua")
load_file("D:\\CMANO-Reinst\\Lua\\TamKung\\inittk.lua")
