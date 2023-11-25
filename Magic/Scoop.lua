function onload()
    self.createButton({
        label = "Scoop",
        click_function = "scoop",
        function_owner = self,
        position = {0, 0.1, 0},
        rotation = {0, 0, 0},
        height = 900,
        width = 600,
        font_size = 160
    })
end

function scoop(obj, ply)
    if ply ~= self.getName() then
        return
    end

    local enc = Global.getVar('Encoder')

    local rot = Player[ply].getHandTransform().rotation
    local grp = nil
    for i, v in pairs(getObjectFromGUID(self.getDescription()).getObjects()) do
        local skip = false
        if v.tag == "Card" or v.tag == "Deck" then

            if enc ~= nil and enc.call("APIobjectExists", {
                obj = v
            }) then
                data = enc.call("APIobjGetAllData", {
                    obj = v
                })
                if data["mtg_token"] then
                    skip = true
                end
            end

            if not skip then
                if grp == nil then
                    grp = v
                elseif grp.getQuantity() < v.getQuantity() then
                    v.putObject(grp)
                    grp = v
                end
                if grp ~= v then
                    grp.putObject(v)
                end
            end
        end
    end

    if grp ~= nil then
        for i, v in pairs(Player[ply].getHandObjects()) do
            if v.tag == "Card" or v.tag == "Deck" then
                grp.putObject(v)
            end
        end

        grp.shuffle()

        --   Remove tokens from group
        local pos = grp.getPosition()
        local rot = grp.getRotation()
        pos:add(Vector(0, 2, 0))
        rot:add(Vector(0, 90, 0))

        for _, t in ipairs(grp.getObjects()) do
            if t.name:find("\nToken") or t.name:find("\nEmblem") then
                grp.takeObject({
                    guid = t.guid,
                    flip = true,
                    position = pos,
                    rotation = rot
                })
            end
        end

        grp.shuffle()
    end
end
