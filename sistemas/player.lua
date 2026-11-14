local Animacao = require("sistemas.animacao")
local State    = require("state")
local Timer    = require("sistemas.timer")
local Aneis    = require("sistemas.aneis")
local PlayerSystem = {}

local ALTURA_PLAYER = 32
local ALTURA_COLISAO = 28

local SPRITE_ANCORA_X = 16
local COLISAO_HALF_W = 6
local COLISAO_TOPO_Y = 4
local COLISAO_BASE_Y = 28
local COLISAO_OFFSET_X = -3

local ACELERACAO = 0.050
local VELOCIDADE_MAXIMA = 6.0
local DESACELERACAO = 0.08

local ACELERACAO_AR = 0.12
local DESACELERACAO_AR = 0.06
local VELOCIDADE_MAXIMA_AR = 6.0

local DESACELERACAO_CONTRARIA = 0.7
local VELOCIDADE_TENSAO = 0.5

local FORCA_GRAVIDADE_RAMPA = 0.25
local GRAVIDADE = 0.35
local FORCA_PULO = -9
local CORTE_PULO = 0.20

local LIMIAR_MOLA = 4.5
local FORCA_MOLA_BASE = -7
local FATOR_VELOCIDADE_MOLA = 1.2
local FORCA_MOLA_MAX = -16

local FRICCAO_ROLAR = 0.995
local FRICCAO_ROLAR_PLANO = 0.06
local VELOCIDADE_MINIMA_ROLAR = 0.2

local PASSO_MAXIMO = 4
local MARGEM_SEGURANCA_RAMPA = 16

local TEMPO_INVENCIVEL = 140
local TEMPO_PISCA = 6

local FORCA_BOUNCE = -6
local DURACAO_BOUNCE = 12
local FATOR_GRAVIDADE_BOUNCE = 0.222

local BUFFS_PADRAO = { invencivel = 0, velocidade_extra = 0, escudo = false }

local function aproximar_zero(valor, quantidade)
    if valor > 0 then return math.max(0, valor - quantidade) end
    if valor < 0 then return math.min(0, valor + quantidade) end
    return 0
end

local function get_buffs()
    return State.buffs or BUFFS_PADRAO
end

