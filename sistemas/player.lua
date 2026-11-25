local Animacao = require("sistemas.animacao")
local State    = require("state")
local Timer    = require("sistemas.timer")
local Aneis    = require("sistemas.aneis")
local UI       = require("sistemas.ui")
local Sprites  = require("sistemas.sprites")

local PlayerSystem = {}

local ALTURA_PLAYER   = 32
local ALTURA_COLISAO  = 28
local SPRITE_ANCORA_X = 16

local COLISAO_HALF_W   = 6
local COLISAO_TOPO_Y   = 4
local COLISAO_BASE_Y   = 28
local COLISAO_OFFSET_X = -3

local ACELERACAO               = 0.050
local VELOCIDADE_MAXIMA        = 4.0
local DESACELERACAO            = 0.08
local ACELERACAO_AR            = 0.12
local DESACELERACAO_AR         = 0.06
local VELOCIDADE_MAXIMA_AR     = 4.0
local DESACELERACAO_CONTRARIA  = 0.7
local VELOCIDADE_TENSAO        = 0.5
local FORCA_GRAVIDADE_RAMPA    = 0.25
local GRAVIDADE                = 0.32
local FORCA_PULO               = -8.0
local CORTE_PULO               = 0.20
local LIMIAR_MOLA              = 4.5
local FORCA_MOLA_BASE          = -10
local FATOR_VELOCIDADE_MOLA    = 1.2
local FORCA_MOLA_MAX           = -19
-- colisao_joga: rampa de lancamento. Arco, nao tiro vertical.
local JOGA_VY_BASE   = -6     -- componente vertical base
local JOGA_VY_FATOR  = -1.9  -- ganho vertical por px/frame de velocidade
local JOGA_VY_TETO   = -15
local JOGA_VX_FATOR  = 0.75   -- ganho horizontal
local JOGA_VX_TETO   = 8
local LIMITE_AR_JOGA = 9   -- teto de vx durante o voo da rampa
local FRICCAO_ROLAR            = 0.995
local FRICCAO_ROLAR_PLANO      = 0.06
local VELOCIDADE_MINIMA_ROLAR  = 0.2
local PASSO_MAXIMO             = 4
local MARGEM_SEGURANCA_RAMPA   = 16
local TEMPO_INVENCIVEL         = 140
local TEMPO_PISCA              = 6
-- Pop da morte por queda: mais alto que o -8 da morte comum, para
-- chegar acima do meio da tela antes de cair de volta.
local FORCA_MORTE_QUEDA = -9.5

-- QUIQUE (ajustável) --------------------------------------------------
-- FORCA_BOUNCE .. FORCA_BOUNCE_MAX = faixa do quique em px/frame.
-- FATOR_BOUNCE = quanto da velocidade de impacto é reaproveitada.
-- FATOR_GRAVIDADE_BOUNCE era 0.222: com -6 e 12 frames o Sonic subia
-- ~107px (mais que o pulo inteiro). Com 1.0 o quique fica em ~56px.
local FORCA_BOUNCE            = -6
local FORCA_BOUNCE_MAX        = -8
local FATOR_BOUNCE            = 0.75
local DURACAO_BOUNCE          = 12
local FATOR_GRAVIDADE_BOUNCE  = 1.0
-- Molas de sala especial (classe mola_esp)
local REST_ESPIRAL       = 0.85  -- restituição (1.0 = elástico perfeito)
local MIN_ESPIRAL        = 4.0   -- saída mínima, para não "morrer" na mola
local MAX_ESPIRAL        = 8.0   -- teto: antes era 11 fixo, forte demais
local RAIO_SONIC_MOLA    = 8     -- raio de contato do Sonic contra o capsule
local COOLDOWN_MOLA_ESP  = 12    -- frames sem reacionar a mesma mola
local LIMITE_AR_ESP      = 14.0  -- teto de vx durante o voo de mola especial

local BUFFS_PADRAO = { invencivel = 0, velocidade_extra = 0, escudo = false }

local function aproximar_zero(valor, quantidade)
    if valor > 0 then return math.max(0, valor - quantidade) end
    if valor < 0 then return math.min(0, valor + quantidade) end
    return 0
end

-- Buffs do PROPRIO player. O fallback em State.buffs cobre qualquer
-- chamada antiga que ainda passe nil.
local function get_buffs(player)
    return (player and player.buffs) or State.buffs or BUFFS_PADRAO
end

