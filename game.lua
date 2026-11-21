require("palette")
require("sprites")

local Palette   = _G.Palette
local State     = require("state")
local Audio     = require("sistemas.audio")
local Input     = require("ui-adapter")
local Camera    = require("sistemas.camera")
local Player    = require("sistemas.player")
local Animacao  = require("sistemas.animacao")
local UI        = require("sistemas.ui")
local Mapa      = require("mapa")
local Transicao = require("sistemas.transicao")
local Objetos   = require("sistemas.objetos")
local Inimigos  = require("sistemas.inimigos")
local Aneis     = require("sistemas.aneis")
local Timer     = require("sistemas.timer")
local Chefe     = require("sistemas.chefe")

local COR_CEU = 0x7EA0
local COR_CEU_ESP = 0x2800

-- Input neutro para cutscenes: a física do Sonic continua rodando
-- (ele pousa e fica parado), mas nenhum comando do jogador entra.
local INPUT_NEUTRO = {
    is_action         = function() return false end,
    is_action_pressed = function() return false end,
}

-- Cutscene da cela: Sonic corre para a direita até sair da tela.
-- A física continua normal (ele desce da cápsula e corre no chão).
local INPUT_AUTO_DIREITA = {
    is_action         = function(acao) return acao == "right" end,
    is_action_pressed = function() return false end,
}

LUPI_HARDWARE_CONSTRAINTS = true
LUPI_LUA_WATCHDOG = true
LUPI_HARDWARE_DEBUG_OVERLAY = true
LUPI_HARDWARE_DEBUG_OVERLAY_RECT = { x0 = 0, y0 = 0, x1 = 164, y1 = 270, col = 2 }
LUPI_HARDWARE_DEBUG_OVERLAY_ALPHA = 0.5

local function indice_cor(cor)
    if not Palette then return 0 end
    for indice, valor in pairs(Palette) do
        if valor == cor then return indice - 1 end
    end
    return 0
end

local indice_ceu_cache = nil

local indice_ceu_cache = nil
local indice_ceu_esp_cache = nil
function init()
    Input.init()
    State.init()
    indice_ceu_cache = indice_cor(COR_CEU)
    indice_ceu_esp_cache = indice_cor(COR_CEU_ESP)
end

function update(frame)
    Input.update(frame)
    Mapa.update()
    State.update(Input)
    Audio.update(State)

    if State.current_scene == State.SCREEN_GAME then
     local fim_de_ato = State.placa.ativa or State.cela_cutscene
     local em_especial = State.stage_e_especial()
     if not State.player.morto and not Timer.esgotado and not fim_de_ato then
         Timer.update()
     end
     -- SALA ESPECIAL: countdown próprio, independente do Timer da fase
     if em_especial then
         local esp = State.especial
         if esp and not esp.concluiu and not esp.falhou
            and not State.player.morto and not State.placa.ativa then
             esp.tempo = esp.tempo - 1
             if esp.tempo <= 0 then
                 esp.tempo = 0
                 State.sp_falhar()
             end
         end
     end
     if not em_especial and Timer.esgotado and not State.player.morto and not fim_de_ato then
            State.player.morto = true
            State.player.timer_morte = 0
            State.player.velocidade_y = -5
        end

        -- Cutscenes: chefe/entrada = sem controle; cela = corre para fora
        local cut_chefe   = Chefe.em_cutscene()
        local cut_cela    = Objetos.em_cutscene_cela()
        local em_cutscene = cut_chefe or cut_cela
        local input_sonic = Input
        local pode_pular  = State.pode_pular()
        if cut_chefe then
            input_sonic = INPUT_NEUTRO
            pode_pular  = false
        elseif cut_cela then
            input_sonic = INPUT_AUTO_DIREITA
            pode_pular  = false
        end

        Objetos.update(State.player)
        Inimigos.update(State.player)
        Aneis.update(State.player)
        Player.atualizar_oxigenio(State.player, Mapa)
        Player.update(State.player, input_sonic, Mapa, pode_pular, Objetos.lista, Objetos)
        -- Colisão com o Sonic DEPOIS da física: o pouso zera velocidade_y,
        -- e era isso que fazia o Sonic tomar dano ao cair em cima do inimigo.
        if not em_cutscene then
            Inimigos.colisoes_player(State.player)
        end
        Objetos.resolver_cela(State.player)
        -- Freada da cutscene de entrada: Sonic para na borda da arena
        if cut_chefe then
            State.player.velocidade_x = State.player.velocidade_x * 0.85
        end
        Chefe.update(State.player)
        Camera.update_look(State.player, input_sonic)
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

    local ceu = indice_ceu_cache or indice_cor(COR_CEU)
    if State.current_scene == State.SCREEN_GAME and State.stage_e_especial() then
        ceu = indice_ceu_esp_cache or indice_cor(COR_CEU_ESP)
    end
    ui.cls(ceu)

    if State.current_scene == State.SCREEN_GAME then
        local cam_arredondada_x = math.floor(Camera.x + 0.5)
        local cam_arredondada_y = math.floor(Camera.y + 0.5)
        local draw_x = -cam_arredondada_x
        local draw_y = -cam_arredondada_y

        -- 1. Fundo
        Mapa.draw_fundo(draw_x, draw_y)
        Mapa.draw_deco(draw_x, draw_y)
        Mapa.draw_agua(draw_x, draw_y)
        Mapa.draw_objetos(draw_x, draw_y)
        Objetos.draw(cam_arredondada_x, cam_arredondada_y)
        -- 2. Sonic
        if State.player and not State.player.invisivel_visual then
            Player.draw(State.player, cam_arredondada_x, cam_arredondada_y)
            local oxi = State.oxigenio
            if oxi and oxi.na_agua and oxi.tempo_restante <= 5 * 60 then
                local segs = math.ceil(oxi.tempo_restante / 60)
                local segs_str = tostring(segs)
                local texto_x = math.floor(State.player.x - cam_arredondada_x) - 8
                local texto_y = math.floor(State.player.y - cam_arredondada_y) - 30
                UI.desenhar_texto_ui(segs_str, texto_x, texto_y, 16)
            end
        end

        -- 4. camadas de frente
        Inimigos.draw(cam_arredondada_x, cam_arredondada_y)
        Aneis.draw(cam_arredondada_x, cam_arredondada_y)
        Chefe.draw(cam_arredondada_x, cam_arredondada_y)
        Mapa.draw_chao(draw_x, draw_y)
    end

    -- 5. UI e HUD
    UI.draw_hud(State)
end