local function atualizar_horizontal(player, input, mapa)
    local esquerda = input.is_action("left", 0)
    local direita = input.is_action("right", 0)
    local baixo = input.is_action("down", 0)
    local vel_abs = math.abs(player.velocidade_x)

    local buffs = get_buffs()
    local aceleracao = ACELERACAO
    local vel_max = VELOCIDADE_MAXIMA

    if buffs and buffs.velocidade_extra and buffs.velocidade_extra > 0 then
        aceleracao = ACELERACAO * 1.5
        vel_max = VELOCIDADE_MAXIMA + 3
    end

    local na_agua = false
    local areas = mapa.get_areas_agua and mapa.get_areas_agua() or {}
    for _, area in ipairs(areas) do
        if player.x > area.x and player.x < area.x + area.w and
           player.y > area.y and player.y < area.y + area.h then
            na_agua = true
            break
        end
    end

    if na_agua then
        aceleracao = aceleracao * 0.5
        vel_max = vel_max * 0.6
    end

    if not player.no_chao then
        if esquerda then
            player.direcao = -1
            player.velocidade_x = player.velocidade_x - ACELERACAO_AR
        elseif direita then
            player.direcao = 1
            player.velocidade_x = player.velocidade_x + ACELERACAO_AR
        else
            player.velocidade_x = aproximar_zero(player.velocidade_x, DESACELERACAO_AR)
        end
        player.velocidade_x = math.max(-VELOCIDADE_MAXIMA_AR, math.min(player.velocidade_x, VELOCIDADE_MAXIMA_AR))
        return
    end

    local pes_y = player.y + ALTURA_PLAYER
    local inclinacao = mapa.inclinacao(player.x, pes_y) or 0

    local esta_em_rampa = math.abs(inclinacao) > 0.2
    if baixo and player.no_chao and not player.rodando and (vel_abs > 1.0 or esta_em_rampa) then
        player.rodando = true
        if vel_abs > 1.0 then player.velocidade_x = player.velocidade_x * 1.1 end
    end

    if player.rodando then
        player.velocidade_x = player.velocidade_x + (inclinacao * FORCA_GRAVIDADE_RAMPA * 1.5)
        if math.abs(inclinacao) < 0.1 and player.no_chao then
            player.velocidade_x = aproximar_zero(player.velocidade_x, FRICCAO_ROLAR_PLANO)
        else
            player.velocidade_x = player.velocidade_x * FRICCAO_ROLAR
        end
        if math.abs(player.velocidade_x) < VELOCIDADE_MINIMA_ROLAR and math.abs(inclinacao) < 0.1 then
            player.rodando = false
            player.velocidade_x = 0
        end
    else
        if esquerda then
            player.direcao = -1
            if player.velocidade_x > VELOCIDADE_TENSAO then
                player.velocidade_x = aproximar_zero(player.velocidade_x, DESACELERACAO_CONTRARIA)
            else
                player.velocidade_x = player.velocidade_x - aceleracao
            end
        elseif direita then
            player.direcao = 1
            if player.velocidade_x < -VELOCIDADE_TENSAO then
                player.velocidade_x = aproximar_zero(player.velocidade_x, DESACELERACAO_CONTRARIA)
            else
                player.velocidade_x = player.velocidade_x + aceleracao
            end
        else
            local desacel = na_agua and (DESACELERACAO * 0.1) or DESACELERACAO
            player.velocidade_x = aproximar_zero(player.velocidade_x, desacel)
        end

        if player.no_chao and not player.pendulo_atual then
            player.velocidade_x = player.velocidade_x + (inclinacao * FORCA_GRAVIDADE_RAMPA)
        end
    end

    local limite = player.rodando and (vel_max * 1.5) or vel_max
    player.velocidade_x = math.max(-limite, math.min(player.velocidade_x, limite))
end

local function iniciar_pulo(player, input, pode_pular)
    local apertou_agora = input.is_action_pressed("confirm", 0)
    local segurando = input.is_action("confirm", 0)
    local em_plataforma = player.plataforma_atual ~= nil

    local deve_pular = (player.no_chao or em_plataforma) and
                       (apertou_agora or (pode_pular and segurando))

    if deve_pular then
        player.velocidade_y = FORCA_PULO
        player.no_chao = false
        player.rodando = false
        player.pulou_mola = false
        player.plataforma_atual = nil
        if player.pendulo_atual then
            player.velocidade_x = player.velocidade_x + (player.pendulo_atual.delta_x * 2)
            player.pendulo_atual = nil
        end
    end
end

local function cortar_pulo(player, input)
    if player.pulou_mola then return end
    if player.bounce_frames and player.bounce_frames > 0 then return end
    if player.em_dano then return end
    if not input.is_action("confirm", 0) and player.velocidade_y < 0 then
        player.velocidade_y = player.velocidade_y * CORTE_PULO
    end
end

local function manter_no_suporte(player, mapa)
    local pes_y = player.y + ALTURA_PLAYER
    local suporte, segmento = mapa.suporte_info(player.x, pes_y, 8)

    if not suporte or not segmento then
        player.no_chao = false
        return false
    end

    local TOLERANCIA_BORDA = 1
    if player.x < segmento.inicio - TOLERANCIA_BORDA or player.x > segmento.fim + TOLERANCIA_BORDA then
        player.no_chao = false
        return false
    end

    if math.abs(pes_y - suporte) > 2 then
        player.no_chao = false
        return false
    end

    player.y = suporte - ALTURA_PLAYER
    player.velocidade_y = 0
    player.no_chao = true
    player.pulou_mola = false
    return true
end

