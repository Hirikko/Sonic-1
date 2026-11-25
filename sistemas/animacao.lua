local Sprites = require("sistemas.sprites")

local Animacao = {}

local TEMPO_ESPERA = 300
local DURACAO_VIRA_RAPIDO = 15
local LIMIAR_CORRIDA = 3.0

local function iniciar(player, estado)
    if player.sprite == estado then return end
    player.sprite = estado
    player.frame_anim = 1
    player.timer_anim = 0
end

local function atualizar_frame(player, configuracao, estado)
    if configuracao.frame_fixo then
        player.frame_anim = configuracao.frame_fixo
        return
    end

    player.timer_anim = player.timer_anim + 1
    if player.timer_anim < configuracao.cadencia then return end

    player.timer_anim = 0
    player.frame_anim = player.frame_anim + 1

    -- total real do heroi, nao o padrao do ANIMACOES
    local total = Sprites.frames(estado, player.heroi)
    if player.frame_anim <= total then return end

    if configuracao.loop then
        player.frame_anim = 1
    else
        player.frame_anim = total
    end
end

local function esta_movendo(player)
    return math.abs(player.velocidade_x) > 0.05
end

local function atualizar_tempo_parado(player)
    if not player.no_chao or esta_movendo(player) then
        player.tempo_parado = 0
        return
    end
    player.tempo_parado = player.tempo_parado + 1
end

local function escolher_parado(player)
    if player.olhando_cima then return "olha_cima" end
    if player.olhando_baixo then return "olha_baixo" end
    if player.tempo_parado >= TEMPO_ESPERA then return "esperar" end
    return "parado"
end

local function escolher_movimento(player)
    local vel_abs = math.abs(player.velocidade_x)
    if vel_abs < LIMIAR_CORRIDA then
        return "andar"
    else
        return "correr"
    end
end

local function mudou_direcao(player)
    return player.direcao ~= player.direcao_anterior
end

local function deve_virar_rapido(player)
    if player.sprite ~= "correr" then return false end
    if math.abs(player.velocidade_x) < 2 then return false end
    return mudou_direcao(player)
end

local function atualizar_forcada(player)
    if not player.animacao_forcada then return false end
    local configuracao = Sprites.ANIMACOES[player.animacao_forcada]
    atualizar_frame(player, configuracao, player.animacao_forcada)

    if player.duracao_forcada then
        player.duracao_forcada = player.duracao_forcada - 1
        if player.duracao_forcada <= 0 then
            player.animacao_forcada = nil
            player.duracao_forcada = nil
        end
    end
    return true
end

-- NOVO: branches reordenadas por frequência.
-- Estados mais comuns primeiro (parado/andar/correr/pular).
-- Prioridades lógicas preservadas:
--   morto > em_queda > em_dano > vulneravel_mola_cima > !no_chao > vira_rapido > rodando > andar/correr > parado
local function escolher_estado(player)
    -- 1. Morto (raro, mas tem prioridade máxima)
    if player.morto then return "morre" end

    -- 2. Parado no chão sem ação especial (mais comum em gameplay calmo)
    if player.no_chao and not player.rodando then
        if player.em_dano then
            -- cai no fluxo abaixo (em_dano sem chão já virou em_dano; no chão reseta)
        elseif player.vulneravel_mola_cima then
            -- idem, cai no fluxo abaixo
        elseif esta_movendo(player) then
            -- vira_rapido tem prioridade sobre andar/correr
            if deve_virar_rapido(player) then
                player.animacao_forcada = "vira_rapido"
                player.duracao_forcada = DURACAO_VIRA_RAPIDO
                iniciar(player, "vira_rapido")
                return "vira_rapido"
            end
            return escolher_movimento(player)
        else
            return escolher_parado(player)
        end
    end

    -- 3. Estados que exigem tratamento especial (na ordem de prioridade original)
    if player.em_queda then return "dano" end

    if player.em_dano then
        if player.no_chao then
            player.em_dano = false
        else
            return "dano"
        end
    end

    if player.vulneravel_mola_cima and not player.no_chao then
        return "pula_mola"
    end

    if not player.no_chao then return "pular" end

    if deve_virar_rapido(player) then
        player.animacao_forcada = "vira_rapido"
        player.duracao_forcada = DURACAO_VIRA_RAPIDO
        iniciar(player, "vira_rapido")
        return "vira_rapido"
    end

    if player.rodando then return "rodar" end

    if esta_movendo(player) then return escolher_movimento(player) end

    return escolher_parado(player)
end

function Animacao.atualizar(player)
    atualizar_tempo_parado(player)

    if atualizar_forcada(player) then
        player.direcao_anterior = player.direcao
        return
    end

    local estado = escolher_estado(player)
    if estado ~= player.sprite then
        iniciar(player, estado)
    end

    local configuracao = Sprites.ANIMACOES[player.sprite]
    if configuracao then
        atualizar_frame(player, configuracao, player.sprite)
    end

    player.direcao_anterior = player.direcao
end

function Animacao.iniciar(player, estado, duracao)
    player.animacao_forcada = estado
    player.duracao_forcada = duracao
    iniciar(player, estado)
end

function Animacao.liberar(player)
    player.animacao_forcada = nil
    player.duracao_forcada = nil
end

function Animacao.sprite_atual(player)
    return Sprites.sprite(player.sprite, player.frame_anim, player.heroi)
end

return Animacao
