
function updateServer()

end

dockStage = 0

function flyToDock(ship, station)

    dockStage = dockStage or 0

    local pos, dir = station:getDockingPositions()
    local ai = ShipAI(ship.index)

    if dockStage == 0 then
        local target = station.position:transformCoord(pos + dir * 250)

        if ai.state ~= AIState.Fly then
            ai:setFly(target, 0)
        end

        local dist = distance(target, ship:getBoundingSphere().center)

        -- once the ship is in the light line, fly towards the dock
        if dist < ship:getBoundingSphere().radius * 2.0 then
            dockStage = 1
        end
    end

    -- stage 1 is flying towards the dock inside the light-line
    if dockStage == 1 then
        local dock = station.position:transformCoord(pos + dir * ship:getBoundingBox().size.z * 0.5)
        ai:setFlyLinear(dock, 0)

        local v = Velocity(ship.index)
        if v.linear2 <= 0.01 then
            dockStage = 2
        end
    end

    if dockStage == 2 then
        local dock = station.position:transformCoord(pos + dir)
        ai:setFlyLinear(dock, 0)

        local engine = Engine(ship.index)
        ship.desiredVelocity = (engine.brakeThrust / engine.maxVelocity) * 0.15
    end

    -- once the ship is at the dock, wait
    if station:isDocked(ship) then
        ai:setPassive()
        return true
    end

    return false
end

local success, rtn =  pcall(require, 'mods.BetterDocking.scripts.entity.ai.dock')
if not success then print(rtn) end