local function atualizar_horizontal(player, input, mapa)
    local esquerda = input.is_action("left", 0)
    local direita  = input.is_action("right", 0)
    local baixo    = input.is_action("down", 0)
    local vel_abs  = math.abs(player.velocidade_x)
    local buffs    = get_buffs()

    local aceleracao = ACELERACAO
    local vel_max    = VELOCIDADE_MAXIMA
    if buffs and buffs.velocidade_extra and buffs.velocidade_extra > 0 then
        aceleracao = ACELERACAO * 1.5
        vel_max    = VELOCIDADE_MAXIMA + 3
    end

    local na_agua = false
    local areas = mapa.get_areas_agua and mapa.get_areas_agua() or {}
    for _, area in ipairs(areas) do
        if player.x > area.x and player.x < area.x + area.w
        and player.y > area.y and player.y < area.y + area.h then
            na_agua = true; break
        end
    end
    if na_agua then
        aceleracao = aceleracao * 0.5
        vel_max    = vel_max * 0.6
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
        -- o voo de mola especial precisa manter a velocidade do rebote,
        -- senão o teto normal (6) corta o alcance horizontal da espiral
        local teto_ar = VELOCIDADE_MAXIMA_AR
        if player.em_mola_esp then teto_ar = LIMITE_AR_ESP end
        if player.em_joga then teto_ar = LIMITE_AR_JOGA end
        player.velocidade_x = math.max(-teto_ar, math.min(player.velocidade_x, teto_ar))
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
    local segurando     = input.is_action("confirm", 0)
    local em_plataforma = player.plataforma_atual ~= nil
    local deve_pular = (player.no_chao or em_plataforma) and (apertou_agora or (pode_pular and segurando))
    if deve_pular then
        player.velocidade_y = FORCA_PULO
        player.no_chao      = false
        player.rodando      = false
        player.esta_pulando = true   -- forma de bola no ar (rodando é false no pulo)
        player.pulou_mola   = false
        player.plataforma_atual = nil
        if player.pendulo_atual then
            player.velocidade_x = player.velocidade_x + (player.pendulo_atual.delta_x * 2)
            player.pendulo_atual = nil
        end
    end
end

local function cortar_pulo(player, input)
    if player.pulou_mola then return end
    if player.em_mola_esp then return end
    if player.bounce_frames and player.bounce_frames > 0 then return end
    if player.em_dano then return end
    if not input.is_action("confirm", 0) and player.velocidade_y < 0 then
        player.velocidade_y = player.velocidade_y * CORTE_PULO
    end
end

local function manter_no_suporte(player, mapa)
    local pes_y = player.y + ALTURA_PLAYER
    local suporte, segmento = mapa.suporte_info(player.x, pes_y, 8)
    if not suporte or not segmento then player.no_chao = false; return false end
    local TOLERANCIA_BORDA = 1
    if player.x < segmento.inicio - TOLERANCIA_BORDA or player.x > segmento.fim + TOLERANCIA_BORDA then
        player.no_chao = false; return false
    end
    if math.abs(pes_y - suporte) > 2 then player.no_chao = false; return false end
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

    -- Velocidade de impacto ANTES de resolver o pouso. O pouso zera
    -- velocidade_y; sem isto a colisão nunca vê o Sonic "caindo".
    player.vy_impacto = player.velocidade_y

    local pes_atual = pes_anterior + player.velocidade_y

    if player.velocidade_y < 0 and mapa.colide_teto then
        local topo_anterior = pes_anterior - ALTURA_PLAYER + COLISAO_TOPO_Y
        local topo_atual    = pes_atual - ALTURA_PLAYER + COLISAO_TOPO_Y
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

    -- Tabuas de ponte: x pela HITBOX (12px), nao pelo sprite. O teste
    -- folgado das plataformas deixaria o Sonic apoiado no ar ao lado
    -- de uma tabua de 16px.
    if objetos and objetos.pontes and player.velocidade_y >= 0 then
        local hx0, _, hx1 = PlayerSystem.get_hitbox(player)
        for _, tb in ipairs(objetos.pontes) do
            if tb.estado == "intacta" or tb.estado == "pisada" or tb.estado == "caindo" then
                if hx1 > tb.x and hx0 < tb.x + tb.largura
                and pes_anterior <= tb.y and pes_atual >= tb.y then
                    player.y = tb.y - ALTURA_PLAYER
                    player.velocidade_y = 0
                    player.no_chao = true
                    player.pulou_mola = false
                    player.plataforma_atual = tb
                    return
                end
            end
        end
    end

    -- Balancas: grava o impacto para a catapulta calcular a forca.
    if objetos and objetos.balancas_lados and player.velocidade_y >= 0 then
        local hx0, _, hx1 = PlayerSystem.get_hitbox(player)
        for _, s in ipairs(objetos.balancas_lados) do
            if hx1 > s.x and hx0 < s.x + s.largura
            and pes_anterior <= s.y and pes_atual >= s.y then
                player.y = s.y - ALTURA_PLAYER
                s.impacto = player.vy_impacto or 0
                player.velocidade_y = 0
                player.no_chao = true
                player.pulou_mola = false
                player.plataforma_atual = s
                return
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
        local pouso = mapa.aterrissagem(player.x, pes_anterior, pes_atual, 16)
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
    player.olhando_cima  = parado and input.is_action("up", 0)
    player.olhando_baixo = parado and input.is_action("down", 0)
end