local function atualizar_vertical(player, input, pode_pular, mapa, pendulos, objetos)
    iniciar_pulo(player, input, pode_pular)
    cortar_pulo(player, input)

    local pes_anterior = player.y + ALTURA_PLAYER

    local grav = GRAVIDADE
    if player.bounce_frames and player.bounce_frames > 0 then
        grav = GRAVIDADE * FATOR_GRAVIDADE_BOUNCE
    end
    player.velocidade_y = player.velocidade_y + grav

    local pes_atual = pes_anterior + player.velocidade_y

    if player.velocidade_y < 0 and mapa.colide_teto then
        local topo_anterior = pes_anterior - ALTURA_PLAYER + COLISAO_TOPO_Y
        local topo_atual = pes_atual - ALTURA_PLAYER + COLISAO_TOPO_Y
        local teto = mapa.colide_teto(player.x, topo_anterior, topo_atual)
        if teto then
            player.y = teto - COLISAO_TOPO_Y
            player.velocidade_y = 0
            pes_atual = player.y + ALTURA_PLAYER
        end
    end

    if objetos and objetos.plataformas and player.velocidade_y >= 0 then
        for _, pl in ipairs(objetos.plataformas) do
            if player.x + 16 > pl.x and player.x < pl.x + pl.largura then
                if pes_anterior <= pl.y and pes_atual >= pl.y then
                    player.y = pl.y - ALTURA_PLAYER
                    player.velocidade_y = 0
                    player.no_chao = true
                    player.pulou_mola = false
                    player.plataforma_atual = pl
                    return
                end
            end
        end
    end

    if player.velocidade_y >= 0 and pendulos then
        for _, p in ipairs(pendulos) do
            if math.abs(player.x - p.x_plataforma) <= 16 then
                if pes_anterior <= p.y_plataforma and pes_atual >= p.y_plataforma then
                    player.y = p.y_plataforma - ALTURA_PLAYER
                    player.velocidade_y = 0
                    player.no_chao = true
                    player.pulou_mola = false
                    player.pendulo_atual = p
                    return
                end
            end
        end
    end

    if player.velocidade_y >= 0 then
        local pouso = mapa.aterrissagem(player.x, pes_anterior, pes_atual, 6)
        if pouso then
            player.y = pouso - ALTURA_PLAYER
            player.velocidade_y = 0
            player.no_chao = true
            player.pulou_mola = false
            player.pendulo_atual = nil
            return
        end
    end

    player.y = pes_atual - ALTURA_PLAYER

    player.no_chao = false
    if player.pendulo_atual then player.pendulo_atual = nil end

    if player.velocidade_y >= 0 then
        local altura_superficie = mapa.altura_suporte(player.x, player.y + ALTURA_PLAYER, MARGEM_SEGURANCA_RAMPA)
        if altura_superficie then
            local pes_novo = player.y + ALTURA_PLAYER
            local penetracao = pes_novo - altura_superficie
            if penetracao > 0 and penetracao <= MARGEM_SEGURANCA_RAMPA then
                player.y = altura_superficie - ALTURA_PLAYER
                player.velocidade_y = 0
                player.no_chao = true
                player.pulou_mola = false
            end
        end
    end
end

local function atualizar_estado_parado(player, input)
    local vx_abs = math.abs(player.velocidade_x)
    local parado = vx_abs < 0.2 and not player.rodando
    player.olhando_cima = parado and input.is_action("up", 0)
    player.olhando_baixo = parado and input.is_action("down", 0)
end

local function atualizar_colisao_horizontal(player, mapa)
    local velocidade_x = player.velocidade_x
    local passos = math.max(1, math.ceil(math.abs(velocidade_x) / PASSO_MAXIMO))
    local passo_x = velocidade_x / passos

    for _ = 1, passos do
        local x_anterior = player.x
        local x_novo = mapa.limitar_x(player.x + passo_x)
        local pes_y = player.y + ALTURA_PLAYER

        local suporte, bateu_parede
        x_novo, suporte, bateu_parede = mapa.movimento_horizontal(x_anterior, x_novo, pes_y, ALTURA_COLISAO)

        if bateu_parede then
            player.x = x_novo
            player.velocidade_x = 0
            break
        end

        if player.no_chao and not player.pendulo_atual and not player.plataforma_atual then
            if suporte then
                player.y = suporte - ALTURA_PLAYER
            else
                player.no_chao = false
            end
        end

        player.x = x_novo

        if x_novo == x_anterior then
            player.velocidade_x = 0
            break
        end
    end
