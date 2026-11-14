local Camera = {
    x = 0,
    y = 150,
    largura_tela = 480,
    altura_tela = 270,

    -- NOVO: offset vertical acumulativo para "olhar" cima/baixo.
    -- É somado ao Camera.y final. 0 = neutro, negativo = olhando pra cima (câmera sobe).
    y_offset = 0,
}

local DEAD_ZONE_X = 32
local DEAD_ZONE_Y = 16
local LOOK_AHEAD = 32

local SUAVIZACAO = 0.15
local LIMIAR_SNAP = 0.01

-- === NOVO: Configuração do "olhar pra cima/baixo" ===
-- Distâncias baseadas no Sonic 1 do Mega Drive [citation:3][citation:6]
local LOOK_UP_DIST = 104       -- quanto a câmera sobe (px)
local LOOK_DOWN_DIST = 88      -- quanto a câmera desce (px)
local LOOK_SPEED = 2           -- velocidade de rolagem (px/frame)
local LOOK_DELAY_FRAMES = 45

-- Estado interno (não exposto)
local look_timer = 0
local look_direcao = 0  -- 0 = neutro, -1 = cima, +1 = baixo

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

-- NOVO: atualiza o y_offset baseado no input e no estado do player
-- Retorna true se a câmera está "olhando" (para o game.lua saber se precisa forçar redraw, etc.)
function Camera.update_look(player, input)
    -- Só permite olhar se player está parado no chão
    local pode_olhar = player and player.no_chao and math.abs(player.velocidade_x) < 0.05

    local cima = input.is_action("up", 0)
    local baixo = input.is_action("down", 0)

    -- Se não pode olhar ou não está segurando nada, reseta
    if not pode_olhar or (not cima and not baixo) then
        look_timer = 0
        look_direcao = 0
    else
        -- Está segurando cima ou baixo com player parado: incrementa timer
        look_timer = look_timer + 1

        if look_timer > LOOK_DELAY_FRAMES then
            if cima then
                look_direcao = -1
            elseif baixo then
                look_direcao = 1
            end
        end
    end

    -- Move o y_offset em direção ao alvo
    local alvo_offset = 0
    if look_direcao == -1 then
        alvo_offset = -LOOK_UP_DIST
    elseif look_direcao == 1 then
        alvo_offset = LOOK_DOWN_DIST
    end

    -- Converge a 2px por frame (como o original)
    if Camera.y_offset < alvo_offset then
        Camera.y_offset = math.min(Camera.y_offset + LOOK_SPEED, alvo_offset)
    elseif Camera.y_offset > alvo_offset then
        Camera.y_offset = math.max(Camera.y_offset - LOOK_SPEED, alvo_offset)
    end
end

function Camera.update(player_x, player_y, player_vx, mapa)
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

    -- Y: alvo base é player - metade da tela. Depois SOMA o y_offset do "olhar".
    local alvo_camera_y_base = player_y - Camera.altura_tela / 2
    local alvo_camera_y = alvo_camera_y_base + Camera.y_offset

    local diff_y = alvo_camera_y - Camera.y
    if diff_y > LIMIAR_SNAP or diff_y < -LIMIAR_SNAP then
        Camera.y = lerp(Camera.y, alvo_camera_y, 0.2)
    elseif diff_y ~= 0 then
        Camera.y = alvo_camera_y
    end

    Camera.x = limitar_x(Camera.x, mapa.largura)
    Camera.y = limitar_y(Camera.y, mapa.altura)
end

function Camera.apply()
    ui.camera(Camera.x, Camera.y)
end

function Camera.get_xy()
    return Camera.x, Camera.y
end

-- NOVO: reset (chamar quando troca de fase ou player reseta)
function Camera.reset()
    Camera.y_offset = 0
    look_timer = 0
    look_direcao = 0
end

return Camera