local function atualizar_colisao_horizontal(player, mapa)
    -- Cutscene de fim de ato (placa_final E capsula): o Sonic corre para
    -- fora da tela. Precisa ignorar os DOIS bloqueios — o limitar_x do
    -- mapa e o bateu_parede do terreno — senao ele fica preso na parede
    -- do final da fase. O snap de rampa continua ativo.
    local cutscene = State.cela_cutscene == true
    local velocidade_x = player.velocidade_x
    local passos = math.max(1, math.ceil(math.abs(velocidade_x) / PASSO_MAXIMO))
    local passo_x = velocidade_x / passos
    for _ = 1, passos do
        local x_anterior = player.x
        local x_novo = player.x + passo_x
        local pes_y = player.y + ALTURA_PLAYER
        local suporte, bateu_parede
        if cutscene then
            x_novo = x_anterior + passo_x
            suporte = mapa.altura_suporte(x_novo, pes_y, MARGEM_SEGURANCA_RAMPA)
            bateu_parede = false
        else
            x_novo = mapa.limitar_x(x_novo)
            x_novo, suporte, bateu_parede = mapa.movimento_horizontal(x_anterior, x_novo, pes_y, ALTURA_COLISAO)
        end
        if bateu_parede then
            player.x = x_novo
            player.velocidade_x = 0
            break
        end
        if player.no_chao and not player.pendulo_atual and not player.plataforma_atual then
            if suporte then player.y = suporte - ALTURA_PLAYER else player.no_chao = false end
        end
        player.x = x_novo
        if x_novo == x_anterior then player.velocidade_x = 0; break end
    end
end

-- ============================================================
-- MOLAS DE SALA ESPECIAL (classe mola_esp)
--   mola_espiral : capsule vertical, rebote com força fixa na
--                  direção da normal (ângulo em que o Sonic bate)
--   mola_cima    : mesmo fluxo da mola vertical, mas o Sonic fica
--                  em forma de bola (sem animação pula_mola)
-- Usam cooldown próprio em vez de pulou_mola, para permitir
-- emendar várias molas no ar como no original.
-- ============================================================
local function verificar_mola_esp(player, mapa)
    if player.mola_esp_cooldown and player.mola_esp_cooldown > 0 then return false end
    local molas = mapa.get_molas and mapa.get_molas() or {}
    local pcx = player.x + COLISAO_OFFSET_X
    local pcy = player.y + 16
    for _, m in ipairs(molas) do
        if m.classe == "mola_esp" then
            if m.tipo == "mola_espiral" then
                local r   = m.raio or (m.largura / 2)
                local ax  = m.eixo_x or (m.x + m.largura / 2)
                local ay1 = m.eixo_y1 or (m.y + r)
                local ay2 = m.eixo_y2 or (m.y + m.altura - r)
                if ay2 < ay1 then ay2 = ay1 end
                local ay = math.max(ay1, math.min(pcy, ay2))
                local dx, dy = pcx - ax, pcy - ay
                local dist = math.sqrt(dx * dx + dy * dy)
                if dist < r + RAIO_SONIC_MOLA then
                    local nx, ny
                    if dist < 0.001 then
                        nx, ny = 0, -1
                    else
                        nx, ny = dx / dist, dy / dist
                    end
                    -- Reflete o vetor de entrada na normal da cápsula:
                    -- v' = v - (1+rest) * (v·n) * n
                    -- O Sonic sai num ângulo espelhado ao de chegada, preservando a componente tangencial (o "deslize").
                    local vn = player.velocidade_x * nx + player.velocidade_y * ny
                    if vn < 0 then
                        local vx = player.velocidade_x - (1 + REST_ESPIRAL) * vn * nx
                        local vy = player.velocidade_y - (1 + REST_ESPIRAL) * vn * ny
                        local teto = (m.forca and m.forca > 0) and m.forca or MAX_ESPIRAL
                        local mag = math.sqrt(vx * vx + vy * vy)
                        if mag < MIN_ESPIRAL then
                            vx, vy = nx * MIN_ESPIRAL, ny * MIN_ESPIRAL
                        elseif mag > teto then
                            local k = teto / mag
                            vx, vy = vx * k, vy * k
                        end
                        player.velocidade_x = vx
                        player.velocidade_y = vy
                    end
                    -- reposiciona para fora do capsule: evita recolisão imediata
                    local alvo = r + RAIO_SONIC_MOLA + 1
                    player.x = ax + nx * alvo - COLISAO_OFFSET_X
                    player.y = ay + ny * alvo - 16
                    player.no_chao            = false
                    player.rodando            = true
                    player.esta_pulando       = false
                    player.pulou_mola         = false
                    player.vulneravel_mola_cima = false
                    player.em_mola_esp        = true
                    player.plataforma_atual   = nil
                    player.pendulo_atual      = nil
                    player.mola_esp_cooldown  = COOLDOWN_MOLA_ESP
                    if math.abs(nx) > 0.2 then
                        player.direcao = (nx > 0) and 1 or -1
                    end
                    return true
                end
            else
                local p_x, p_y, p_w, p_h = player.x + 4, player.y + 4, 8, 24
                if player.velocidade_y >= 0
                and p_x < m.x + m.largura and p_x + p_w > m.x
                and p_y < m.y + m.altura and p_y + p_h > m.y then
                    player.velocidade_x = 0
                    player.velocidade_y = -((m.forca and m.forca > 0) and m.forca or 13.5)
                    player.no_chao            = false
                    player.rodando            = true
                    player.esta_pulando       = false
                    player.pulou_mola         = false
                    player.vulneravel_mola_cima = false
                    player.em_mola_esp        = true
                    player.plataforma_atual   = nil
                    player.pendulo_atual      = nil
                    player.mola_esp_cooldown  = COOLDOWN_MOLA_ESP
                    return true
                end
            end
        end
    end
    return false
