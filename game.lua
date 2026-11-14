require("palette")
require("sprites")

local Palette = _G.Palette
local State = require("state")
local Audio = require("sistemas.audio")
local Input = require("ui-adapter")
local Camera = require("sistemas.camera")
local Player = require("sistemas.player")
local Animacao = require("sistemas.animacao")
local UI = require("sistemas.ui")
local Mapa = require("mapa")
local Transicao = require("sistemas.transicao")
local Objetos = require("sistemas.objetos")
local Inimigos = require("sistemas.inimigos")
local Aneis = require("sistemas.aneis")
local Timer = require("sistemas.timer")

local COR_CEU = 0x7EA0

--[[
LUPI_HARDWARE_CONSTRAINTS = true
LUPI_LUA_WATCHDOG = true
LUPI_HARDWARE_DEBUG_OVERLAY = true
LUPI_HARDWARE_DEBUG_OVERLAY_RECT = { x0 = 0, y0 = 0, x1 = 164, y1 = 270, col = 2 }
LUPI_HARDWARE_DEBUG_OVERLAY_ALPHA = 0.5
]]--

local function indice_cor(cor)
    if not Palette then return 0 end
    for indice, valor in pairs(Palette) do
        if valor == cor then return indice - 1 end
    end
    return 0
end

-- NOVO: cache do índice da cor do céu (calculado uma vez, nunca muda)
local indice_ceu_cache = nil

function init()
    Input.init()
    State.init()
    -- Calcula uma vez após a paleta estar disponível
    indice_ceu_cache = indice_cor(COR_CEU)
end

function update(frame)
    Input.update(frame)
    Mapa.update()
    State.update(Input)
    Audio.update(State)

    if State.current_scene == State.SCREEN_GAME then
        if not State.player.morto and not Timer.esgotado and not State.placa.ativa then
            Timer.update()
        end

        if Timer.esgotado and not State.player.morto and not State.placa.ativa then
            State.player.morto = true
            State.player.timer_morte = 0
            State.player.velocidade_y = -5
        end

        Objetos.update(State.player)
        Inimigos.update(State.player)
        Aneis.update(State.player)
        Player.atualizar_oxigenio(State.player, Mapa)
        Player.update(State.player, Input, Mapa, State.pode_pular(), Objetos.lista, Objetos)

        -- NOVO: atualiza o offset de "olhar cima/baixo" ANTES da câmera
        Camera.update_look(State.player, Input)
    end

    if State.player then
        Camera.update(State.player.x, State.player.y, State.player.velocidade_x, Mapa)
    end

    if Palette then
        for i = 1, #Palette do
            ui.palset(i - 1, Palette[i])
        end
    end

    if Transicao.ativa then
        Transicao.aplicar(Palette)
    end

    -- Usa cache (com fallback caso init não tenha rodado por algum motivo)
    local ceu = indice_ceu_cache or indice_cor(COR_CEU)
    ui.cls(ceu)

    if State.current_scene == State.SCREEN_GAME then
    -- Arredonda a câmera UMA VEZ para todos os desenhos
        local cam_arredondada_x = math.floor(Camera.x + 0.5)
        local cam_arredondada_y = math.floor(Camera.y + 0.5)

        local draw_x = -cam_arredondada_x
        local draw_y = -cam_arredondada_y

    -- 1. Desenha as camadas de fundo antes de sonic (nuvens), montanhas, decorações, agua)
        Mapa.draw_fundo(draw_x, draw_y)
        Mapa.draw_deco(draw_x, draw_y)
        Mapa.draw_agua(draw_x, draw_y)

    -- 2. Desenha o Sonic (Player)
        if State.player and not State.player.invisivel_visual then

        -- Usa a câmera arredondada para o Sonic não tremer
            local screen_x = math.floor(State.player.x - cam_arredondada_x)
            local screen_y = math.floor(State.player.y - cam_arredondada_y)

            local sprite = Animacao.sprite_atual(State.player)
            if sprite then
                local draw_sprite_y = screen_y
                if type(sprite.height) == "number" and sprite.height < 32 then
                    draw_sprite_y = screen_y + (32 - sprite.height)
                end
                ui.spr(sprite, screen_x - 16, draw_sprite_y, State.player.direcao < 0, false)
            end

    -- 3. Desenha o aviso de oxigênio
            local oxi = State.oxigenio
            if oxi and oxi.na_agua and not oxi.morrendo and oxi.tempo_restante > 0 and oxi.tempo_restante <= 5 * 60 then
                local segs = math.ceil(oxi.tempo_restante / 60)

                -- Coordenadas e recorte do objetos.png (Ajuste o 'w' e 'y' se o número estiver cortado)
                local src_x = 16 + ((segs - 1) * 16)
                local src_y = 32
                local w, h = 8  , 16 -- Tente mudar w para 8 se estiver pegando números vizinhos

                local texto_x = screen_x - 8
                local texto_y = screen_y - 28

                local sprite_img = _G.Sprites.objetos.objetos or _G.Sprites.objetos
                if sprite_img then
                    ui.clip(texto_x, texto_y, w, h)
                    ui.spr(sprite_img, texto_x - src_x, texto_y - src_y)
                    ui.clip()
                end
            end
        end

    -- 4. Desenha o resto dos objetos e outras camadas que ficam na frente de sonic
        Mapa.draw_objetos(draw_x, draw_y)
        Objetos.draw(cam_arredondada_x, cam_arredondada_y)
        Inimigos.draw(cam_arredondada_x, cam_arredondada_y)
        Aneis.draw(cam_arredondada_x, cam_arredondada_y)
        Mapa.draw_chao(draw_x, draw_y)
    end

    -- 5. Desenha a Ui do jogo
        UI.draw_hud(State)

        if State.current_scene == State.SCREEN_GAME then
            Timer.draw()
        end
end
