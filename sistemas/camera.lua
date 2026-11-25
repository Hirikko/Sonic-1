local Camera = {
    x = 0,
    y = 150,
    largura_tela = 480,
    altura_tela = 270,
    y_offset = 0,
}

local DEAD_ZONE_X = 32
local DEAD_ZONE_Y = 16
local LOOK_AHEAD = 32

local SUAVIZACAO = 0.15
local LIMIAR_SNAP = 0.01

local LOOK_UP_DIST = 104
local LOOK_DOWN_DIST = 88
local LOOK_SPEED = 2
local LOOK_DELAY_FRAMES = 45

local look_timer = 0
local look_direcao = 0

local function limitar_x(x, largura_mapa)
    if not largura_mapa then return x end
    return math.max(0, math.min(x, largura_mapa - Camera.largura_tela))
end

local function limitar_y(y, altura_mapa)
    if not altura_mapa then return y end
    return math.max(0, math.min(y, altura_mapa - Camera.altura_tela))
end

local function lerp(a, b, t)
    return a + (b - a) * t
end

function Camera.update_look(player, input)
    local pode_olhar = player and player.no_chao and math.abs(player.velocidade_x) < 0.05

    local cima  = input.is_action("up", 0)
    local baixo = input.is_action("down", 0)

    if not pode_olhar or (not cima and not baixo) then
        look_timer = 0
        look_direcao = 0
    else
        look_timer = look_timer + 1
        if look_timer > LOOK_DELAY_FRAMES then
            if cima then
                look_direcao = -1
            elseif baixo then
                look_direcao = 1
            end
        end
    end

    local alvo_offset = 0
    if look_direcao == -1 then
        alvo_offset = -LOOK_UP_DIST
    elseif look_direcao == 1 then
        alvo_offset = LOOK_DOWN_DIST
    end

    if Camera.y_offset < alvo_offset then
        Camera.y_offset = math.min(Camera.y_offset + LOOK_SPEED, alvo_offset)
    elseif Camera.y_offset > alvo_offset then
        Camera.y_offset = math.max(Camera.y_offset - LOOK_SPEED, alvo_offset)
    end
end

function Camera.update(player_x, player_y, player_vx, mapa)
    local State   = require("state")
    local Terreno = require("sistemas.terreno")
    local dados   = Terreno.get_dados()

    -- ============================================================
    -- CUTSCENE DA CAPSULA: a câmera ABANDONA o Sonic.
    -- Precisa ser return, não um lerp por cima do follow: o follow
    -- (0.15) é mais forte que a trava (0.08) e arrastava a câmera
    -- atrás do Sonic enquanto ele corre para fora da tela.
    -- ============================================================
    if State.cela_cutscene and State.cela_foco_x then
        local foco_y = State.cela_foco_y or (Camera.y + Camera.altura_tela / 2)
        local alvo_x = limitar_x(State.cela_foco_x - Camera.largura_tela / 2, mapa.largura)
        local alvo_y = limitar_y(foco_y - Camera.altura_tela / 2, mapa.altura)
        Camera.x = lerp(Camera.x, alvo_x, 0.08)
        Camera.y = lerp(Camera.y, alvo_y, 0.08)
        return
    end

    -- COOP: o alvo passa a ser o centro dos vivos. Com vx=0 nao ha
    -- look-ahead, e a dead zone existente da o follow suave de grupo.
    local Coop = require("sistemas.coop")
    if Coop.ativo then
        local cx, cy = Coop.centro_vivos()
        if cx then
            player_x, player_y, player_vx = cx, cy - 16, 0
        end
    end

    local centro_x = Camera.x + Camera.largura_tela / 2
    local look = 0
    if player_vx > 2 then look = LOOK_AHEAD
    elseif player_vx < -2 then look = -LOOK_AHEAD end
    local alvo_x = player_x + look

    local alvo_camera_x = Camera.x
    if alvo_x > centro_x + DEAD_ZONE_X then
        alvo_camera_x = alvo_x - DEAD_ZONE_X - Camera.largura_tela / 2
    elseif alvo_x < centro_x - DEAD_ZONE_X then
        alvo_camera_x = alvo_x + DEAD_ZONE_X - Camera.largura_tela / 2
    end

    local diff_x = alvo_camera_x - Camera.x
    if diff_x > LIMIAR_SNAP or diff_x < -LIMIAR_SNAP then
        Camera.x = lerp(Camera.x, alvo_camera_x, SUAVIZACAO)
    elseif diff_x ~= 0 then
        Camera.x = alvo_camera_x
    end

    local alvo_camera_y = (player_y - Camera.altura_tela / 2) + Camera.y_offset
    local diff_y = alvo_camera_y - Camera.y
    if diff_y > LIMIAR_SNAP or diff_y < -LIMIAR_SNAP then
        Camera.y = lerp(Camera.y, alvo_camera_y, 0.2)
    elseif diff_y ~= 0 then
        Camera.y = alvo_camera_y
    end

    Camera.x = limitar_x(Camera.x, mapa.largura)
    Camera.y = limitar_y(Camera.y, mapa.altura)

    -- Trava da arena do chefe: centraliza (não segue o chefe voador)
    if State.chefe_ativo and not State.chefe_derrotado
       and dados and dados.initrava and dados.travafim then
        local centro_arena = (dados.initrava.x + dados.travafim.x) / 2
        local alvo_cam_x   = centro_arena - Camera.largura_tela / 2
        Camera.x = lerp(Camera.x, alvo_cam_x, 0.05)
        -- min/max estavam invertidos (2016 > 2000) e se anulavam.
        local a = dados.initrava.x
        local b = dados.travafim.x - Camera.largura_tela
        local lim_inf, lim_sup = math.min(a, b), math.max(a, b)
        Camera.x = math.max(lim_inf, math.min(Camera.x, lim_sup))
    end
end

function Camera.apply()
    ui.camera(Camera.x, Camera.y)
end

function Camera.get_xy()
    return Camera.x, Camera.y
end

function Camera.reset()
    Camera.y_offset = 0
    look_timer      = 0
    look_direcao    = 0
end

return Camera