end

-- O parser grava forca = 0 quando o objeto nao tem a propriedade no Tiled.
-- Em Lua 0 e verdadeiro, entao "m.forca or 13.5" devolveria 0 e a mola
-- lancaria com forca ZERO. Precisa do teste > 0, como na mola_esp.
local function forca_mola(m, padrao)
    local f = m.forca
    if f and f > 0 then return f end
    return padrao
end

local function verificar_mola(player, mapa)
if player.pulou_mola then return false end
    -- Caixa pela HITBOX, nao por player.x+4: aquele offset jogava a
    -- janela 8px para a direita do centro do sprite, e uma mola de 10px
    -- so pegava 1px quando o Sonic estava visualmente em cima dela.
    local p_x, p_y, p_x1, p_y1 = PlayerSystem.get_hitbox(player)
    local p_w, p_h = p_x1 - p_x, p_y1 - p_y
    for _, m in ipairs(mapa.get_molas()) do
        if m.classe ~= "mola_esp"
            and p_x < m.x + m.largura and p_x + p_w > m.x
            and p_y < m.y + m.altura and p_y + p_h > m.y then
            local tipo = m.tipo or ""
            local eh_cima = (string.find(tipo, "cima") or string.find(tipo, "up")) and true or false

            -- Mola vertical so dispara com o Sonic CAINDO sobre ela.
            -- Andando no chao (no_chao) ou subindo (vy <= 0) nao lanca.
            -- As outras direcoes continuam disparando por toque.
            local libera = true
            if eh_cima then
                local caindo_agora = (not player.no_chao) and player.velocidade_y > 0
                -- Frame seguinte ao pouso: velocidade_y já virou 0 e
                -- no_chao virou true, mas vy_impacto ainda guarda a
                -- velocidade da queda. Sem isto, quedas rápidas pulavam
                -- a faixa de 6px acima do chão e a mola nunca disparava.
                -- Andando no chão vy_impacto é só 0.32 (gravidade de 1
                -- frame), então continua NÃO lançando ao andar.
                local acabou_de_pousar = player.no_chao and (player.vy_impacto or 0) > 1.0
                libera = caindo_agora or acabou_de_pousar
            end

            if libera then
                if eh_cima then
                    player.velocidade_x = 0
                    player.velocidade_y = -forca_mola(m, 13.5)
                    player.vulneravel_mola_cima = true
                    player.vulneravel_mola_cima_timer = 300
                elseif string.find(tipo, "dir") or string.find(tipo, "right") then
                    player.velocidade_x = forca_mola(m, 12.0)
                    player.velocidade_y = -2.0
                elseif string.find(tipo, "baixo") or string.find(tipo, "down") then
                    player.velocidade_x = 0
                    player.velocidade_y = forca_mola(m, 10.0)
                else
                    player.velocidade_x = -forca_mola(m, 12.0)
                    player.velocidade_y = -2.0
                end
                player.rodando      = true
                player.no_chao      = false
                player.pulou_mola   = true
                player.esta_pulando = false
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
    local width  = max_x - min_x
    local height = max_y - min_y
    if mapa.colide_joga(min_x, min_y, width, height) then
        -- Escala com a velocidade, mas reparte em arco: menos vertical,
        -- mais horizontal. A gravidade normal fecha o arco.
        local vy = JOGA_VY_BASE + vel_abs * JOGA_VY_FATOR
        if vy < JOGA_VY_TETO then vy = JOGA_VY_TETO end
        local sinal = (player.velocidade_x >= 0) and 1 or -1
        local vx = math.min(JOGA_VX_TETO, vel_abs * JOGA_VX_FATOR)
        player.velocidade_y = vy
        player.velocidade_x = sinal * vx
        player.no_chao      = false
        player.rodando      = false
        player.pulou_mola   = true
        player.esta_pulando = false
        player.em_joga      = true
    end
end

