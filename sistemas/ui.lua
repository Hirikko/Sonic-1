local UI = {}
local BTN = require("btn")
local Sprites = require("sistemas.sprites")

local titulo_frame = 1
local titulo_timer = 0
local TITULO_CADENCIA = 18

local botao_frame = 1
local botao_timer = 0
local BOTAO_CADENCIA = 30

-- Caches de texto do HUD (evita concatenação a cada frame)
local cache_score = { valor = -1, texto = "SCORE: 0" }
local cache_aneis = { valor = -1, texto = "Aneis: 0" }
local cache_vidas = { valor = -1, texto = "Vidas: 0" }

local function print_cached(cache, valor, prefixo, x, y, cor)
    if valor ~= cache.valor then
        cache.valor = valor
        cache.texto = prefixo .. tostring(valor)
    end
    ui.print(cache.texto, x, y, cor)
end

local function animar_titulo()
    titulo_timer = titulo_timer + 1
    if titulo_timer >= TITULO_CADENCIA then
        titulo_timer = 0
        titulo_frame = titulo_frame + 1
        if titulo_frame > 2 then titulo_frame = 1 end
    end
    return titulo_frame
end

local function animar_botao()
    botao_timer = botao_timer + 1
    if botao_timer >= BOTAO_CADENCIA then
        botao_timer = 0
        botao_frame = (botao_frame == 1) and 2 or 1
    end
    return botao_frame
end

local function desenhar_informacoes(state)
    print_cached(cache_score, state.pontuacao or 0, "SCORE: ", 10, 10, 7)
    print_cached(cache_aneis, state.inventory.aneis or 0, "Aneis: ", 10, 30, 38)
    print_cached(cache_vidas, state.vidas or 0, "Vidas: ", 10, 40, 7)

    if state.buffs and state.buffs.invencivel > 0 then
        ui.print("INVENCIVEL", 10, 60, 12)
    end
    if state.buffs and state.buffs.velocidade_extra > 0 then
        ui.print("SPEED UP", 10, 70, 10)
    end
end

local function desenhar_titulo()
    ui.rectfill(0, 0, 480, 270, 0)
    local frame = animar_titulo()
    local sprite = Sprites.sprite("titulo", frame)

    local base_y = 200

    if sprite then
        local w = sprite.width or 256
        local h = sprite.height or 128
        ui.spr(sprite, math.floor((480 - w) / 2), math.floor(base_y - h), false, false)
    else
        ui.print("Sonic SMS", 175, 90, 17)
        ui.print("LUPINHO", 200, 120, 21)
    end

    local b_frame = animar_botao()
    local botao_sprite = Sprites.sprite("titulo_botao", 1)

    if botao_sprite and b_frame == 1 then
        local w = botao_sprite.width or 64
        ui.spr(botao_sprite, math.floor((480 - w) / 2), base_y + 10, false, false)
    elseif b_frame == 1 then
        ui.rectfill(180, base_y + 10, 300, base_y + 30, 12)
        ui.print("BOTAO", 210, base_y + 15, 0)
    end
end

local function desenhar_stage_preview(state)
    ui.rectfill(0, 0, 480, 270, 0)
    ui.print("PROXIMA FASE", 160, 40, 7)
    local stage = state.stages[state.stage_atual]
    if stage then
        ui.print(stage.nome .. " ACT " .. tostring(state.ato_atual), 170, 120, 10)
    end

    local Mapa = require("mapa")
    if Mapa.carregando then
        ui.print("CARREGANDO...", 185, 220, 12)
    else
        ui.print("PRESSIONE A", 175, 220, 10)
    end
end

local function desenhar_stage_select(state)
    ui.rectfill(0, 0, 480, 270, 0)
    ui.print("ESCOLHE FASE", 160, 20, 7)
    ui.print("UP/DOWN: navegar", 160, 40, 7)
    ui.print("Z: confirmar", 160, 52, 7)

    if state.stages then
        for i, stage in ipairs(state.stages) do
            local cor = (i == state.stage_atual) and 10 or 7
            local prefixo = (i == state.stage_atual) and "> " or "  "
            ui.print(prefixo .. stage.nome, 120, 90 + (i - 1) * 20, cor)
        end
    end
    ui.print("PRESSIONE Z", 175, 240, 10)
end

local function desenhar_vitoria(state)
    ui.rectfill(0, 0, 480, 270, 0)
    local stage = state.stages[state.stage_atual]
    local nome_zona = stage and stage.nome or "ZONE"

    ui.print(nome_zona .. " ZONE", 140, 30, 10)
    ui.print("ACT " .. tostring(state.ato_atual) .. " CLEAR", 170, 50, 7)
    ui.line(100, 70, 380, 70, 7)

    ui.print("SCORE", 100, 90, 7)
    ui.print("TIME", 250, 90, 7)
    ui.print("RINGS", 350, 90, 7)

    local tempo_str = string.format("%d:%02d", math.floor((state.tempo_final or 0) / 60), (state.tempo_final or 0) % 60)

    ui.print(tostring(state.pontuacao or 0), 100, 110, 10)
    ui.print(tempo_str, 250, 110, 10)
    ui.print(tostring(state.inventory.aneis), 350, 110, 10)

    ui.print("RING BONUS", 100, 140, 7)
    ui.print("TIME BONUS", 250, 140, 7)
    ui.print(tostring(state.bonus_aneis or 0), 100, 160, 10)
    ui.print(tostring(state.bonus_tempo or 0), 250, 160, 10)

    ui.print("PRESSIONE A", 175, 230, 10)
end

local function desenhar_game_over(state)
    ui.rectfill(0, 0, 480, 270, 0)
    ui.print("GAME OVER", 170, 100, 12)
    ui.print("PRESSIONE A", 175, 160, 7)
end

function UI.draw_hud(state)
    assert(state, "UI.draw_hud requer state")
    assert(state.inventory, "UI.draw_hud requer state.inventory")

    if state.current_scene == state.SCREEN_TITLE then
        desenhar_titulo()
        return
    elseif state.current_scene == state.SCREEN_STAGE_PREVIEW then
        desenhar_stage_preview(state)
        return
    elseif state.current_scene == state.SCREEN_STAGE_SELECT then
        desenhar_stage_select(state)
        return
    elseif state.current_scene == state.SCREEN_VICTORY then
        desenhar_vitoria(state)
        return
    elseif state.current_scene == state.SCREEN_GAME_OVER then
        desenhar_game_over()
        return
    end

    desenhar_informacoes(state)
    -- REMOVIDO: prints de debug "X:..." e "Y:..." que apareciam na tela
end

return UI
