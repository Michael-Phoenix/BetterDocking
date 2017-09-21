package.path = package.path .. ";data/scripts/lib/?.lua"
package.path = package.path .. ";data/scripts/entity/?.lua"

require ("ai/dock")
require ("randomext")

local stationIndex
local script
local stage
local waitCount

function getStationIndex()
    return stationIndex
end

function getUpdateInterval()
    return 2
end

function restore(values)
    stationIndex = Uuid(values.stationIndex)
    script = values.script
    stage = values.stage
    waitCount = values.waitCount
    dockStage = values.dockStage
end

function secure()
    return
    {
        stationIndex = stationIndex.string,
        script = script,
        stage = stage,
        waitCount = waitCount,
        dockStage = dockStage,
    }
end

function initialize(stationIndex_in, script_in)
    stationIndex = stationIndex_in
    script = script_in
end

function onTradingFinished(ship)
end

function updateServer(timeStep)

    local ship = Entity()

    local station = Entity(stationIndex)

    -- in case the station doesn't exist any more, leave the sector
    if not station then
        ship:addScript("ai/passsector.lua", random():getDirection() * 2000)
        terminate()
        return
    end

    local pos, dir = station:getDockingPositions()

    -- stages
    if not pos or not dir or not valid(station) then
        -- something is not right, abort
        onTradingFinished(ship)
    else
        stage = stage or 0

        -- stage 0 is flying towards the light-line
        if stage == 0 then
            if flyToDock(ship, station) then
                stage = 2
            end
        end

        -- stage 2 is waiting
        if stage == 2 then
            waitCount = waitCount or 0
            waitCount = waitCount + timeStep

            if waitCount > 40 then -- seconds waiting
                doTransaction(ship, station, script)
                -- fly away
                stage = 3
            end
        end

        -- fly back to the end of the lights
        if stage == 3 then
            local pos, dir = station:getDockingPositions()
            local target = station.position:transformCoord(pos + dir * 300)

            local ai = ShipAI()
            if ai.state ~= AIState.Fly then
                ai:setFlyLinear(target, 0)
            end

            local dist = distance(target, ship:getBoundingSphere().center)

            -- once the ship reached the end of the light line, trading is done
            if dist < ship:getBoundingSphere().radius * 2.0 then
                onTradingFinished(ship)
            end
        end
    end
end

local success, rtn =  pcall(require, 'mods.BetterDocking.scripts.entity.ai.trade')
if not success then print(rtn) end