local function verificar_especiais(player, mapa, old_x, old_y)
    local buffs = get_buffs()
    local invencivel_monitor = buffs and buffs.invencivel and buffs.invencivel > 0
    if not player.morto and (player.timer_invencivel or 0) <= 0 and not invencivel_monitor
    and mapa.colide_dano(player.x, player.y, 16, 32) then
        PlayerSystem.aplicar_dano(player)
    end

    if not player.morto then verificar_gatilho(player, mapa, old_x, old_y) end

    if not player.em_queda then
        for _, sensor in ipairs(mapa.get_sensores_queda and mapa.get_sensores_queda() or {}) do
            local px0, py0, px1, py1 = PlayerSystem.get_hitbox(player)
            if px0 < sensor.x + sensor.w and px1 > sensor.x
            and py0 < sensor.y + sensor.h and py1 > sensor.y then
                player.em_queda = true
                player.em_dano  = true
                -- não encurta a invulnerabilidade de quem já estava piscando
                player.timer_invencivel = math.max(player.timer_invencivel or 0, 120)
                player.velocidade_y = -5
                player.no_chao      = false
                player.rodando      = false
                player.esta_pulando = false
                player.bola_no_frame = false
                break
            end
        end
    end
end

-- ============================================================
-- FORMA DE BOLA / ATAQUE — fonte única de verdade
-- Consumida por inimigos.lua, resolver_monitores e chefe.lua
-- ============================================================
function PlayerSystem.em_bola(player)
    if not player or player.morto then return false end
    if player.em_dano or player.em_queda then return false end
    -- mola vertical: no original o Sonic NÃO está em forma de bola
    if player.vulneravel_mola_cima and not player.no_chao then return false end
    if player.rodando then return true end
    return player.esta_pulando == true and not player.no_chao
end

function PlayerSystem.pode_atacar(player)
    if PlayerSystem.em_bola(player) then return true end
    local b = get_buffs()
    return (b and b.invencivel and b.invencivel > 0) and true or false
end

function PlayerSystem.contexto_ataque(player)
    local b  = get_buffs()
    local vy = player.vy_impacto or player.velocidade_y or 0
    return {
        -- bola_no_frame = estado ANTES da física deste frame.
        -- Cobre o caso "pousei no chão no mesmo frame em que encostei".
        atacando = (player.bola_no_frame == true) or PlayerSystem.em_bola(player),
        invencivel_ofensivo  = (b and b.invencivel and b.invencivel > 0) and true or false,
        invencivel_defensivo = (player.timer_invencivel or 0) > 0,
        caindo     = vy > 0,
        vy_impacto = vy,
        pes_prev   = (player.y_prev or player.y) + ALTURA_PLAYER,
    }
end

-- Resolve o acerto contra qualquer alvo (inimigo / monitor / chefe).
-- alvo_topo = y do topo da caixa do alvo; tol = folga do "veio de cima".
-- Retorna true se o alvo deve ser destruído.
function PlayerSystem.acertar_alvo(player, alvo_topo, tol)
    local ctx = PlayerSystem.contexto_ataque(player)
    if not (ctx.atacando or ctx.invencivel_ofensivo) then return false end
    -- estrelas: destrói sem quique
    if ctx.invencivel_ofensivo and not ctx.atacando then return true end
    if ctx.caindo and ctx.pes_prev <= alvo_topo + (tol or 6) then
        PlayerSystem.aplicar_bounce(player, ctx.vy_impacto)
    elseif player.rodando and player.no_chao then
        player.velocidade_x = player.velocidade_x * 0.85
    end
    return true
end

function PlayerSystem.resolver_monitores(player, objetos)
    if not objetos or not objetos.outros then return end
    local px0, py0, px1, py1 = PlayerSystem.get_hitbox(player)
    for _, o in ipairs(objetos.outros) do
        if o.tipo == 'monitores' and not o.coletado then
            local MON_W, MON_H = 16, 16
            local mx0 = o.x + (o.w - MON_W) / 2
            local my0 = o.y + (o.h - MON_H) / 2
            local mx1 = mx0 + MON_W
            local my1 = my0 + MON_H
            if px0 < mx1 and px1 > mx0 and py0 < my1 and py1 > my0 then
                local overlap_x = math.min(px1, mx1) - math.max(px0, mx0)
                local overlap_y = math.min(py1, my1) - math.max(py0, my0)
                local ctx = PlayerSystem.contexto_ataque(player)
                -- cabeça ANTES da física deste frame: se já estava abaixo
                -- da base do monitor e subindo, veio de baixo.
                local cabeca_prev = (player.y_prev or player.y) + PlayerSystem.COLISAO_TOPO_Y
                local veio_de_baixo = cabeca_prev >= my1 - 2 and ctx.vy_impacto < 0

                if veio_de_baixo and overlap_y <= overlap_x then
                    -- Por baixo o monitor NÃO quebra: ele cai até o chão.
                    -- (a física da queda está em Objetos.update)
                    o.caindo = true
                    o.vy = 0
                    player.y = my1 - PlayerSystem.COLISAO_TOPO_Y
                    player.velocidade_y = 0
                elseif PlayerSystem.acertar_alvo(player, my0, 8) then
                    o.coletado = true
                    local Objetos = require("sistemas.objetos")
                    Objetos._aplicar_monitor(o.nome, State, mx0 + MON_W / 2, my0 + MON_H / 2, player)
                    -- o quique moveu o Sonic: recalcula para os próximos
                    px0, py0, px1, py1 = PlayerSystem.get_hitbox(player)
                else
                    -- Colisão lateral / por cima sem bola (bloqueia o Sonic)
                    if overlap_x < overlap_y then
                        local half_w   = PlayerSystem.COLISAO_HALF_W
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
                        else
                            player.y = my1 - PlayerSystem.COLISAO_TOPO_Y
                        end
                        player.velocidade_y = 0
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

    local meus = get_buffs(player)
    if meus and meus.escudo then
        meus.escudo = false
        player.timer_invencivel = TEMPO_INVENCIVEL
        player.em_dano = true
        player.velocidade_y = -5
        player.velocidade_x = -3 * player.direcao
        player.no_chao = false
        player.rodando = false
        player.esta_pulando = false
        player.bola_no_frame = false
        player.pulou_mola = false
        player.pendulo_atual = nil
        return
    end

    player.em_dano = true
    player.vulneravel_mola_cima = false
    player.esta_pulando = false
    player.bola_no_frame = false

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
        if Aneis.espalhar_aneis then Aneis.espalhar_aneis(player.x, player.y, quantidade_aneis) end
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