end

local function verificar_mola(player, mapa)
    if player.pulou_mola then return false end

    local p_x, p_y = player.x + 4, player.y + 4
    local p_w, p_h = 8, 24

    for _, m in ipairs(mapa.get_molas()) do
        if p_x < m.x + m.largura and p_x + p_w > m.x and p_y < m.y + m.altura and p_y + p_h > m.y then
            local tipo = m.tipo or ""
            if string.find(tipo, "cima") or string.find(tipo, "up") then
                player.velocidade_x = 0
                player.velocidade_y = -13.5
                player.vulneravel_mola_cima = true
                player.vulneravel_mola_cima_timer = 300
            elseif string.find(tipo, "dir") or string.find(tipo, "right") then
                player.velocidade_x = 12.0
                player.velocidade_y = -2.0
            elseif string.find(tipo, "baixo") or string.find(tipo, "down") then
                player.velocidade_x = 0
                player.velocidade_y = 10.0
            else
                player.velocidade_x = -12.0
                player.velocidade_y = -2.0
            end

            player.rodando = true
            player.no_chao = false
            player.pulou_mola = true
            if player.vulneravel_mola_cima then
                if player.no_chao then
                    player.vulneravel_mola_cima = false
                    player.vulneravel_mola_cima_timer = nil
                    player.pulou_mola = false
                elseif player.vulneravel_mola_cima_timer then
                    player.vulneravel_mola_cima_timer = player.vulneravel_mola_cima_timer - 1
                    if player.vulneravel_mola_cima_timer <= 0 then
                        player.vulneravel_mola_cima = false
                        player.vulneravel_mola_cima_timer = nil
                        player.pulou_mola = false
                    end
                end
            end
            return true
        end
    end
    return false
end

local function verificar_gatilho(player, mapa, old_x, old_y)
    if not player.rodando then return end
    local vel_abs = math.abs(player.velocidade_x)
    if vel_abs < LIMIAR_MOLA then return end

    local min_x = math.min(old_x, player.x)
    local min_y = math.min(old_y, player.y)
    local max_x = math.max(old_x, player.x) + 16
    local max_y = math.max(old_y, player.y) + 32
    local width = max_x - min_x
    local height = max_y - min_y

    if mapa.colide_joga(min_x, min_y, width, height) then
        local forca = FORCA_MOLA_BASE - (vel_abs * FATOR_VELOCIDADE_MOLA)
        if forca < FORCA_MOLA_MAX then forca = FORCA_MOLA_MAX end
        player.velocidade_y = forca
        player.no_chao = false
        player.rodando = false
        player.pulou_mola = true
    end
end

local function verificar_especiais(player, mapa, old_x, old_y)
    local buffs = get_buffs()
    local invencivel_monitor = buffs and buffs.invencivel and buffs.invencivel > 0

    if not player.morto and (player.timer_invencivel or 0) <= 0 and not invencivel_monitor and mapa.colide_dano(player.x, player.y, 16, 32) then
        PlayerSystem.aplicar_dano(player)
    end

    if not player.morto then
        verificar_gatilho(player, mapa, old_x, old_y)
    end

    if not player.em_queda then
        for _, sensor in ipairs(mapa.get_sensores_queda and mapa.get_sensores_queda() or {}) do
            local px0, py0, px1, py1 = PlayerSystem.get_hitbox(player)
            if px0 < sensor.x + sensor.w and px1 > sensor.x and py0 < sensor.y + sensor.h and py1 > sensor.y then
                player.em_queda = true
                player.em_dano = true
                player.timer_invencivel = 120
                player.velocidade_y = -5
                player.no_chao = false
                player.rodando = false
                break
            end
        end
    end
