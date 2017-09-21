--LogLevels - Dirtyredz|David McClain
package.path = package.path .. ";mods/LogLevels/scripts/lib/?.lua"
require("PrintLog")
local logLevels = require("LogLevels")

local closestPos
local closestDir
local dockingCache = false
local oldPosition


dockStage = 0

function getSqDistance(pointA,pointB)
    local dX = pointA.x - pointB.x
    local dY = pointA.y - pointB.y
    local dZ = pointA.z - pointB.z
    return dX*dX + dY*dY + dZ*dZ
end

function getNearestDockingPosition(ship,station)


	local docks = {station:getDockingPositions()}

	-- check if cached dock still exists
    if dockingCache == true then
		dockingCache = false
		local ai = ShipAI(ship.index)
		for i=1,#docks,2 do
			mypos = docks[i]
			if mypos.x == closestPos.x and mypos.y == closestPos.y and mypos.z == closestPos.z then
				dockingCache = true
				break
			end
		end
		if dockingCache == false then 
			ai:setPassive()
			dockStage = 0 
		end
		
		oldPosition = oldPosition or stationPosition.pos
		local newPosition = stationPosition.pos
		if  newPosition.x ~= oldPosition.x or newPosition.y ~= oldPosition.y or newPosition.z ~= oldPosition.z then
			print("STATION MOVED: "..tostring(newPosition).." and old: "..tostring(oldPosition), logLevels.debug)
			oldPosition = newPosition
			ai:setPassive()
		end

					
    end

	if dockingCache == false then
		local closestSqDist = -1.0
		local shipPos = cache.boundingSphere.center
		local stationPosition = station.position
		local currDist
		local mypos
		local mydir
		local i
		for i=1,#docks,2 do
			mypos = docks[i]
			mydir = docks[i+1]
			currDist = getSqDistance(shipPos,stationPosition:transformCoord(mypos + mydir * config.LandingStripDistance))
			if closestSqDist == -1.0 or currDist < closestSqDist then
				closestPos = mypos
				closestDir = mydir
				closestSqDist = currDist
			end
		end
		dockingCache = true
    end
    return closestPos, closestDir
end

function flyToDock(ship, station)
    dockStage = dockStage or 0
	local ai = ShipAI(ship.index)
	if dockStage == 0 then
		print("Approaching", logLevels.debug)
		local target = cache.landingStripPosition
		if ai.state ~= AIState.Fly then
			ai:setFly(target, 0)
		end
		local dist = distance(target, cache.boundingSphere.center)
		-- once the ship is in the light line, fly towards the dock
		if dist < cache.boundingSphere.radius * 2.0 then
			ai:setPassive()
			dockStage = 1
			print("Switching To Docking Mode", logLevels.debug)
		end
	end
	-- stage 1 is flying towards the dock inside the light-line
	if dockStage == 1 then
	print("Docking", logLevels.debug)
	-- don't just use the Z-axis for calculation, as there are ships that are wider than long and might bump into the station while turning
		if ai.state ~= AIState.Fly then
			ai:setFly(cache.dockPosition, 0)
		end
		if station:getNearestDistance(ship) < cache.boundingSphere.radius * 2.0 then
			ai:setPassive()
			print("Docked", logLevels.debug)
			return true

		end
	end
	return false
end