function PlayerSystem.aplicar_bounce(player, vy_impacto)
    local mag = math.abs(vy_impacto or player.velocidade_y or 0) * FATOR_BOUNCE
    mag = math.max(math.abs(FORCA_BOUNCE), math.min(math.abs(FORCA_BOUNCE_MAX), mag))
    player.velocidade_y     = -mag
    player.no_chao          = false
    player.plataforma_atual = nil
    player.pendulo_atual    = nil
    player.pulou_mola       = false
    player.em_dano          = false
    player.esta_pulando     = true   -- continua em forma de bola no ar
    player.bola_no_frame    = true   -- acertos seguintes no mesmo frame ainda contam
    player.bounce_frames    = DURACAO_BOUNCE
    player.y = player.y - 1
end

function PlayerSystem.get_hitbox(player)
    local x0 = player.x - COLISAO_HALF_W + COLISAO_OFFSET_X
    local x1 = player.x + COLISAO_HALF_W + COLISAO_OFFSET_X
    local y0 = player.y + COLISAO_TOPO_Y
    local y1 = player.y + COLISAO_BASE_Y
    return x0, y0, x1, y1
end

PlayerSystem.COLISAO_HALF_W   = COLISAO_HALF_W
PlayerSystem.COLISAO_TOPO_Y   = COLISAO_TOPO_Y
PlayerSystem.COLISAO_BASE_Y   = COLISAO_BASE_Y
PlayerSystem.COLISAO_OFFSET_X = COLISAO_OFFSET_X