end

function PlayerSystem.resolver_monitores(player, objetos)
    if not objetos or not objetos.outros then return end

    local px0 = player.x - COLISAO_HALF_W + COLISAO_OFFSET_X
    local px1 = player.x + COLISAO_HALF_W + COLISAO_OFFSET_X
    local py0 = player.y + COLISAO_TOPO_Y
    local py1 = player.y + COLISAO_BASE_Y

    for _, o in ipairs(objetos.outros) do
        if o.tipo == 'monitores' and not o.coletado then
            local MON_W, MON_H = 16, 16
            local mx0 = o.x + (o.w - MON_W) / 2
            local my0 = o.y + (o.h - MON_H) / 2
            local mx1 = mx0 + MON_W
            local my1 = my0 + MON_H

            if px0 < mx1 and px1 > mx0 and py0 < my1 and py1 > my0 then
                local rolou = player.rodando and math.abs(player.velocidade_x) > 1.0
                local pulou_em_cima = player.velocidade_y > 0 and py1 < my0 + 4

                if rolou or pulou_em_cima then
                    o.coletado = true
                    local Objetos = require("sistemas.objetos")
                    Objetos._aplicar_monitor(o.nome, State, mx0 + MON_W / 2, my0 + MON_H / 2)
                    if pulou_em_cima then
                        PlayerSystem.aplicar_bounce(player)
                    elseif rolou then
                        player.velocidade_x = player.velocidade_x * 0.85
                    end
                else
                    local overlap_x = math.min(px1, mx1) - math.max(px0, mx0)
                    local overlap_y = math.min(py1, my1) - math.max(py0, my0)

                    if overlap_x < overlap_y then
                        local half_w = PlayerSystem.COLISAO_HALF_W
                        local offset_x = PlayerSystem.COLISAO_OFFSET_X or 0
                        if px0 < mx0 then
                            player.x = mx0 - half_w - offset_x
                        else
                            player.x = mx1 + half_w - offset_x
                        end
                        player.velocidade_x = 0
                    else
                        if py0 < my0 then
                            player.y = my0 - PlayerSystem.COLISAO_BASE_Y
                            player.velocidade_y = 0
                        else
                            player.y = my1 - PlayerSystem.COLISAO_TOPO_Y
                            player.velocidade_y = 0
                        end
                    end
                end
            end
        end
    end
end

function PlayerSystem.aplicar_dano(player)
    if player.morto then return end
    local buffs = get_buffs()
    if buffs and buffs.invencivel and buffs.invencivel > 0 then return end
    if (player.timer_invencivel or 0) > 0 then return end

    if State.buffs and State.buffs.escudo then
        State.buffs.escudo = false
        player.timer_invencivel = TEMPO_INVENCIVEL
        player.em_dano = true
        player.velocidade_y = -5
        player.velocidade_x = -3 * player.direcao
        player.no_chao = false
        player.rodando = false
        player.pulou_mola = false
        player.pendulo_atual = nil
        return
    end

    player.em_dano = true
    player.vulneravel_mola_cima = false

    if State.inventory.aneis > 0 then
        local quantidade_aneis = State.inventory.aneis
        State.inventory.aneis = 0
        player.timer_invencivel = TEMPO_INVENCIVEL
        player.velocidade_y = -5
        player.velocidade_x = -3 * player.direcao
        player.no_chao = false
        player.rodando = false
        player.pulou_mola = false
        player.pendulo_atual = nil
        if Aneis.espalhar_aneis then
            Aneis.espalhar_aneis(player.x, player.y, quantidade_aneis)
        end
    else
        player.morto = true
        player.timer_morte = 0
        player.velocidade_y = -8
        player.velocidade_x = -3 * player.direcao
        player.no_chao = false
        player.pulou_mola = false
        player.pendulo_atual = nil
    end
