local Aneis = {}
local Sprites = require("sistemas.sprites")
local State   = require("state")
local Mapa    = require("mapa")

local TEMPO_ANIMACAO = 10
local RAIO_COLETA = 12
local TEMPO_COLETA = 8
local TEMPO_ESPALHADO = 240
local GRAVIDADE_ANEL = 0.4

-- NOVO: cache de sprite por frame (frames 1-7)
local cache_anel = {}
local cache_anel_coleta = nil

local function sprite_anel(frame)
    local s = cache_anel[frame]
    if s then return s end
    s = Sprites.sprite("aneis", frame)
    if s then cache_anel[frame] = s end
    return s
end

local function sprite_anel_coleta()
    if cache_anel_coleta then return cache_anel_coleta end
    cache_anel_coleta = Sprites.sprite("aneis", 7)
    return cache_anel_coleta
end

function Aneis.init(dados_terreno)
    Aneis.lista = {}
    Aneis.espalhados = {}
    Aneis.frame = 1
    Aneis.timer = 0

    cache_anel = {}
    cache_anel_coleta = nil

    if dados_terreno and dados_terreno.aneis then
        for _, anel in ipairs(dados_terreno.aneis) do
            table.insert(Aneis.lista, { x = anel.x, y = anel.y, coletado = false, timer_coleta = 0 })
        end
    end
end

function Aneis.espalhar_aneis(x, y, quantidade)
    for i = 1, quantidade do
        local angulo = (i / quantidade) * math.pi * 2
        local vx = math.cos(angulo) * 3
        local vy = math.sin(angulo) * 3 - 3
        table.insert(Aneis.espalhados, {
            x = x, y = y, vx = vx, vy = vy,
            timer = TEMPO_ESPALHADO,
            coletado = false,
            timer_coleta = 0,
            frame_par = 0,  -- NOVO: contador para espaçar checks de chão
        })
    end
end

function Aneis.update(player)
    Aneis.timer = Aneis.timer + 1
    if Aneis.timer >= TEMPO_ANIMACAO then
        Aneis.timer = 0
        Aneis.frame = Aneis.frame + 1
        if Aneis.frame > 6 then Aneis.frame = 1 end
    end

    local px = player.x
    local py = player.y + 16

    for _, anel in ipairs(Aneis.lista) do
        if anel.coletado then
            if anel.timer_coleta > 0 then anel.timer_coleta = anel.timer_coleta - 1 end
        else
            local dx = px - anel.x
            local dy = py - anel.y
            if (dx * dx + dy * dy) < (RAIO_COLETA * RAIO_COLETA) then
                anel.coletado = true
                anel.timer_coleta = TEMPO_COLETA
                State.inventory.aneis = State.inventory.aneis + 1
            end
        end
    end

    for i = #Aneis.espalhados, 1, -1 do
        local anel = Aneis.espalhados[i]
        if anel.coletado then
            anel.timer_coleta = anel.timer_coleta - 1
            if anel.timer_coleta <= 0 then table.remove(Aneis.espalhados, i) end
        else
            anel.vy = anel.vy + GRAVIDADE_ANEL
            anel.x = anel.x + anel.vx
            anel.y = anel.y + anel.vy
            anel.vx = anel.vx * 0.98

            -- NOVO: checa chão a cada 2 frames por anel (spread temporal)
            anel.frame_par = anel.frame_par + 1
            if anel.frame_par >= 2 then
                anel.frame_par = 0
                local chao = Mapa.altura_suporte(anel.x, anel.y + 8)
                if chao and anel.y + 8 >= chao then
                    anel.y = chao - 8
                    anel.vy = -anel.vy * 0.5
                    if math.abs(anel.vy) < 1 then anel.vy = 0 end
                    anel.vx = anel.vx * 0.9
                end
            end

            anel.timer = anel.timer - 1
            if anel.timer <= 0 then
                table.remove(Aneis.espalhados, i)
            else
                local dx = px - anel.x
                local dy = py - anel.y
                if (dx * dx + dy * dy) < (RAIO_COLETA * RAIO_COLETA) then
                    anel.coletado = true
                    anel.timer_coleta = TEMPO_COLETA
                    State.inventory.aneis = State.inventory.aneis + 1
                end
            end
        end
    end
end

function Aneis.draw(cam_x, cam_y)
    if Aneis.lista then
        for _, anel in ipairs(Aneis.lista) do
            local sprite
            if anel.coletado then
                if anel.timer_coleta > 0 then sprite = sprite_anel_coleta() end
            else
                sprite = sprite_anel(Aneis.frame)
            end
            if sprite then
                local largura = sprite.width or 16
                local altura = sprite.height or 16
                ui.spr(sprite, math.floor(anel.x - cam_x - largura / 2), math.floor(anel.y - cam_y - altura / 2), false, false)
            end
        end
    end
    if Aneis.espalhados then
        for _, anel in ipairs(Aneis.espalhados) do
            local sprite
            if anel.coletado then sprite = sprite_anel_coleta() else sprite = sprite_anel(Aneis.frame) end
            if sprite then
                local largura = sprite.width or 16
                local altura = sprite.height or 16
                local visivel = true
                if anel.timer < 60 and anel.timer % 10 < 5 then visivel = false end
                if visivel then
                    ui.spr(sprite, math.floor(anel.x - cam_x - largura / 2), math.floor(anel.y - cam_y - altura / 2), false, false)
                end
            end
        end
    end
end

return Aneis