function PlayerSystem.update(player, input, mapa, pode_pular, pendulos, objetos)
    if player.morto then
        player.bola_no_frame = false
        player.esta_pulando  = false
        -- Coop: morto esperando respawn fica congelado, sem fisica.
        if player.coop_esperando then
            Animacao.atualizar(player)
            return
        end
        player.timer_morte = player.timer_morte + 1
        if player.morte_queda then
            player.morte_vy = (player.morte_vy or 0) + GRAVIDADE
            player.morte_dy = (player.morte_dy or 0) + player.morte_vy
        else
            player.velocidade_y = player.velocidade_y + GRAVIDADE
            player.y = player.y + player.velocidade_y
        end
        player.em_queda = false
        if player.timer_morte > 60 then
            player.morte_queda = false
            player.morte_dy = 0
            player.em_queda = false
            -- COOP: custo no pool compartilhado, mas NAO reseta a fase
            -- nem vai para game over aqui. Quem decide e o Coop.atualizar
            -- (reset so com todos mortos; game over so com vidas 0).
            local Coop = require("sistemas.coop")
            if Coop.ativo then
                Coop.ao_morrer(player, State)
                Animacao.atualizar(player)
                return
            end
            State.vidas = State.vidas - 1
            if State.vidas <= 0 then
                -- SEMPRE vai para a tela de fim de jogo. Quem consome o
                -- continue e o handler de SCREEN_GAME_OVER no state.lua,
                -- depois do jogador apertar confirmar.
                -- O checkpoint e limpo aqui: da tela de game over só se
                -- sai continuando (deve limpar) ou indo pro titulo (idem).
                local Objetos = require("sistemas.objetos")
                if Objetos.limpar_checkpoint then Objetos.limpar_checkpoint() end
                State.proxima_cena = State.SCREEN_GAME_OVER
                local Transicao = require("sistemas.transicao")
                if not Transicao.ativa then Transicao.iniciar() end
                player.morto = false
                player.timer_morte = 0
                player.velocidade_x = 0
                player.velocidade_y = 0
            else
                player.morto = false
                player.timer_morte = 0
                State.espera_soltar = true
                State.proxima_cena = State.SCREEN_GAME
                State.acao_pos_transicao = function() State.resetar_estado_fase() end
                local Transicao = require("sistemas.transicao")
                if not Transicao.ativa then Transicao.iniciar() end
            end
        end
        Animacao.atualizar(player)
        return
    end

    -- Cutscene de fim de ato: ao sair da tela o Sonic DEIXA DE EXISTIR.
    -- Sem isto, em fases curtas (gh3, bz2) ele passava da borda do mapa,
    -- caia no vazio e morria/resetava a fase antes da vitoria chegar.
    -- require preguiçoso: camera.lua so exige state/terreno dentro das
    -- funções, então não há ciclo de carregamento.
    if State.cela_cutscene then
        if player.saiu_da_tela then
            player.velocidade_x = 0
            player.velocidade_y = 0
            return
        end
        local Camera = require("sistemas.camera")
        local cam_x, cam_y = Camera.get_xy()
        local sx, sy = player.x - cam_x, player.y - cam_y
        if sx > Camera.largura_tela + 32 or sx < -32
        or sy > Camera.altura_tela + 32 or sy < -32 then
            player.saiu_da_tela = true
            player.velocidade_x = 0
            player.velocidade_y = 0
            return
        end
    end

    if player.y > mapa.altura + 100 and not State.cela_cutscene then
        player.morto = true
        player.timer_morte = 0
        -- Mesma morte comum: pop para cima e gravidade traz de volta.
        -- Só reposiciona para a faixa visível (a câmera limita y a
        -- mapa.altura - 270), senão o pop acontecia abaixo da tela.
        -- A câmera segue player.y. Subir o player.y no pop fazia a
        -- câmera subir junto e ele parecia parado lá embaixo. Agora o
        -- pop anima um OFFSET de desenho, com player.y fixo.
        player.y = mapa.altura - 32
        player.velocidade_x = 0
        player.velocidade_y = 0
        player.morte_queda = true
        player.morte_dy = 0
        player.morte_vy = -9.5
        player.pulou_mola = false
        player.pendulo_atual = nil
        player.esta_pulando = false
        player.bola_no_frame = false
        Animacao.iniciar(player, "morre", 60)
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
    if player.mola_esp_cooldown and player.mola_esp_cooldown > 0 then
        player.mola_esp_cooldown = player.mola_esp_cooldown - 1
    end

    local old_x = player.x
    local old_y = player.y

    -- Latch do frame: posição e forma de bola ANTES da física.
    player.y_prev        = old_y
    player.bola_no_frame = PlayerSystem.em_bola(player)

    if player.no_chao and player.plataforma_atual then
        local pl = player.plataforma_atual
        local dentro_x
        if pl.eh_tabua or pl.eh_balanca then
            local hx0, _, hx1 = PlayerSystem.get_hitbox(player)
            dentro_x = hx1 > pl.x and hx0 < pl.x + pl.largura
        else
            dentro_x = player.x + 16 > pl.x - 4 and player.x < pl.x + pl.largura + 4
        end
        if dentro_x then
            player.x = player.x + pl.delta_x
            if pl.eh_tabua and pl.estado == "caindo" then
                -- Tabua em queda: segue o delta_y sem limite. O teste < 8
                -- abaixo soltaria o Sonic quando a tabua passasse de
                -- 8px/frame (ela chega a PONTE_VY_MAX = 10).
                player.y = player.y + (pl.delta_y or 0)
                player.velocidade_y = 0
                player.no_chao = true
            elseif math.abs((player.y + 32) - pl.y) < 8 then
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

    local usou_mola_esp = verificar_mola_esp(player, mapa)
    if not usou_mola_esp then verificar_mola(player, mapa) end
    atualizar_horizontal(player, input, mapa)
    atualizar_colisao_horizontal(player, mapa)
    atualizar_vertical(player, input, pode_pular, mapa, pendulos, objetos)

    -- cobre TODOS os caminhos de pouso (terreno, plataforma, pêndulo, rampa)
    if player.no_chao then
        player.esta_pulando = false
        player.em_mola_esp  = false
        player.em_joga      = false
    end

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

