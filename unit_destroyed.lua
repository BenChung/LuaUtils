local unit = ScenEdit_UnitX()
if unit.destroyed ~= nil then
unit:destroyed()
end

if unit.behaviour ~= nil and unit.behaviour.destroyed_handler ~= nil then
unit.behaviour.destroyed_handler(unit)
end