local Debug = {}
local Terreno = require("sistemas.terreno")

local function dist_segmento(px, py, x1, y1, x2, y2)
    local l2 = (x2 - x1)^2 + (y2 - y1)^2
    if l2 == 0 then return math.sqrt((px - x1)^2 + (py - y1)^2) end
    local t = ((px - x1) * (x2 - x1) + (py - y1) * (y2 - y1)) / l2
    t = math.max(0, math.min(1, t))
    local proj_x = x1 + t * (x2 - x1)
    local proj_y = y1 + t * (y2 - y1)
    return math.sqrt((px - proj_x)^2 + (py - proj_y)^2)
end

function Debug.draw(cam_x, cam_y, objetos_dinamicos, outros)
    local mx, my = ui.mouse()
    if not mx then return end

    local wx = mx + cam_x
    local wy = my + cam_y

    local info = string.format("Mouse X:%d Y:%d | ", math.floor(wx), math.floor(wy))
    local encontrou = false

    for _, s in ipairs(Terreno.superficies) do
        if dist_segmento(wx, wy, s.pontos[1], s.pontos[2], s.pontos[3], s.pontos[4]) < 8 then
            info = info .. "[Superficie] "
            encontrou = true
            break
        end
    end

    for _, p in ipairs(Terreno.paredes) do
        if math.abs(wx - p.x) < 8 and wy >= p.y1 - 8 and wy <= p.y2 + 8 then
            info = info .. "[Parede] "
            encontrou = true
            break
        end
    end

    for _, d in ipairs(Terreno.danos) do
        if wx >= d.x and wx <= d.x + d.largura and wy >= d.y and wy <= d.y + d.altura then
            info = info .. "[Dano] "
            encontrou = true
            break
        end
    end

    for _, j in ipairs(Terreno.joga) do
        if wx >= j.x and wx <= j.x + j.largura and wy >= j.y and wy <= j.y + j.altura then
            info = info .. "[Gatilho/Mola] "
            encontrou = true
            break
        end
    end

    if objetos_dinamicos then
        for _, p in ipairs(objetos_dinamicos) do
            if math.abs(wx - p.x) < 8 and math.abs(wy - p.y) < 8 then
                info = info .. "[Pendulo Pivo] "
                encontrou = true
            end
            if math.abs(wx - p.x_plataforma) < 20 and math.abs(wy - p.y_plataforma) < 12 then
                info = info .. "[Pendulo Plataforma] "
                encontrou = true
            end
        end
    end

    if outros then
        for _, o in ipairs(outros) do
            -- Se o objeto tiver largura ou altura zero, usa margem de 8px
            local w = o.w > 0 and o.w or 8
            local h = o.h > 0 and o.h or 8
            local ox = o.w > 0 and o.x or o.x - 4
            local oy = o.h > 0 and o.y or o.y - 4

            if wx >= ox and wx <= ox + w and wy >= oy and wy <= oy + h then
                info = info .. "[Outro: " .. o.tipo .. "] "
                encontrou = true
                break
            end
        end
    end

    if not encontrou then info = info .. "Nada encontrado" end

    ui.rectfill(0, 0, 480, 16, 0)
    ui.print(info, 4, 4, 7)
end

return Debug
