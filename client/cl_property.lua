---@diagnostic disable: duplicate-set-field
Property = {
    inShell = false,
    has_access = false,
    isOwner = false,
    shellObj = nil,
    shellData = nil,
    property_id = nil,
    propertyData = nil,
    furnitureObjs = {},
    garageZone = nil,
    doorbellPool = {},

    CreateShell = function (self)
        local ped = PlayerPedId()
        local coords = self.propertyData.door_data
        local modelHash = self.shellData.hash
        RequestModel(modelHash)
        while not HasModelLoaded(modelHash) do Wait(0) end
        self.shellObj = CreateObject(modelHash, coords.x, coords.y, coords.z - 50.0, false, false, false)
        SetModelAsNoLongerNeeded(modelHash)
        FreezeEntityPosition(self.shellObj, true)
        local doorOffset = self.shellData.doorOffset
        local offset = GetOffsetFromEntityInWorldCoords(self.shellObj, doorOffset.x, doorOffset.y, doorOffset.z)
        self:RegisterDoorZone(offset)
        SetEntityCoordsNoOffset(ped, offset.x, offset.y, offset.z, false, false, true)
        SetEntityHeading(ped, self.shellData.doorOffset.heading)
    end,

    RegisterDoorZone = function(self, offset)
        exports['qb-target']:AddBoxZone("shellExit", vector3(offset.x, offset.y, offset.z),  1.0, self.shellData.doorOffset.width, {
            name="shellExit",
            heading= self.shellData.doorOffset.heading,
            debugPoly=Config.DebugPoly,
            minZ=offset.z-2.0,
            maxZ=offset.z+1.0,
        }, {
            options = {
                {
                    label = 'Leave Property',
                    action = function(entity) -- This is the action it has to perform, this REPLACES the event and this is OPTIONAL
                        if IsPedAPlayer(entity) then return false end -- This will return false if the entity interacted with is a player and otherwise returns true
                        self:LeaveShell()
                    end,
                },
                {
                    label = "Check Door",
                    action = function(entity)
                        if IsPedAPlayer(entity) then return false end
                        self:OpenDoorbellMenu()
                    end
                }
            }
        })
    end,

    RegisterPropertyEntrance = function (self)
        local door_data = self.propertyData.door_data
        local targetname = string.gsub(self.propertyData.label, "%s+", "")..tostring(self.propertyData.property_id)
        local label = self.has_access and 'Enter Property' or 'Ring Doorbell'
        exports['qb-target']:AddBoxZone(targetname, vector3(door_data.x, door_data.y, door_data.z), door_data.length, door_data.width, {
            name=targetname,
            heading=door_data.h,
            debugPoly=true,
            minZ=door_data.z - 1.0,
            maxZ=door_data.z + 2.0,
        }, {
            options = {
                {
                    label = label,
                    action = function(entity) -- This is the action it has to perform, this REPLACES the event and this is OPTIONAL
                        if IsPedAPlayer(entity) then return false end -- This will return false if the entity interacted with is a player and otherwise returns true
                        TriggerServerEvent('ps-housing:server:enterProperty', self.propertyData.property_id)
                    end,
                }
            }
        })
    end,

    -- QBCORE Did house garages the shittiest way possible so I did my own version of it. Might not be a very framework friendly decision but fuck qb
    RegisterGarageZone = function (self)
        if not self.propertyData.garage_data.x then return end
        local garageData = self.propertyData.garage_data
        local garageName = "propert"..self.property_id.."garage"
        self.garageZone = BoxZone:Create(vector3(garageData.x, garageData.y, garageData.z), garageData.length, garageData.width, {
            name=garageName,
            debugPoly=Config.DebugPoly,
        })
        self.garageZone:onPlayerInOut(function(isPointInside, point)
            if isPointInside then
                exports['qb-radialmenu']:AddOption({
                    id = garageName,
                    title = "Open Property Garage",
                    icon = "warehouse",
                    type = "server",
                    event = "ps-housing:client:handlerGarage",
                    garage = garageName,
                    shouldClose = true,
                }, garageName)
            else
                exports['qb-radialmenu']:RemoveOption(garageName)
            end
        end)
    end,

    EnterShell = function(self)
        self.inShell = true
        self.shellData = Config.Shells[self.propertyData.shell]
        self:CreateShell()
        exports['qb-radialmenu']:AddOption({
            id = "furnituremenu",
            title = "Furniture Menu",
            icon = "house",
            type = "client",
            event = "ps-housing:client:furnitureMenu",
            shouldClose = true,
        }, "furnituremenu")
    end,

    LeaveShell = function(self)
        if not self.inShell then return end
        local ped = PlayerPedId()
        local coords = self.propertyData.door_data
        SetEntityCoordsNoOffset(ped, coords.x, coords.y, coords.z, false, false, true)
        exports['qb-target']:RemoveZone("shellExit")
        exports['qb-radialmenu']:RemoveOption("furnituremenu")
        self.garageZone:destroy()
        TriggerServerEvent("ps-housing:server:leaveShell", self.property_id)
        self.inShell = false
        self:UnloadFurnitures()
        DeleteObject(self.shellObj)
        self.shellObj = nil
        self.shellData = nil
    end,

    OpenDoorbellMenu = function (self)
        local menu = {}
        table.insert(menu,
        {
            header = 'People at the door',
            icon = 'fas fa-door',
            isMenuHeader = true,
        })
        for k, v in pairs(self.doorbellPool) do
            table.insert(menu,{
                header = GetPlayerName(k),
                params = {
                    event = "ps-housing:server:doorbellAnswer",
                    args = {
                        targetSrc = k,
                        property_id = self.property_id,
                    },
                }
            })
        end
        exports['qb-menu']:openMenu(menu)
    end,

    LoadFurnitures = function(self)
        for i = 1, #self.propertyData.furnitures do
            local v = self.propertyData.furnitures[i]
            local coords = GetOffsetFromEntityInWorldCoords(self.shellObj, v.position.x, v.position.y, v.position.z)
            local hash = v.object
            while not HasModelLoaded(hash) do Wait(0) end
            local object = CreateObject(hash, coords.x, coords.y, coords.z, false, true, false)
            SetModelAsNoLongerNeeded(hash)
            SetEntityRotation(object, v.rotation.x, v.rotation.y, v.rotation.z, 2, true)
            FreezeEntityPosition(object, true)
            self.furnitureObjs[#self.furnitureObjs + 1] = object
        end
    end,

    UnloadFurnitures = function(self)
        for i = 1, #self.furnitureObjs do
            DeleteObject(self.furnitureObjs[i])
        end
        self.furnitureObjs = {}
    end,

    DeleteProperty = function(self)
        local targetname = string.gsub(self.propertyData.label, "%s+", "")..tostring(self.property_id)
        exports['qb-target']:RemoveZone(targetname)
        if self.inShell then self:LeaveShell() end
    end,
}


function Property:new(propertyData)
    local obj = {}
    obj.property_id = propertyData.property_id
    obj.propertyData = propertyData
    local isOwner = false
    local has_access = false
    local Player = QBCore.Functions.GetPlayerData()
    local citizenid = Player.citizenid
    if propertyData.owner == citizenid then
        isOwner = true
    end
    for i = 1, #propertyData.has_access do
        if propertyData.has_access[i] == citizenid then
            has_access = true
            break
        end
    end
    obj.isOwner = isOwner
    obj.has_access = has_access
    setmetatable(obj, self)
    self.__index = self
    obj:RegisterPropertyEntrance()
    obj:RegisterGarageZone()
    return obj
end

RegisterNetEvent("ps-housing:client:enterProperty", function(property_id)
    local property = PropertiesTable[property_id]
    property:EnterShell()
end)

RegisterNetEvent("ps-housing:client:updateDoorbellPool", function(property_id, data)
    local property = PropertiesTable[property_id]
    property.doorbellPool = data
end)

RegisterNetEvent("ps-housing:client:updateProperty", function(propertyData)
    local property_id = propertyData.property_id
    local property = PropertiesTable[property_id]
    property.propertyData = propertyData
    if property.inShell then
        property:LeaveShell()
    end
    property:DeleteProperty()
    property = nil
    PropertiesTable[property_id] = Property:new(propertyData)
end)
