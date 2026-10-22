local root = assert(os.getenv("SOLIUM_SURFACE_ROOT"), "SOLIUM_SURFACE_ROOT is required")
package.path = root .. "/mobile/lua/?.lua;" .. root .. "/share/solium/lua/?.lua;" .. package.path
local mobile = dofile(root .. "/mobile/lua/mobile.lua")
if os.getenv("SOLIUM_MOBILE_FINGER") == "1" then
    sol.surface("touch-finger", {scene="mobile/Finger.qml",layer="overlay",on="primary",interactive=false,
        properties={down=false,phase="ready"}})
end
local active = {}
sol.on("touch", function(e)
    if e.kind == "down" then active[e.slot] = true end
    local count = 0
    for _ in pairs(active) do count = count + 1 end
    sol.log(string.format("SURFACE_TOUCH kind=%s slot=%d x=%.2f y=%.2f target=%s control=%s window=%s time=%d active=%d",
        e.kind,e.slot,e.x,e.y,e.target,tostring(e.control),tostring(e.window),e.time,count))
    if e.kind == "up" or e.kind == "cancel" then active[e.slot] = nil end
end)
return mobile