end

function PlayerSystem.aplicar_bounce(player)
    player.velocidade_y = FORCA_BOUNCE
    player.no_chao = false
    player.plataforma_atual = nil
    player.pendulo_atual = nil
    player.y = player.y - 1
    player.bounce_frames = DURACAO_BOUNCE
end

function PlayerSystem.get_hitbox(player)
    local x0 = player.x - COLISAO_HALF_W + COLISAO_OFFSET_X
    local x1 = player.x + COLISAO_HALF_W + COLISAO_OFFSET_X
    local y0 = player.y + COLISAO_TOPO_Y
    local y1 = player.y + COLISAO_BASE_Y
    return x0, y0, x1, y1
end

PlayerSystem.COLISAO_HALF_W = COLISAO_HALF_W
PlayerSystem.COLISAO_TOPO_Y = COLISAO_TOPO_Y
PlayerSystem.COLISAO_BASE_Y = COLISAO_BASE_Y
PlayerSystem.COLISAO_OFFSET_X = COLISAO_OFFSET_X

function PlayerSystem.update(player, input, mapa, pode_pular, pendulos, objetos)
    if player.morto then
        player.timer_morte = player.timer_morte + 1
        player.velocidade_y = player.velocidade_y + GRAVIDADE
        player.y = player.y + player.velocidade_y
        player.em_queda = false

        if player.timer_morte > 60 then
            State.vidas = State.vidas - 1
            player.em_queda = false

            if State.vidas <= 0 then
                if State.continuacoes and State.continuacoes > 0 then
                    State.continuacoes = State.continuacoes - 1
                    State.vidas = 3
                    State.resetar_estado_fase()
                    State.proxima_cena = State.SCREEN_GAME
                    local Transicao = require("sistemas.transicao")
                    if not Transicao.ativa then Transicao.iniciar() end
                else
                    State.proxima_cena = State.SCREEN_GAME_OVER
                    local Transicao = require("sistemas.transicao")
                    if not Transicao.ativa then Transicao.iniciar() end
                end
                player.morto = false
                player.timer_morte = 0
                player.velocidade_x = 0
                player.velocidade_y = 0
            else
                player.morto = false
                player.timer_morte = 0
                if State.checkpoint_ativo then
                    player.x = State.checkpoint_x
                    player.y = State.checkpoint_y
                else
                    player.x = player.spawn_x
                    player.y = player.spawn_y
                end
                player.velocidade_x = 0
                player.velocidade_y = 0
                player.no_chao = true
                player.rodando = false
                player.pulou_mola = false
                player.pendulo_atual = nil
                player.sprite = "parado"
                player.timer_invencivel = 0
                player.em_dano = false

                Timer.init()
            end
        end

        Animacao.atualizar(player)
        return
    end

    if player.y > mapa.altura + 100 then
        player.morto = true
        player.timer_morte = 0
        player.velocidade_y = -5
        player.pulou_mola = false
        player.pendulo_atual = nil
    end

    if player.timer_invencivel and player.timer_invencivel > 0 then
        player.timer_invencivel = player.timer_invencivel - 1
        if math.floor(player.timer_invencivel / TEMPO_PISCA) % 2 == 0 then
            player.invisivel_visual = false
        else
            player.invisivel_visual = true
        end
    else
        player.invisivel_visual = false
    end

    if player.bounce_frames and player.bounce_frames > 0 then
        player.bounce_frames = player.bounce_frames - 1
    end

    local old_x = player.x
    local old_y = player.y

    if player.no_chao and player.plataforma_atual then
        local pl = player.plataforma_atual
        if player.x + 16 > pl.x - 4 and player.x < pl.x + pl.largura + 4 then
            player.x = player.x + pl.delta_x
            if math.abs((player.y + 32) - pl.y) < 8 then
                player.y = pl.y - 32
                player.velocidade_y = 0
                player.no_chao = true
            end
        else
            player.plataforma_atual = nil
        end
    end

    if player.no_chao and player.pendulo_atual then
        player.x = player.x + player.pendulo_atual.delta_x
        player.y = player.y + player.pendulo_atual.delta_y
        if math.abs(player.x - player.pendulo_atual.x_plataforma) > 16 then
            player.no_chao = false
            player.pendulo_atual = nil
        end
    end

    if player.no_chao and not player.pendulo_atual and not player.plataforma_atual then
        manter_no_suporte(player, mapa)
    end

    verificar_mola(player, mapa)

    atualizar_horizontal(player, input, mapa)
    atualizar_colisao_horizontal(player, mapa)
    atualizar_vertical(player, input, pode_pular, mapa, pendulos, objetos)
    if player.em_queda and player.no_chao then
        player.em_queda = false
        player.em_dano = false
        player.vulneravel_mola_cima = false
    end

    if player.vulneravel_mola_cima and player.no_chao then
        player.vulneravel_mola_cima = false
        player.pulou_mola = false
    end
    atualizar_estado_parado(player, input)
    verificar_especiais(player, mapa, old_x, old_y)

    PlayerSystem.resolver_monitores(player, objetos)

    Animacao.atualizar(player)
