--[[ Calculator Module
by ototperks
Adds some buttons to help with calculations during combat
]] pID = "Calculator_Module"
UPDATE_URL = 'https://raw.githubusercontent.com/jordanpg/Tabletop-Simulator-Scripts/master/Magic/CalculatorModule.lua'
version = '1.0.0'
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
            tooltip = "Calculate Total Power/Toughness"
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
    log(player.steam_name)
    local result = getSelectedPT(player)
    if result == nil then
        return
    end
    broadcastToColor(string.format("[FF4242]Power[-]:            %d\n[6A8EAE]Toughness[-]:     %d", result.power, result.toughness), player.color, { r=255, g=255, b=255 })
end

function getSelectedPT(player)
    local selections = player.getSelectedObjects()
    local result = { power=0, toughness=0 }

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
                -- Get base P/T plus +1/+1 counters and any manual modifications
                local ourPower = (tonumber(data.cardFaces[data.activeFace].basePower or "0") or 0)
                    + data.power
                    + data.plusOneCounters
                local ourToughness = (tonumber(data.cardFaces[data.activeFace].baseToughness or "0") or 0)
                    + data.toughness
                    + data.plusOneCounters
                -- Find keywords that will affect P/T
                local kws = data.cardFaces[data.activeFace].keywords or {}
                for i, v in ipairs(kws) do
                    if v:find("ouble strike") then
                        ourPower = ourPower * 2
                    end
                end
                -- Add to sum
                result.power = result.power + ourPower
                result.toughness = result.toughness + ourToughness
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