function PlayerSystem.draw(player, cam_x, cam_y)
    if player.invisivel_visual then return end
    if player.saiu_da_tela then return end
    if player.coop_esperando then return end
    local screen_x = math.floor(player.x - cam_x)
    local screen_y = math.floor(player.y + (player.morte_dy or 0) - cam_y)
    -- Totalmente fora da tela: nao desenha. Na cutscene de fim de ato o
    -- Sonic atravessa a parede e sai; sem isto ele continuaria sendo
    -- desenhado (e as estrelas/escudo junto) fora do quadro.
    -- Margens folgadas para nao cortar sprite alto (pula_mola = 40px)
    -- nem as estrelas de invencibilidade (raio 16).
    if screen_x < -40 or screen_x > 520
    or screen_y < -48 or screen_y > 300 then
        return
    end
    local sprite = Animacao.sprite_atual(player)
    if sprite then
        local draw_y = screen_y
        if type(sprite.height) == "number" and sprite.height < 32 then
            draw_y = screen_y + (32 - sprite.height)
        end
        ui.spr(sprite, screen_x - SPRITE_ANCORA_X, draw_y, player.direcao < 0, false)
    end

    local buffs = get_buffs()
    if buffs and buffs.invencivel and buffs.invencivel > 0 then
        local frame_invenc = 16
        if math.floor(Timer.contador_frames / 4) % 2 == 0 then
            frame_invenc = 20
        end
        local cx = screen_x - 6
        local cy = screen_y + 12
        local raio = 16
        local angulo_base = Timer.contador_frames * 0.15
        for i = 0, 3 do
            local ang = angulo_base + (i * math.pi / 2)
            local ex = cx + math.cos(ang) * raio
            local ey = cy + math.sin(ang) * raio
            UI.desenhar_tile_ui(frame_invenc, ex - 8, ey - 8)
        end
    end

    if buffs and buffs.escudo then
        if player.escudo_timer == nil then player.escudo_timer = 0 end
        local frame_escudo = 9
        if player.escudo_timer < 8 then
            frame_escudo = player.escudo_timer + 1
            player.escudo_timer = player.escudo_timer + 1
        end
        local deve_desenhar = true
        if frame_escudo == 9 and math.floor(Timer.contador_frames / 4) % 2 ~= 0 then
            deve_desenhar = false
        end
        if deve_desenhar then
            local sprite_escudo = Sprites.sprite("escudo_ativado", frame_escudo, player.heroi)
            if sprite_escudo then
                local cx = screen_x - 6
                local cy = screen_y + 16
                if player.rodando or not player.no_chao then
                    cy = cy + 2
                end
                local escudo_x = cx - math.floor((sprite_escudo.width or 16) / 2)
                local escudo_y = cy - math.floor((sprite_escudo.height or 16) / 2)
                ui.spr(sprite_escudo, escudo_x, escudo_y, player.direcao < 0, false)
            end
        end
    else
        player.escudo_timer = nil
    end
end

-- Ray casting: funciona em poligonos concavos. A agua da BZ1 e um
-- poligono so com cachoeiras e rio; o bbox dele cobria terra seca.
local function ponto_em_poligono(px, py, pts)
    local n = math.floor(#pts / 2)
    if n < 3 then return false end
    local dentro = false
    local j = n
    for i = 1, n do
        local xi, yi = pts[i * 2 - 1], pts[i * 2]
        local xj, yj = pts[j * 2 - 1], pts[j * 2]
        if (yi > py) ~= (yj > py) then
            local t = (py - yi) / (yj - yi)
            if px < xi + t * (xj - xi) then
                dentro = not dentro
            end
        end
        j = i
    end
    return dentro
end

function PlayerSystem.atualizar_oxigenio(player, mapa)
    if not player or player.morto then return end
    if not player.oxigenio then
        player.oxigenio = {
            tempo_maximo = 20 * 60,
            tempo_restante = 0,
            na_agua = false,
            morrendo = false,
            timer_morte = 0,
        }
    end
    local oxi = player.oxigenio
    local areas = mapa.get_areas_agua and mapa.get_areas_agua() or {}

    -- O que conta é a CABEÇA, não o corpo: no original o Sonic respira
    -- enquanto a cabeça estiver fora, mesmo com o tronco submerso.
    local cabeca_x = player.x + COLISAO_OFFSET_X
    local cabeca_y = player.y + COLISAO_TOPO_Y

    local na_agua_agora = false
    for _, area in ipairs(areas) do
        -- bbox como pre-filtro barato
        if cabeca_x > area.x and cabeca_x < area.x + area.w
        and cabeca_y > area.y and cabeca_y < area.y + area.h then
            -- forma real: sem pontos (mapas antigos) cai no bbox
            if not area.pontos or #area.pontos < 6
               or ponto_em_poligono(cabeca_x, cabeca_y, area.pontos) then
                na_agua_agora = true
                break
            end
        end
    end

    if na_agua_agora and not oxi.na_agua then
        oxi.na_agua = true
        oxi.tempo_restante = oxi.tempo_maximo
        oxi.morrendo = false
        oxi.timer_morte = 0
    elseif not na_agua_agora and oxi.na_agua then
        -- Saiu da água (inclusive pulando): fôlego volta ao máximo e o
        -- afogamento em curso é cancelado.
        oxi.na_agua = false
        oxi.tempo_restante = oxi.tempo_maximo
        oxi.morrendo = false
        oxi.timer_morte = 0
    end

    if oxi.na_agua and not oxi.morrendo then
        oxi.tempo_restante = oxi.tempo_restante - 1
        if oxi.tempo_restante <= 0 then
            oxi.tempo_restante = 0
            oxi.morrendo = true
            oxi.timer_morte = 0
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