end

function PlayerSystem.draw(player)
    if player.invisivel_visual then return end
    local px = math.floor(player.x + 0.5)
    local py = math.floor(player.y + 0.5)
    local sprite = Animacao.sprite_atual(player)
    if sprite then
        local draw_y = py
        if type(sprite.height) == "number" and sprite.height < 32 then
            draw_y = py + (32 - sprite.height)
        end
        ui.spr(sprite, px - SPRITE_ANCORA_X, draw_y, player.direcao < 0, false)
    end
end

function PlayerSystem.atualizar_oxigenio(player, mapa)
    if not player or player.morto then return end

    if not State.oxigenio then
        State.oxigenio = {
            tempo_maximo = 20 * 60,
            tempo_restante = 0,
            na_agua = false,
            morrendo = false,
            timer_morte = 0,
        }
    end

    local oxi = State.oxigenio

    local areas = mapa.get_areas_agua and mapa.get_areas_agua() or {}
    local na_agua_agora = false
    for _, area in ipairs(areas) do
        if player.x > area.x and player.x < area.x + area.w and
           player.y > area.y and player.y < area.y + area.h then
            na_agua_agora = true
            break
        end
    end

    if na_agua_agora and not oxi.na_agua then
        oxi.na_agua = true
        oxi.tempo_restante = oxi.tempo_maximo
        oxi.morrendo = false
    elseif not na_agua_agora and oxi.na_agua then
        oxi.na_agua = false
        oxi.tempo_restante = 0
        oxi.morrendo = false
    end

    if oxi.na_agua and not oxi.morrendo then
        oxi.tempo_restante = oxi.tempo_restante - 1

        if oxi.tempo_restante > 5 * 60 and oxi.tempo_restante % 60 == 0 then
            -- TODO: sfx.fx(ID_SOM_AVISO_NORMAL)
        end

        if oxi.tempo_restante <= 5 * 60 and oxi.tempo_restante > 0 then
            if oxi.tempo_restante % 15 == 0 then
                -- TODO: sfx.fx(ID_SOM_AVISO_RAPIDO)
            end
        end

        if oxi.tempo_restante <= 0 then
            oxi.morrendo = true
            oxi.timer_morte = 0
            -- TODO: sfx.fx(ID_SOM_AFOGANDO)
        end
    end

    if oxi.morrendo then
        oxi.timer_morte = oxi.timer_morte + 1
        player.velocidade_x = 0
        player.rodando = false

        if oxi.timer_morte >= 120 then
            player.morto = true
            player.timer_morte = 0
            player.velocidade_y = -5
            oxi.morrendo = false
            oxi.na_agua = false
        end
    end
end

return PlayerSystem
