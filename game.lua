require("palette")
require("sprites")

LUPI_HARDWARE_CONSTRAINTS = true
LUPI_LUA_WATCHDOG = true
LUPI_HARDWARE_DEBUG_OVERLAY = false
LUPI_HARDWARE_DEBUG_OVERLAY_RECT = { x0 = 0, y0 = 0, x1 = 164, y1 = 270, col = 2 }
LUPI_HARDWARE_DEBUG_OVERLAY_ALPHA = 0.5

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

-- Um wrapper de input por controle. Cacheado: sem alocacao por frame.
-- O ui-adapter ja aceita o indice, entao nao precisa monkey-patch de
-- ui.btn como o projeto de referencia fazia.
local inputs_pad = {}
local function input_do_pad(idx)
    local c = inputs_pad[idx]
    if not c then
        c = {
            is_action         = function(a) return Input.is_action(a, idx) end,
            is_action_pressed = function(a) return Input.is_action_pressed(a, idx) end,
        }
        inputs_pad[idx] = c
    end
    return c
end

local function algum_vivo(lista)
    for _, p in ipairs(lista) do
        if not p.morto and not p.coop_esperando then return true end
    end
    return false
end

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

    if State.current_scene == State.SCREEN_GAME and not State.pausado_opcoes then
     local lista = State.players or { State.player }
     local Coop  = require("sistemas.coop")
     local vivo  = algum_vivo(lista)
     local fim_de_ato = State.placa.ativa or State.cela_cutscene
     local em_especial = State.stage_e_especial()
     if vivo and not Timer.esgotado and not fim_de_ato then
         Timer.update()
     end
     if em_especial then
         local esp = State.especial
         if esp and not esp.concluiu and not esp.falhou
            and vivo and not State.placa.ativa then
             esp.tempo = esp.tempo - 1
             if esp.tempo <= 0 then
                 esp.tempo = 0
                 State.sp_falhar()
             end
         end
     end
     if not em_especial and Timer.esgotado and vivo and not fim_de_ato then
         for _, p in ipairs(lista) do
             if not p.morto and not p.coop_esperando then
                 p.morto = true
                 p.timer_morte = 0
                 p.velocidade_y = -5
             end
         end
     end

     local cut_chefe   = Chefe.em_cutscene()
     local cut_cela    = Objetos.em_cutscene_cela()
     local em_cutscene = cut_chefe or cut_cela
     local input_base  = Input
     local pode_pular  = State.pode_pular()
     if cut_chefe then
         input_base = INPUT_NEUTRO
         pode_pular = false
     elseif cut_cela then
         input_base = INPUT_AUTO_DIREITA
         pode_pular = false
     end

     -- Sistemas que ainda recebem UM player: usam o primeiro vivo.
     local ref = lista[1]
     for _, p in ipairs(lista) do
         if not p.morto and not p.coop_esperando then ref = p; break end
     end

     Objetos.update(ref)
     Inimigos.update(ref)
     Aneis.update()          -- global: animacao + fisica, uma vez

     for _, p in ipairs(lista) do
         local inp = (input_base == Input) and input_do_pad(p.pad or 0) or input_base
         Aneis.coleta(p)     -- por player: cada um pega os seus
         Player.atualizar_oxigenio(p, Mapa)
         Player.update(p, inp, Mapa, pode_pular, Objetos.lista, Objetos)
         if not em_cutscene then Inimigos.colisoes_player(p) end
         Objetos.resolver_cela(p)
         if cut_chefe then p.velocidade_x = p.velocidade_x * 0.85 end
     end

     Chefe.update(ref)
     Camera.update_look(ref, input_base)

     -- COOP: decide respawn / reset / game over
     local acao = Coop.atualizar(State)
     if acao == "game_over" then
         if Objetos.limpar_checkpoint then Objetos.limpar_checkpoint() end
         State.proxima_cena = State.SCREEN_GAME_OVER
         if not Transicao.ativa then Transicao.iniciar() end
     elseif acao == "resetar_fase" then
         State.espera_soltar = true
         State.proxima_cena = State.SCREEN_GAME
         State.acao_pos_transicao = function() State.resetar_estado_fase() end
         if not Transicao.ativa then Transicao.iniciar() end
     end
    end

    if State.player then
        local lista = State.players or { State.player }
        local ref = lista[1]
        for _, p in ipairs(lista) do
            if not p.morto and not p.coop_esperando then ref = p; break end
        end
        Camera.update(ref.x, ref.y, ref.velocidade_x, Mapa)
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
        for _, p in ipairs(State.players or { State.player }) do
            if not p.invisivel_visual then
                Player.draw(p, cam_arredondada_x, cam_arredondada_y)
                local oxi = p.oxigenio
                if oxi and oxi.na_agua and oxi.tempo_restante <= 5 * 60
                   and not p.morto and not p.coop_esperando then
                    local segs_str = tostring(math.ceil(oxi.tempo_restante / 60))
                    local tx = math.floor(p.x - cam_arredondada_x) - 8
                    local ty = math.floor(p.y - cam_arredondada_y) - 30
                    UI.desenhar_texto_ui(segs_str, tx, ty, 16)
                end
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
