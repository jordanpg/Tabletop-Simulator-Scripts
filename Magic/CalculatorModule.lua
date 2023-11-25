--[[ Calculator Module
by ototperks
Adds some buttons to help with calculations during combat
]] pID = "Calculator_Module"
UPDATE_URL = 'https://raw.githubusercontent.com/jordanpg/Tabletop-Simulator-Scripts/master/Magic/CalculatorModule.lua'
version = '1.2.0'
Style = {}
UiId = "calculator-buttons"
Ui = {
    attributes = {
        childAlignment = "MiddleRight",
        height = "50",
        offsetXY = "-6 0",
        rectAlignment = "MiddleRight",
        width = "50",
        id = UiId
    },
    children = {{
        attributes = {},
        children = {{
            attributes = {
                colors = "#282828|#E18D15|#8E8E8E|#8E8E8E",
                iconColor = "#F0F0F0",
                tooltipBackgroundColor = "#151515C8",
                tooltipBorderColor = "#000000",
                tooltipPosition = "Left",
                tooltipTextColor = "#FFFFFF"
            },
            children = {},
            tag = "Button"
        }},
        tag = "Defaults"
    }, {
        attributes = {
            icon = "CombatIcon",
            onClick = self.guid .. "/uiCalculateCombat",
            tooltip = "Calculate Combat"
        },
        children = {},
        tag = "Button"
    }},
    tag = "VerticalLayout"
}

function onload()
    Wait.condition(addGlobalUi, function()
        return not UI.loading
    end)
    Wait.condition(registerModule, function()
        return Global.getVar('Encoder') ~= nil and true or false
    end)
end

function registerModule()
    enc = Global.getVar('Encoder')
    if enc ~= nil then
        properties = {
            propID = pID,
            name = "Calculator Module",
            values = {},
            funcOwner = self,
            activateFunc = '',
            tags = "tool",
            visible = false
        }
        enc.call("APIregisterProperty", properties)
    end
end

function addGlobalUi()
    log("Adding calculator buttons to UI...")

    local curr = UI.getXmlTable() or {}
    -- Remove the existing UI
    filter_inplace(curr, function(elem)
        return elem.attributes.id ~= UiId
    end)
    -- Add new UI
    table.insert(curr, Ui)

    UI.setXmlTable(curr)
end

function uiCalculateCombat(player)
    local result = calculateCombat(player)
    if result == nil then
        return
    end

    local sumPower = result.power + result.fs + result.last
    
    if result.fs > 0 or result.last > 0 then
        player.broadcast(string.format("[909CC2]Phases[-]: first %d | %d%s", result.fs, result.power, result.last > 0 and string.format(" | %d last", result.last) or ""))
    end
    
    if result.lifelink > 0 then
        player.broadcast(string.format("[F7F5FB]Lifelink[-]: %d", result.lifelink))
    end
    
    if result.reach.power > 0 or result.reach.toughness > 0 then
        player.broadcast(string.format("[04724D]Reach[-]: %d power / %d toughness", result.reach.power, result.reach.toughness))
    end
    if result.flying.power > 0 or result.flying.toughness > 0 then
        player.broadcast(string.format("[CDE6F5]Flying[-]: %d power / %d toughness", result.flying.power, result.flying.toughness))
    end

    player.broadcast(string.format("[084887]Toughness[-]: %d", result.toughness))
    player.broadcast(string.format("[F58A07]Power[-]: %d", sumPower))
end

function calculateCombat(player)
    local selections = player.getSelectedObjects()
    local result = {
        power = 0,
        toughness = 0,
        fs = 0,
        last = 0,
        lifelink = 0,
        reach = { power = 0, toughness = 0 },
        flying = { power = 0, toughness = 0 }
    }

    if selections == nil or #selections == 0 then
        return nil
    end

    enc = Global.getVar('Encoder')
    if enc ~= nil then
        for i, t in ipairs(selections) do
            if enc.call("APIobjectExists", { obj=t }) then
                -- Get encoder data
                local encData = enc.call("APIobjGetPropData", {
                    obj = t,
                    propID = "_MTG_Simplified_UNIFIED"
                })
                local data = encData["tyrantUnified"]
                Notes.addNotebookTab({ title="data_" .. t.getGUID(), body=JSON.encode_pretty(data) })
                
                -- Set up variables, pull from data
                local ourPower = (tonumber(data.cardFaces[data.activeFace].basePower or "0") or 0)
                    + data.power
                    + data.plusOneCounters
                local ourFSPower = 0
                local ourLSPower = 0
                local ourToughness = (tonumber(data.cardFaces[data.activeFace].baseToughness or "0") or 0)
                    + data.toughness
                    + data.plusOneCounters
                local lifelink = false
                local reach = false
                local flying = false
                local kws = data.cardFaces[data.activeFace].keywords or {}
                
                -- Find notable keywords
                for i, v in ipairs(kws) do
                    -- Handle first strike damage
                    if v:find("ouble strike") then
                        ourFSPower = ourFSPower + ourPower
                    elseif v:find("irst strike") then
                        -- For first strike, we only have FS damage, so set regular power to 0
                        ourFSPower = ourPower
                        ourPower = 0
                    end
                    
                    -- Handle last strike damage
                    if v:find("riple strike") then
                        ourFSPower = ourFSPower + ourPower
                        ourLSPower = ourLSPower + ourPower
                    elseif v:find("ast strike") then
                        ourLSPower = ourPower
                        ourPower = 0
                    end

                    -- Lifelink
                    if v:find("ifelink") then
                        lifelink = true
                    end

                    -- Reach
                    if v:find("Reach") then
                        reach = true
                    end

                    -- Flying
                    if v:find("lying") then
                        flying = true
                    end
                end

                -- Add to result
                local sumPower = ourPower + ourFSPower + ourLSPower
                result.power = result.power + ourPower
                result.fs = result.fs + ourFSPower
                result.last = result.last + ourLSPower
                result.toughness = result.toughness + ourToughness
                result.lifelink = result.lifelink + (lifelink and sumPower or 0)
                result.reach.power = result.reach.power + (reach and sumPower or 0)
                result.reach.toughness = result.reach.toughness + (reach and ourToughness or 0)
                result.flying.power = result.flying.power + (flying and sumPower or 0)
                result.flying.toughness = result.flying.toughness + (flying and ourToughness or 0)
            end
        end
    end

    return result
end

function updateModule(wr)
    enc = Global.getVar('Encoder')
    if enc ~= nil then
        wr = wr.text
        wrv = string.match(wr, "version = '(.-)'")
        if wrv == 'DEPRECIATED' then
            enc.call("APIremoveProperty", {
                propID = pID
            })
            self.destruct()
        end
        local ver = enc.call("APIversionComp", {
            wv = wrv,
            cv = version
        })
        if '' .. ver ~= '' .. version then
            broadcastToAll("An update has been found for " .. pID .. ". Reloading Module.")
            self.script_code = wr
            self.reload()
        else
            broadcastToAll("No update found for " .. pID .. ". Carry on.")
        end
    end
end

function filter_inplace(arr, func)
    local new_index = 1
    local size_orig = #arr
    for old_index, v in ipairs(arr) do
        if func(v, old_index) then
            arr[new_index] = v
            new_index = new_index + 1
        end
    end
    for i = new_index, size_orig do
        arr[i] = nil
    end
end
