local Inimigos  = {}
local Sprites   = require("sistemas.sprites")
local Mapa      = require("mapa")
local PlayerSys = require("sistemas.player")
local Camera    = require("sistemas.camera")
local State     = require("state")

local GRAVIDADE_PROJETIL = 0.10
-- Orbo: detectar o Sonic pelas costas, mas 2s mais lento que de frente.
local ORBO_ATRASO_TRAS = 120
local ORBO_ALCANCE_H = 160   -- alcance horizontal (antes era raio 96 euclidiano)
local ORBO_TOL_ACIMA = 8     -- acima disso NÃO detecta
local ORBO_ALCANCE_V = 48    -- quanto abaixo do Orbo ainda detecta

local CONFIG = {
    ["motobug"] = { sprite_anda = "motobug_anda", velocidade = 1.0, largura = 15, altura = 15, padrao = "anda_chao", alcance = 48 },
    ["crab-ghz"] = { sprite_anda = "crabghz_anda", sprite_ataq = "crabghz_ataq", velocidade = 0.6, largura = 15, altura = 15, padrao = "patrulha_atira", alcance = 48, duracao_ataque = 90, cooldown_ataque = 90, velocidade_projetil_x = 2.5, velocidade_projetil_y = -2.5, alcance_arco = 125 },
    ["crab_jz"] = { sprite_anda = "crabjz_anda", sprite_ataq = "crabjz_ataq", velocidade = 0.6, largura = 21, altura = 21, padrao = "patrulha_atira", alcance = 48, duracao_ataque = 90, cooldown_ataque = 90, velocidade_projetil_x = 2.5, velocidade_projetil_y = -2.5, alcance_arco = 125 },
    ["buzz"] = { sprite_anda = "buzz_anda", sprite_ataq = "buzz_ataq", velocidade = 0.8, largura = 15, altura = 15, padrao = "voo_patrulha_atira", alcance = 48, raio_deteccao = 110, duracao_ataque = 60, cooldown_ataque = 100, tolerancia_alinhamento = 20, velocidade_projetil = 2.5 },
    ["burr"] = { sprite_anda = "burr_anda", sprite_ataq = "burr_ataq", velocidade = 1.0, largura = 13, altura = 28, padrao = "burr_esconde", raio_deteccao = 42, forca_pulo = -6.5, gravidade = 0.28, duracao_anda = 180 },
    ["cater"] = { sprite_anda = "cater_anda", sprite_ataq = "cater_cabeca", velocidade = 0.4, largura = 16, altura = 15, padrao = "cater_segmentos", alcance = 32, raio_deteccao = 52, cooldown_ataque = 180, num_segmentos = 4, forca_pulo_y = -4.0, forca_pulo_x_base = 1.5, gravidade_segmento = 0.35, atrito_horizontal = 1.0, limite_espalhamento = 32 },
    ["ballhog"] = { sprite_anda = "ballhog_anda", sprite_ataq = "ballhog_ataq", velocidade = 0.5, largura = 9, altura = 22, padrao = "ballhog_anda_atira", alcance = 48, duracao_ataque = 40, raio_deteccao = 60, cooldown_ataque = 120, velocidade_bala = 2.0, gravidade_bala = 0.12, quique_bala = 0.6, tempo_bala = 240 },
    ["statue"] = { sprite_anda = "statue_anda", sprite_ataq = "statue_ataq", velocidade = 0, largura = 21, altura = 21, padrao = "statue_atira", cooldown_ataque = 180, velocidade_projetil = 2.5, gravidade_projetil = 0.10, tempo_projetil = 240 },
    ["bomb"] = { sprite_anda = "bomb_anda", sprite_ataq = "bomb_ataq", velocidade = 0.4, largura = 10, altura = 12, padrao = "bomb_explode", alcance = 48, raio_deteccao = 64, duracao_pavio = 90, velocidade_bala = 1.8, gravidade_bala = 0.18 },
    ["neutron"] = { sprite_anda = "neutron_anda", sprite_ataq = nil, largura = 13, altura = 29, padrao = "neutron_fade", raio_deteccao = 90, velocidade_tiro = 3.0, duracao_fade_in = 45, duracao_espera = 90, duracao_pos_tiro = 90, duracao_fade_out = 45 },
    ["orbo"] = { sprite_anda = "orbo_anda", sprite_ataq = "orbo_orbita", largura = 13, altura = 13, padrao = "orbo_atira", raio_deteccao = 96, raio_orbita = 16, velocidade_orbita = 0.04, velocidade_tiro = 0.6, intervalo_tiro = 40, tempo_queda = 10, movimento_flutuante = 8, velocidade_flutuante = 0.02 },
    ["jaws"] = { sprite_anda = "jaws_anda", sprite_ataq = "jaws_ataq", largura = 18, altura = 11, padrao = "jaws_persegue", raio_deteccao = 190, raio_saida = 220, velocidade_normal = 0.5, velocidade_boost = 2.0, duracao_perseguicao = 90, duracao_boost = 60, cooldown_boost = 180, flutuacao_amplitude = 4, flutuacao_velocidade = 0.05 },
    ["chopper"] = { sprite_anda = "chopper_anda", largura = 13, altura = 13, padrao = "chopper_salta", raio_deteccao = 32, forca_pulo = -7.0, gravidade = 0.3 },
    ["spikes"] = { sprite_anda = "spikes_anda", largura = 21, altura = 29, padrao = "spikes_anda", velocidade = 0.5, alcance = 48 },
    ["spike-ball"] = { sprite_anda = "spike_ball_anda", largura = 20.67, altura = 18.67, padrao = "spike_ball_move", velocidade = 2.0, alcance = 64, tempo_parado = 120 },
}

Inimigos.lista     = {}
Inimigos.projeteis = {}
Inimigos.explosoes = {}
Inimigos.segmentos = {}

function Inimigos.init(dados_terreno)
    Inimigos.lista     = {}
    Inimigos.projeteis = {}
    Inimigos.explosoes = {}
    Inimigos.segmentos = {}
    if dados_terreno and dados_terreno.inimigos then
        for _, i in ipairs(dados_terreno.inimigos) do
            local tipo_base = i.tipo
            local direcao_fixa = nil
            if tipo_base == "statue_dir" then
                tipo_base = "statue"
                direcao_fixa = 1
            elseif tipo_base == "statue_esq" then
                tipo_base = "statue"
                direcao_fixa = -1
            end
            local cfg = CONFIG[tipo_base]
            if cfg then
                table.insert(Inimigos.lista, {
                    tipo = tipo_base,
                    nome_original = i.tipo,
                    x = i.x, y = i.y, x_inicial = i.x, y_inicial = i.y,
                    direcao_str = i.direcao,
                    vivo = true, cfg = cfg, largura = i.w or 15, altura = i.h or 15,
                    direcao = direcao_fixa or -1,
                    direcao_fixa = direcao_fixa,
                    timer_anim = 0, frame_anim = 1, modo = "anda", timer_modo = 0,
                    cooldown = 0, atirou_neste_ciclo = false,
                })
            end
        end
    end
end

function Inimigos.criar_explosao(x, y)
    table.insert(Inimigos.explosoes, { x = x, y = y, frame = 1, timer = 0 })
end

local function distancia_ao_player(inimigo, player)
    local dx = (player.x + 8) - inimigo.x
    local dy = (player.y + 16) - inimigo.y
    return math.sqrt(dx * dx + dy * dy)
end

local function atualizar_motobug(inimigo)
    local cfg = inimigo.cfg
    inimigo.x = inimigo.x + cfg.velocidade * inimigo.direcao
    if inimigo.x > inimigo.x_inicial + cfg.alcance then inimigo.direcao = -1
    elseif inimigo.x < inimigo.x_inicial - cfg.alcance then inimigo.direcao = 1 end
    local chao = Mapa.altura_suporte(inimigo.x, inimigo.y, 32)
    if chao then inimigo.y = chao - 8 end
end

local function atualizar_orbo(inimigo, player)
    local cfg = inimigo.cfg
    if inimigo.timer_global == nil then
        inimigo.timer_global = 0; inimigo.orbita_angulo = 0; inimigo.flutuacao_angulo = 0
        inimigo.atirando = false; inimigo.orbes_restantes = 4; inimigo.timer_tiro = 0
        inimigo.timer_queda_orbe = 0; inimigo.esperando = false; inimigo.y_base = inimigo.y_inicial
    end
    inimigo.timer_global = inimigo.timer_global + 1
    inimigo.flutuacao_angulo = inimigo.flutuacao_angulo + cfg.velocidade_flutuante
    inimigo.y = inimigo.y_base + math.sin(inimigo.flutuacao_angulo) * cfg.movimento_flutuante

    local dx = (player.x + 8) - inimigo.x
    local dy = (player.y + 16) - inimigo.y
    local dist = math.sqrt(dx * dx + dy * dy)
    local mesmo_lado = (dx > 0 and inimigo.direcao == 1) or (dx < 0 and inimigo.direcao == -1)

    if not inimigo.atirando and not inimigo.esperando and inimigo.orbes_restantes > 0 then
        inimigo.orbita_angulo = inimigo.orbita_angulo + cfg.velocidade_orbita
        -- Horizontal puro (não encurta com a altura) e só do nível do
        -- Orbo para BAIXO: quem está acima não é detectado.
        local dy_rel = (player.y + 16) - inimigo.y
        local na_faixa = dy_rel >= -ORBO_TOL_ACIMA and dy_rel <= ORBO_ALCANCE_V
        if math.abs(dx) < ORBO_ALCANCE_H and na_faixa then
            if mesmo_lado then
                inimigo.timer_tras = 0
                inimigo.atirando = true; inimigo.timer_tiro = 0; inimigo.timer_queda_orbe = 0
                inimigo.orbita_angulo = -math.pi / 2
            else
                -- Pelas costas: detecta igual, mas com atraso de 2s
                -- antes de virar e começar a lançar.
                inimigo.timer_tras = (inimigo.timer_tras or 0) + 1
                if inimigo.timer_tras >= ORBO_ATRASO_TRAS then
                    inimigo.direcao = (dx >= 0) and 1 or -1
                    inimigo.timer_tras = 0
                    inimigo.atirando = true; inimigo.timer_tiro = 0; inimigo.timer_queda_orbe = 0
                    inimigo.orbita_angulo = -math.pi / 2
                end
            end
        else
            inimigo.timer_tras = 0
        end
    end

    if inimigo.esperando then
        inimigo.timer_tiro = inimigo.timer_tiro + 1
        if inimigo.timer_tiro >= cfg.intervalo_tiro then
            inimigo.esperando = false; inimigo.timer_queda_orbe = 0
            inimigo.orbita_angulo = -math.pi / 2
        end
    elseif inimigo.atirando then
        inimigo.timer_queda_orbe = inimigo.timer_queda_orbe + 1
        if inimigo.timer_queda_orbe >= cfg.tempo_queda then
            inimigo.orbes_restantes = inimigo.orbes_restantes - 1
            local dir_tiro = (dx > 0) and 1 or -1
            table.insert(Inimigos.projeteis, {
                x = inimigo.x, y = inimigo.y,
                vx = cfg.velocidade_tiro * dir_tiro, vy = 0,
                gravidade = 0, quique = 0, timer = 240,
                frame = 1, timer_anim = 0, sprite_estado = "orbo_orbita"
            })
            if inimigo.orbes_restantes <= 0 then
                inimigo.atirando = false
            else
                inimigo.atirando = false; inimigo.esperando = true; inimigo.timer_tiro = 0
            end
        end
    end

        -- Posições dos orbes: calculadas UMA vez por frame e compartilhadas
        -- entre o draw e a colisão. Antes só o draw sabia onde eles estavam,
        -- por isso encostar neles não feria.
        local pos = inimigo.orbes_pos
        if not pos then pos = {}; inimigo.orbes_pos = pos end
        local qtd = inimigo.orbes_restantes or 0
        local raio = cfg.raio_orbita
        local tq = cfg.tempo_queda or 10
        for i = 1, qtd do
            local ang = inimigo.orbita_angulo + ((i - 1) * math.pi / 2)
            local oy = inimigo.y + math.sin(ang) * raio
            if inimigo.atirando and i == 1 then
                oy = oy + (raio * 2) * (inimigo.timer_queda_orbe / tq)
            end
            local e = pos[i]
            if not e then e = {}; pos[i] = e end
            e.x = inimigo.x + math.cos(ang) * raio
            e.y = oy
        end
        for i = #pos, qtd + 1, -1 do pos[i] = nil
    end
end

local function atualizar_crab(inimigo, player)
    local cfg = inimigo.cfg
    local dx = (player.x + 8) - inimigo.x
    if inimigo.cooldown > 0 then inimigo.cooldown = inimigo.cooldown - 1 end

    if inimigo.modo == "anda" then
        inimigo.x = inimigo.x + cfg.velocidade * inimigo.direcao
        if inimigo.x > inimigo.x_inicial + cfg.alcance then inimigo.direcao = -1
        elseif inimigo.x < inimigo.x_inicial - cfg.alcance then inimigo.direcao = 1 end
        local chao = Mapa.altura_suporte(inimigo.x, inimigo.y, 32)
        if chao then inimigo.y = chao - 8 end
        if inimigo.cooldown <= 0 and math.abs(dx) < cfg.alcance_arco then
            inimigo.modo = "ataque"; inimigo.timer_modo = 0
            inimigo.atirou_neste_ciclo = false
            inimigo.direcao = (dx >= 0) and 1 or -1
        end
    elseif inimigo.modo == "ataque" then
        inimigo.timer_modo = inimigo.timer_modo + 1
        if not inimigo.atirou_neste_ciclo then
            inimigo.atirou_neste_ciclo = true
            for i = 1, 2 do
                local dir = (i == 1) and -1 or 1
                table.insert(Inimigos.projeteis, {
                    x = inimigo.x, y = inimigo.y - 6,
                    vx = cfg.velocidade_projetil_x * dir, vy = cfg.velocidade_projetil_y,
                    gravidade = GRAVIDADE_PROJETIL, timer = 240, frame = 1, timer_anim = 0
                })
            end
        end
        if inimigo.timer_modo >= cfg.duracao_ataque then
            inimigo.modo = "anda"; inimigo.timer_modo = 0; inimigo.cooldown = cfg.cooldown_ataque
        end
    end
end

local function atualizar_burr(inimigo, player)
    local cfg = inimigo.cfg
    local dx = (player.x + 8) - inimigo.x
    if inimigo.modo_estado == nil then
        inimigo.modo_estado = "escondido"; inimigo.velocidade_y = 0
        inimigo.y_escondido = inimigo.y_inicial + 24
        inimigo.y = inimigo.y_escondido; inimigo.timer_estado = 0
    end
    inimigo.timer_estado = inimigo.timer_estado + 1

    if inimigo.modo_estado == "escondido" then
        inimigo.modo = "ataque"; inimigo.velocidade_y = 0
        if math.abs(dx) < cfg.raio_deteccao then
            inimigo.modo_estado = "pulando"; inimigo.velocidade_y = cfg.forca_pulo
            inimigo.timer_estado = 0; inimigo.direcao = (dx >= 0) and 1 or -1
        end
    elseif inimigo.modo_estado == "pulando" then
        inimigo.modo = "ataque"
        inimigo.velocidade_y = inimigo.velocidade_y + cfg.gravidade
        inimigo.y = inimigo.y + inimigo.velocidade_y
        local chao = Mapa.altura_suporte(inimigo.x, inimigo.y + 8, 32)
        if chao and inimigo.y + 8 >= chao and inimigo.velocidade_y > 0 then
            inimigo.y = chao - 14; inimigo.velocidade_y = 0
            inimigo.modo_estado = "andando"; inimigo.timer_estado = 0
        end
    elseif inimigo.modo_estado == "andando" then
        inimigo.modo = "anda"
        inimigo.direcao = (dx >= 0) and 1 or -1
        inimigo.x = inimigo.x + cfg.velocidade * inimigo.direcao
        local chao = Mapa.altura_suporte(inimigo.x, inimigo.y + 8, 32)
        if chao then inimigo.y = chao - 14 end
        if math.abs(dx) > cfg.raio_deteccao * 1.5 and inimigo.timer_estado > cfg.duracao_anda then
            inimigo.modo_estado = "voltando"; inimigo.timer_estado = 0
        end
        if inimigo.timer_estado > cfg.duracao_anda * 2 then
            inimigo.modo_estado = "voltando"; inimigo.timer_estado = 0
        end
    elseif inimigo.modo_estado == "voltando" then
        inimigo.modo = "anda"
        local dx_ini = inimigo.x_inicial - inimigo.x
        if math.abs(dx_ini) < 1 then
            inimigo.modo_estado = "escondido"; inimigo.y = inimigo.y_escondido
            inimigo.timer_estado = 0
        else
            inimigo.direcao = (dx_ini >= 0) and 1 or -1
            inimigo.x = inimigo.x + cfg.velocidade * inimigo.direcao
            local chao = Mapa.altura_suporte(inimigo.x, inimigo.y + 8, 32)
            if chao then inimigo.y = chao - 14 end
        end
    end
end

local function atualizar_buzz(inimigo, player)
    local cfg = inimigo.cfg
    local dist = distancia_ao_player(inimigo, player)
    if inimigo.cooldown > 0 then inimigo.cooldown = inimigo.cooldown - 1 end

    if inimigo.modo == "anda" then
        inimigo.x = inimigo.x + cfg.velocidade * inimigo.direcao
        if inimigo.x > inimigo.x_inicial + cfg.alcance then inimigo.direcao = -1
        elseif inimigo.x < inimigo.x_inicial - cfg.alcance then inimigo.direcao = 1 end
        inimigo.y = inimigo.y_inicial
        if dist < cfg.raio_deteccao and inimigo.cooldown <= 0 then
            local dx = (player.x + 8) - inimigo.x
            local alvo_y = (player.y + 16) - math.abs(dx)
            local dy = alvo_y - inimigo.y
            if math.abs(dy) > cfg.tolerancia_alinhamento then
                inimigo.y = inimigo.y + math.max(-cfg.velocidade, math.min(cfg.velocidade, dy))
                inimigo.direcao = (dx >= 0) and 1 or -1
            else
                inimigo.modo = "ataque"; inimigo.timer_modo = 0
                inimigo.atirou_neste_ciclo = false
                inimigo.direcao = (dx >= 0) and 1 or -1
            end
        end
    elseif inimigo.modo == "ataque" then
        inimigo.timer_modo = inimigo.timer_modo + 1
        if not inimigo.atirou_neste_ciclo then
            inimigo.atirou_neste_ciclo = true
            local vel = cfg.velocidade_projetil
            table.insert(Inimigos.projeteis, {
                x = inimigo.x, y = inimigo.y + 4,
                vx = vel * inimigo.direcao, vy = vel,
                gravidade = 0, timer = 200, frame = 1, timer_anim = 0
            })
        end
        if inimigo.timer_modo >= cfg.duracao_ataque then
            inimigo.modo = "anda"; inimigo.timer_modo = 0; inimigo.cooldown = cfg.cooldown_ataque
        end
    end
end

local function atualizar_cater(inimigo, player)
    local cfg = inimigo.cfg
    local dx = (player.x + 8) - inimigo.x
    if inimigo.cooldown == nil then inimigo.cooldown = 0 end
    if inimigo.cooldown > 0 then inimigo.cooldown = inimigo.cooldown - 1 end

    if inimigo.modo ~= "ataque" then
        inimigo.modo = "anda"
        inimigo.x = inimigo.x + cfg.velocidade * inimigo.direcao
        if inimigo.x > inimigo.x_inicial + cfg.alcance then inimigo.direcao = -1
        elseif inimigo.x < inimigo.x_inicial - cfg.alcance then inimigo.direcao = 1 end
        local chao = Mapa.altura_suporte(inimigo.x, inimigo.y, 32)
        if chao then inimigo.y = chao - 8 end
    end

    if inimigo.cooldown <= 0 and math.abs(dx) < cfg.raio_deteccao then
        inimigo.cooldown = cfg.cooldown_ataque
        local dir = (dx >= 0) and 1 or -1
        for i = 1, cfg.num_segmentos do
            local offset_x = (i - 2.5) * 8 * dir
            local pos_x = inimigo.x + offset_x
            table.insert(Inimigos.segmentos, {
                x = pos_x, y = inimigo.y - 4, x_centro = pos_x,
                vx = cfg.forca_pulo_x_base * dir * (1 + i * 0.1),
                vy = cfg.forca_pulo_y - (i * 0.3),
                gravidade = cfg.gravidade_segmento, atrito = cfg.atrito_horizontal,
                limite = cfg.limite_espalhamento, is_cabeca = false
            })
        end
        table.insert(Inimigos.segmentos, {
            x = inimigo.x, y = inimigo.y - 4, x_centro = inimigo.x,
            vx = cfg.forca_pulo_x_base * dir, vy = cfg.forca_pulo_y,
            gravidade = cfg.gravidade_segmento, atrito = cfg.atrito_horizontal,
            limite = cfg.limite_espalhamento, is_cabeca = true
        })
        inimigo.vivo = false
    end
end

local function atualizar_ballhog(inimigo, player)
    local cfg = inimigo.cfg
    local dx = math.abs((player.x + 8) - inimigo.x)
    if inimigo.cooldown == nil then inimigo.cooldown = 0 end
    if inimigo.cooldown > 0 then inimigo.cooldown = inimigo.cooldown - 1 end

    if inimigo.modo == "anda" then
        inimigo.x = inimigo.x + cfg.velocidade * inimigo.direcao
        if inimigo.x > inimigo.x_inicial + cfg.alcance then inimigo.direcao = -1
        elseif inimigo.x < inimigo.x_inicial - cfg.alcance then inimigo.direcao = 1 end
        local chao = Mapa.altura_suporte(inimigo.x, inimigo.y, 32)
        if chao then inimigo.y = chao - 11 end
        if inimigo.cooldown <= 0 and dx < cfg.raio_deteccao then
            inimigo.modo = "ataque"; inimigo.timer_modo = 0; inimigo.atirou_neste_ciclo = false
            local ddx = (player.x + 8) - inimigo.x
            inimigo.direcao = (ddx >= 0) and 1 or -1
        end
    elseif inimigo.modo == "ataque" then
        inimigo.timer_modo = inimigo.timer_modo + 1
        if not inimigo.atirou_neste_ciclo then
            inimigo.atirou_neste_ciclo = true
            table.insert(Inimigos.projeteis, {
                x = inimigo.x, y = inimigo.y - 4,
                vx = cfg.velocidade_bala * inimigo.direcao, vy = -1.5,
                gravidade = cfg.gravidade_bala, quique = cfg.quique_bala,
                timer = cfg.tempo_bala, frame = 1, timer_anim = 0,
                sprite_estado = "ballhog_bala", is_bola_ballhog = true
            })
        end
        if inimigo.timer_modo >= cfg.duracao_ataque then
            inimigo.modo = "anda"; inimigo.timer_modo = 0; inimigo.cooldown = cfg.cooldown_ataque
        end
    end
end

local function atualizar_statue(inimigo, player)
    local cfg = inimigo.cfg
    if inimigo.cooldown == nil then inimigo.cooldown = cfg.cooldown_ataque end
    if inimigo.cooldown > 0 then
        inimigo.cooldown = inimigo.cooldown - 1; inimigo.modo = "anda"; return
    end
    inimigo.modo = "anda"
    if inimigo.direcao_fixa then inimigo.direcao = inimigo.direcao_fixa end
    table.insert(Inimigos.projeteis, {
        x = inimigo.x, y = inimigo.y,
        vx = cfg.velocidade_projetil * inimigo.direcao, vy = 0,
        gravidade = 0, quique = 0, timer = cfg.tempo_projetil,
        frame = 1, timer_anim = 0, sprite_estado = "statue_ataq", is_statue_shot = true
    })
    inimigo.cooldown = cfg.cooldown_ataque
end

local function atualizar_bomb(inimigo, player)
    local cfg = inimigo.cfg
    local dx = math.abs((player.x + 8) - inimigo.x)
    if inimigo.estado_bomb == nil then
        inimigo.estado_bomb = "andando"; inimigo.timer_estado = 0
    end
    inimigo.timer_estado = inimigo.timer_estado + 1

    if inimigo.estado_bomb == "andando" then
        inimigo.modo = "anda"
        if inimigo.caindo then
            inimigo.velocidade_y = (inimigo.velocidade_y or 0) + 0.3
            inimigo.y = inimigo.y + inimigo.velocidade_y
            local chao_baixo = Mapa.altura_suporte(inimigo.x, inimigo.y + 12, 16)
            if chao_baixo and inimigo.y + 6 >= chao_baixo then
                inimigo.y = chao_baixo - 6; inimigo.velocidade_y = 0
                inimigo.caindo = false; inimigo.x_inicial = inimigo.x
            end
        else
            inimigo.x = inimigo.x + cfg.velocidade * inimigo.direcao
            if inimigo.x > inimigo.x_inicial + cfg.alcance then inimigo.direcao = -1
            elseif inimigo.x < inimigo.x_inicial - cfg.alcance then inimigo.direcao = 1 end
            local chao_novo = Mapa.altura_suporte(inimigo.x, inimigo.y + 12, 32)
            if not chao_novo then
                inimigo.caindo = true; inimigo.velocidade_y = 0
            else
                inimigo.y = chao_novo - 6
            end
        end
        if not inimigo.caindo then
            local dx2 = math.abs((player.x + 8) - inimigo.x)
            if dx2 < cfg.raio_deteccao then
                inimigo.estado_bomb = "acendendo"; inimigo.timer_estado = 0
                local ddx = (player.x + 8) - inimigo.x
                inimigo.direcao = (ddx >= 0) and 1 or -1
            end
        end
        if dx < cfg.raio_deteccao then
            inimigo.estado_bomb = "acendendo"; inimigo.timer_estado = 0
            local ddx = (player.x + 8) - inimigo.x
            inimigo.direcao = (ddx >= 0) and 1 or -1
        end
    elseif inimigo.estado_bomb == "acendendo" then
        inimigo.modo = "ataque"
        inimigo.timer_anim = inimigo.timer_anim + 1
        if inimigo.timer_anim >= 4 then
            inimigo.timer_anim = 0
            inimigo.frame_anim = (inimigo.frame_anim == 1) and 2 or 1
        end
        if inimigo.timer_estado >= cfg.duracao_pavio then
            local velocidade = cfg.velocidade_bala
            local balas = {
                { vx = -velocidade, vy = -2.5 },
                { vx = velocidade, vy = -2.5 },
                { vx = -velocidade * 0.6, vy = -3.5 },
                { vx = velocidade * 0.6, vy = -3.5 },
            }
            for _, b in ipairs(balas) do
                table.insert(Inimigos.projeteis, {
                    x = inimigo.x, y = inimigo.y - 4,
                    vx = b.vx, vy = b.vy, gravidade = cfg.gravidade_bala,
                    timer = 240, frame = 1, timer_anim = 0, sprite_estado = "bala"
                })
            end
            Inimigos.criar_explosao(inimigo.x, inimigo.y)
            inimigo.vivo = false
        end
    end
end

local function atualizar_neutron(inimigo, player)
    local cfg = inimigo.cfg
    if inimigo.estado_neutron == nil then
        inimigo.estado_neutron = "invisivel"; inimigo.timer_estado = 0; inimigo.alpha = 0
    end
    inimigo.timer_estado = inimigo.timer_estado + 1

    if inimigo.estado_neutron == "invisivel" then
        inimigo.modo = "anda"; inimigo.alpha = 0
        local dx = (player.x + 8) - inimigo.x
        local dy = (player.y + 16) - inimigo.y
        local dist = math.sqrt(dx * dx + dy * dy)
        if dist < cfg.raio_deteccao then
            inimigo.estado_neutron = "fade_in"; inimigo.timer_estado = 0
        end
    elseif inimigo.estado_neutron == "fade_in" then
        inimigo.modo = "anda"
        inimigo.alpha = math.min(1, inimigo.timer_estado / cfg.duracao_fade_in)
        if inimigo.timer_estado >= cfg.duracao_fade_in then
            inimigo.alpha = 1; inimigo.estado_neutron = "esperando"; inimigo.timer_estado = 0
        end
    elseif inimigo.estado_neutron == "esperando" then
        inimigo.modo = "anda"; inimigo.alpha = 1
        if inimigo.timer_estado >= cfg.duracao_espera then
            local dx = (player.x + 8) - inimigo.x
            local dy = (player.y + 16) - inimigo.y
            local atan2 = math.atan2 or math.atan
            local angulo = atan2(dy, dx)
            table.insert(Inimigos.projeteis, {
                x = inimigo.x, y = inimigo.y,
                vx = math.cos(angulo) * cfg.velocidade_tiro,
                vy = math.sin(angulo) * cfg.velocidade_tiro,
                gravidade = 0, quique = 0, timer = 240,
                frame = 1, timer_anim = 0, sprite_estado = "bala"
            })
            inimigo.estado_neutron = "pos_tiro"; inimigo.timer_estado = 0
        end
    elseif inimigo.estado_neutron == "pos_tiro" then
        inimigo.modo = "anda"; inimigo.alpha = 1
        if inimigo.timer_estado >= cfg.duracao_pos_tiro then
            inimigo.estado_neutron = "fade_out"; inimigo.timer_estado = 0
        end
    elseif inimigo.estado_neutron == "fade_out" then
        inimigo.modo = "anda"
        inimigo.alpha = math.max(0, 1 - (inimigo.timer_estado / cfg.duracao_fade_out))
        if inimigo.timer_estado >= cfg.duracao_fade_out then
            inimigo.alpha = 0; inimigo.vivo = false
        end
    end
end

local function atualizar_jaws(inimigo, player)
    local cfg = inimigo.cfg
    if inimigo.estado == nil then
        inimigo.estado = "flutuando"; inimigo.flutuacao_angulo = 0
        inimigo.timer_estado = 0; inimigo.y_base = inimigo.y_inicial
    end
    inimigo.timer_estado = inimigo.timer_estado + 1

    local areas = Mapa.get_areas_agua and Mapa.get_areas_agua() or {}
    local sonic_na_agua = false
    for _, area in ipairs(areas) do
        if player.x > area.x and player.x < area.x + area.w
        and player.y > area.y and player.y < area.y + area.h then
            sonic_na_agua = true; break
        end
    end

    local jaws_na_agua = false; local area_atual = nil
    for _, area in ipairs(areas) do
        if inimigo.x > area.x and inimigo.x < area.x + area.w
        and inimigo.y > area.y and inimigo.y < area.y + area.h then
            jaws_na_agua = true; area_atual = area; break
        end
    end
    if not jaws_na_agua then return end

    local dx = (player.x + 8) - inimigo.x
    local dy = (player.y + 16) - inimigo.y
    local dist = math.sqrt(dx * dx + dy * dy)

    if not sonic_na_agua then
        if inimigo.estado ~= "flutuando" and inimigo.estado ~= "recuperando" then
            inimigo.estado = "recuperando"; inimigo.timer_estado = 0
        end
        if dist > cfg.raio_saida then inimigo.estado = "flutuando" end
    end

    if inimigo.estado == "flutuando" then
        inimigo.modo = "anda"
        if dist < cfg.raio_deteccao then inimigo.direcao = (dx >= 0) and 1 or -1 end
        if sonic_na_agua and dist < cfg.raio_deteccao then
            inimigo.estado = "perseguindo"; inimigo.timer_estado = 0
        end
        inimigo.flutuacao_angulo = inimigo.flutuacao_angulo + cfg.flutuacao_velocidade
        inimigo.y = inimigo.y_base + math.sin(inimigo.flutuacao_angulo) * cfg.flutuacao_amplitude
    elseif inimigo.estado == "perseguindo" then
        inimigo.modo = "anda"; inimigo.direcao = (dx >= 0) and 1 or -1
        local atan2 = math.atan2 or math.atan
        local angulo = atan2(dy, dx)
        inimigo.x = inimigo.x + math.cos(angulo) * cfg.velocidade_normal
        inimigo.y = inimigo.y + math.sin(angulo) * cfg.velocidade_normal
        if inimigo.timer_estado >= cfg.duracao_perseguicao then
            inimigo.estado = "atacando"; inimigo.timer_estado = 0
        end
        if dist > cfg.raio_saida then inimigo.estado = "flutuando" end
    elseif inimigo.estado == "atacando" then
        inimigo.modo = "ataque"; inimigo.direcao = (dx >= 0) and 1 or -1
        local atan2 = math.atan2 or math.atan
        local angulo = atan2(dy, dx)
        inimigo.x = inimigo.x + math.cos(angulo) * cfg.velocidade_boost
        inimigo.y = inimigo.y + math.sin(angulo) * cfg.velocidade_boost
        if inimigo.timer_estado >= cfg.duracao_boost or dist > cfg.raio_saida then
            inimigo.estado = "recuperando"; inimigo.timer_estado = 0
        end
    elseif inimigo.estado == "recuperando" then
        inimigo.modo = "anda"; inimigo.direcao = (dx >= 0) and 1 or -1
        if sonic_na_agua and dist < cfg.raio_saida then
            local atan2 = math.atan2 or math.atan
            local angulo = atan2(dy, dx)
            inimigo.x = inimigo.x + math.cos(angulo) * cfg.velocidade_normal
            inimigo.y = inimigo.y + math.sin(angulo) * cfg.velocidade_normal
        end
        if inimigo.timer_estado >= cfg.cooldown_boost then
            if sonic_na_agua and dist < cfg.raio_deteccao then
                inimigo.estado = "perseguindo"; inimigo.timer_estado = 0
            else
                inimigo.estado = "flutuando"; inimigo.y_base = inimigo.y
            end
        end
    end

    if area_atual then
        local margem = inimigo.largura / 2
        if inimigo.x < area_atual.x + margem then inimigo.x = area_atual.x + margem end
        if inimigo.x > area_atual.x + area_atual.w - margem then inimigo.x = area_atual.x + area_atual.w - margem end
        if inimigo.y < area_atual.y + margem then inimigo.y = area_atual.y + margem end
        if inimigo.y > area_atual.y + area_atual.h - margem then inimigo.y = area_atual.y + area_atual.h - margem end
    end
end

local function atualizar_chopper(inimigo, player)
    local cfg = inimigo.cfg
    if inimigo.estado_chopper == nil then
        inimigo.estado_chopper = "escondido"
        inimigo.y_escondido = inimigo.y_inicial
        inimigo.vy = 0
    end
    local dx = math.abs((player.x + 8) - inimigo.x)
    if inimigo.estado_chopper == "escondido" then
        inimigo.y = inimigo.y_escondido
        if dx < cfg.raio_deteccao then
            inimigo.estado_chopper = "pulando"; inimigo.vy = cfg.forca_pulo
        end
    elseif inimigo.estado_chopper == "pulando" then
        inimigo.vy = inimigo.vy + cfg.gravidade
        inimigo.y = inimigo.y + inimigo.vy
        if inimigo.vy > 0 and inimigo.y >= inimigo.y_escondido then
            inimigo.y = inimigo.y_escondido; inimigo.vy = 0
            inimigo.estado_chopper = "escondido"
        end
    end
end

local function atualizar_spikes(inimigo, player)
    local cfg = inimigo.cfg
    inimigo.x = inimigo.x + cfg.velocidade * inimigo.direcao
    if inimigo.x > inimigo.x_inicial + cfg.alcance then inimigo.direcao = -1
    elseif inimigo.x < inimigo.x_inicial - cfg.alcance then inimigo.direcao = 1 end
    local chao = Mapa.altura_suporte(inimigo.x, inimigo.y, 32)
    if chao then inimigo.y = chao - 14 end
end

local function atualizar_spike_ball(inimigo, player)
    local cfg = inimigo.cfg
    if inimigo.estado_spike == nil then
        inimigo.estado_spike = "movendo"; inimigo.sentido = 1; inimigo.timer_parado = 0
        local d = inimigo.direcao_str or ""
        inimigo.vx, inimigo.vy = 0, 0
        if d == "cima" then inimigo.vy = -1
        elseif d == "baixo" then inimigo.vy = 1
        elseif d == "esq" then inimigo.vx = -1
        elseif d == "dir" then inimigo.vx = 1
        elseif d == "cimaesq" then inimigo.vx, inimigo.vy = -0.707, -0.707
        elseif d == "cimadir" then inimigo.vx, inimigo.vy = 0.707, -0.707
        elseif d == "baixoesq" then inimigo.vx, inimigo.vy = -0.707, 0.707
        elseif d == "baixodir" then inimigo.vx, inimigo.vy = 0.707, 0.707
        else inimigo.estado_spike = "parado"; inimigo.timer_parado = 999999 end
    end

    if inimigo.estado_spike == "parado" and inimigo.vx == 0 and inimigo.vy == 0 then return end

    if inimigo.estado_spike == "movendo" then
        inimigo.modo = "anda"
        inimigo.x = inimigo.x + inimigo.vx * cfg.velocidade * inimigo.sentido
        inimigo.y = inimigo.vy and (inimigo.y + inimigo.vy * cfg.velocidade * inimigo.sentido) or inimigo.y
        local dx = inimigo.x - inimigo.x_inicial
        local dy = inimigo.y - inimigo.y_inicial
        local dist = math.sqrt(dx * dx + dy * dy)
        if dist >= cfg.alcance then
            inimigo.x = inimigo.x_inicial + (inimigo.vx * cfg.alcance * inimigo.sentido)
            inimigo.y = inimigo.y_inicial + (inimigo.vy * cfg.alcance * inimigo.sentido)
            inimigo.estado_spike = "parado"; inimigo.timer_parado = cfg.tempo_parado
        end
    elseif inimigo.estado_spike == "parado" then
        inimigo.modo = "anda"
        inimigo.timer_parado = inimigo.timer_parado - 1
        if inimigo.timer_parado <= 0 then
            inimigo.estado_spike = "movendo"; inimigo.sentido = -inimigo.sentido
        end
    end
end

-- Contexto agora vem do Player (fonte única de verdade).
local function calcular_contexto_player(player)
    return PlayerSys.contexto_ataque(player)
end

-- ============================================================
-- UPDATE: apenas IA, física e animação.
-- A colisão com o Sonic foi para Inimigos.colisoes_player,
-- chamada DEPOIS de Player.update em game.lua.
-- ============================================================
function Inimigos.update(player)
    for _, inimigo in ipairs(Inimigos.lista) do
        if inimigo.vivo then
            local cfg = inimigo.cfg
            if cfg.padrao == "anda_chao" then atualizar_motobug(inimigo)
            elseif cfg.padrao == "patrulha_atira" then atualizar_crab(inimigo, player)
            elseif cfg.padrao == "voo_patrulha_atira" then atualizar_buzz(inimigo, player)
            elseif cfg.padrao == "burr_esconde" then atualizar_burr(inimigo, player)
            elseif cfg.padrao == "cater_segmentos" then atualizar_cater(inimigo, player)
            elseif cfg.padrao == "ballhog_anda_atira" then atualizar_ballhog(inimigo, player)
            elseif cfg.padrao == "statue_atira" then atualizar_statue(inimigo, player)
            elseif cfg.padrao == "bomb_explode" then atualizar_bomb(inimigo, player)
            elseif cfg.padrao == "neutron_fade" then atualizar_neutron(inimigo, player)
            elseif cfg.padrao == "orbo_atira" then atualizar_orbo(inimigo, player)
            elseif cfg.padrao == "jaws_persegue" then atualizar_jaws(inimigo, player)
            elseif cfg.padrao == "chopper_salta" then atualizar_chopper(inimigo, player)
            elseif cfg.padrao == "spikes_anda" then atualizar_spikes(inimigo, player)
            elseif cfg.padrao == "spike_ball_move" then atualizar_spike_ball(inimigo, player)
            end

            if inimigo.modo == "anda" then
                inimigo.timer_anim = inimigo.timer_anim + 1
                if inimigo.timer_anim >= 8 then
                    inimigo.timer_anim = 0
                    inimigo.frame_anim = inimigo.frame_anim + 1
                    if inimigo.frame_anim > 2 then inimigo.frame_anim = 1 end
                end
            end
        end
    end

        -- Orbes em órbita do Orbo ferem ao toque. O corpo do Orbo já foi
    -- testado acima; aqui são os 4 orbes ao redor dele.
    for _, inimigo in ipairs(Inimigos.lista) do
        if inimigo.vivo and inimigo.tipo == "orbo" and inimigo.orbes_pos then
            local px0, py0, px1, py1 = PlayerSys.get_hitbox(player)
            for _, o in ipairs(inimigo.orbes_pos) do
                if px0 < o.x + 4 and px1 > o.x - 4
                and py0 < o.y + 4 and py1 > o.y - 4 then
                    PlayerSys.aplicar_dano(player)
                    if player.morto or player.em_dano then return end
                end
            end
        end
    end

    -- Segmentos: só física
    for i = #Inimigos.segmentos, 1, -1 do
        local s = Inimigos.segmentos[i]
        s.vy = s.vy + s.gravidade
        s.y = s.y + s.vy
        local dist_centro = s.x - s.x_centro
        if math.abs(dist_centro) > s.limite then
            s.vx = -s.vx * 0.8
            s.x = s.x_centro + (s.limite * (dist_centro > 0 and 1 or -1))
        end
        s.vx = s.vx * (s.atrito or 1.0)
        s.x = s.x + s.vx
        local chao = Mapa.altura_suporte(s.x, s.y + 8, 16)
        if chao and s.y + 8 >= chao and s.vy > 0 then
            s.y = chao - 8; s.vy = -4.0
        end
        if s.y > 1200 then table.remove(Inimigos.segmentos, i) end
    end

    -- Projéteis: só física e descarte
    for i = #Inimigos.projeteis, 1, -1 do
        local p = Inimigos.projeteis[i]
        p.x = p.x + p.vx
        p.y = p.y + p.vy
        if p.gravidade and p.gravidade > 0 then p.vy = p.vy + p.gravidade end
        p.timer = p.timer - 1

        if p.is_bola_ballhog then
            p.vy = p.vy + 0.3
            p.y = p.y + p.vy
            local chao_atual = Mapa.altura_suporte(p.x, p.y + 4, 24)
            if chao_atual then
                local pes_bola = p.y + 4
                if pes_bola >= chao_atual then
                    p.y = chao_atual - 4
                    if p.vy > 1.0 then
                        p.vy = -p.vy * p.quique
                        if math.abs(p.vy) < 0.5 then p.vy = 0 end
                    else
                        p.vy = 0
                    end
                    local passo = 8
                    local chao_frente = Mapa.altura_suporte(p.x + passo, chao_atual, 16)
                    if chao_frente then
                        local variacao = chao_atual - chao_frente
                        p.vx = p.vx - (variacao * 0.03)
                    end
                    p.vx = p.vx * 0.997
                    if math.abs(p.vx) < 0.05 then p.vx = 0 end
                end
            end
        end

        if p.timer <= 0 or p.y > 1024
        or (not p.is_bola_ballhog and Mapa.colide_projetil(p.x - 3, p.y - 3, 6, 6)) then
            table.remove(Inimigos.projeteis, i)
        end
    end

    for i = #Inimigos.explosoes, 1, -1 do
        local e = Inimigos.explosoes[i]
        e.timer = e.timer + 1
        if e.timer >= 5 then
            e.timer = 0
            e.frame = e.frame + 1
            if e.frame > 3 then table.remove(Inimigos.explosoes, i) end
        end
    end
end

-- ============================================================
-- COLISÕES COM O SONIC — rodar DEPOIS de Player.update.
-- Hitbox e contexto são relidos a cada teste (nada de dados velhos).
-- ============================================================
function Inimigos.colisoes_player(player)
    if not player or player.morto then return end

    for _, inimigo in ipairs(Inimigos.lista) do
        if inimigo.vivo and inimigo.tipo ~= "statue" then
            local px0, py0, px1, py1 = PlayerSys.get_hitbox(player)
            local half_w, half_h = inimigo.largura / 2, inimigo.altura / 2
            if px0 < inimigo.x + half_w and px1 > inimigo.x - half_w
            and py0 < inimigo.y + half_h and py1 > inimigo.y - half_h then
                Inimigos._colidir_com_player(inimigo, player)
                if player.morto or player.em_dano then return end
            end
        end
    end

    for i = #Inimigos.segmentos, 1, -1 do
        local s = Inimigos.segmentos[i]
        local px0, py0, px1, py1 = PlayerSys.get_hitbox(player)
        if px0 < s.x + 6 and px1 > s.x - 6 and py0 < s.y + 6 and py1 > s.y - 6 then
            if s.is_cabeca then
                if PlayerSys.acertar_alvo(player, s.y - 6, 6) then
                    Inimigos.criar_explosao(s.x, s.y)
                    for j = #Inimigos.segmentos, 1, -1 do table.remove(Inimigos.segmentos, j) end
                    return
                else
                    PlayerSys.aplicar_dano(player)
                    if player.morto or player.em_dano then return end
                end
            else
                -- corpo do caterkiller sempre fere, mesmo em bola (original)
                PlayerSys.aplicar_dano(player)
                if player.morto or player.em_dano then return end
            end
        end
    end

    for i = #Inimigos.projeteis, 1, -1 do
        local p = Inimigos.projeteis[i]
        local px0, py0, px1, py1 = PlayerSys.get_hitbox(player)
        if px0 < p.x + 6 and px1 > p.x - 6 and py0 < p.y + 6 and py1 > p.y - 6 then
            PlayerSys.aplicar_dano(player)
            if not p.is_bola_ballhog then table.remove(Inimigos.projeteis, i) end
            if player.morto or player.em_dano then return end
        end
    end
end

function Inimigos._colidir_com_player(inimigo, player, ctx)
    -- sempre recalcula: o ctx do chamador pode estar velho
    ctx = calcular_contexto_player(player)

    -- corpo da estátua é invulnerável; só o tiro fere
    if inimigo.tipo == "statue" then return end

    -- bola de espinhos: sempre fere, nem estrelas destroem
    if inimigo.tipo == "spike-ball" then PlayerSys.aplicar_dano(player); return end

    -- Invulnerabilidade pós-dano NÃO bloqueia o ataque:
    -- o Sonic atravessa sem ferir (aplicar_dano já checa o timer)
    -- e continua destruindo inimigos se estiver em forma de bola.
    -- (buffs.invencivel de monitor/esmeralda segue com regra própria em acertar_alvo)

    local topo = inimigo.y - inimigo.altura / 2

    -- BOMB (Master System): o Sonic NÃO destrói; ele se autodestrói.
    -- Contato sempre fere, igual ao comportamento anterior.
    if inimigo.tipo == "bomb" then
        PlayerSys.aplicar_dano(player)
        return
    end

    -- CHOPPER (Master System): só morre se acertado por baixo ou pelos lados.
    -- Acertar por cima (pés acima do centro do peixe) sempre fere.
    if inimigo.tipo == "chopper" then
        local acertou_topo = (player.y + PlayerSys.COLISAO_BASE_Y) < (inimigo.y + 4)
        if acertou_topo and not ctx.invencivel_ofensivo then
            PlayerSys.aplicar_dano(player)
            return
        end
        if PlayerSys.acertar_alvo(player, topo, 6) then
            inimigo.vivo = false
            Inimigos.criar_explosao(inimigo.x, inimigo.y)
        else
            PlayerSys.aplicar_dano(player)
        end
        return
    end

    -- JAWS: dentes de frente ferem; cima/baixo/trás mata
    if inimigo.tipo == "jaws" then
        if not (ctx.atacando or ctx.invencivel_ofensivo) then
            PlayerSys.aplicar_dano(player); return
        end
        local px_c = player.x + 8
        local dx = px_c - inimigo.x
        local pela_frente = (dx > 0 and inimigo.direcao == 1) or (dx < 0 and inimigo.direcao == -1)
        local de_baixo = player.y > inimigo.y + 4
        local de_cima  = player.y + 32 < inimigo.y + 4
        if pela_frente and not de_baixo and not de_cima and not ctx.invencivel_ofensivo then
            PlayerSys.aplicar_dano(player); return
        end
        if PlayerSys.acertar_alvo(player, topo, 6) then
            inimigo.vivo = false
            Inimigos.criar_explosao(inimigo.x, inimigo.y)
        end
        return
    end

    -- SPIKES: só rolamento de frente (comportamento tipo Yadrin) — MANTIDO
    if inimigo.tipo == "spikes" then
        local dx = (player.x + 8) - inimigo.x
        local pela_frente = (dx > 0 and inimigo.direcao == 1) or (dx < 0 and inimigo.direcao == -1)
        local rolou = player.rodando and math.abs(player.velocidade_x) > 1.0
        if ctx.invencivel_ofensivo then
            inimigo.vivo = false
            Inimigos.criar_explosao(inimigo.x, inimigo.y)
        elseif rolou and pela_frente then
            inimigo.vivo = false
            Inimigos.criar_explosao(inimigo.x, inimigo.y)
            player.velocidade_x = player.velocidade_x * 0.85
        else
            PlayerSys.aplicar_dano(player)
        end
        return
    end

    -- GENÉRICO (motobug, crab, buzz, burr, cater, ballhog, neutron, orbo)
    -- Forma de bola mata em QUALQUER direção, subindo ou caindo.
    if PlayerSys.acertar_alvo(player, topo, 6) then
        inimigo.vivo = false
        Inimigos.criar_explosao(inimigo.x, inimigo.y)
        return
    end
    PlayerSys.aplicar_dano(player)
end

function Inimigos.draw(cam_x, cam_y)
    for _, inimigo in ipairs(Inimigos.lista) do
        if inimigo.vivo then
            if inimigo.tipo == "neutron" then
                local alpha = inimigo.alpha or 0
                if alpha > 0.05 then
                    local sprite_estado, frame_use
                    if alpha >= 0.95 then
                        sprite_estado = "neutron_anda"; frame_use = 1
                    else
                        sprite_estado = "neutron_fade"
                        if alpha <= 0.33 then frame_use = 1
                        elseif alpha <= 0.66 then frame_use = 2
                        else frame_use = 3 end
                    end
                    local sprite = Sprites.sprite(sprite_estado, frame_use)
                    if sprite then
                        ui.spr(sprite,
                            math.floor(inimigo.x - cam_x - (sprite.width or 16) / 2),
                            math.floor(inimigo.y - cam_y - (sprite.height or 16) / 2),
                            false, false)
                    end
                end
            else
                local sprite_estado, frame_use
                if inimigo.tipo == "statue" or inimigo.tipo == "orbo"
                or inimigo.tipo == "jaws" or inimigo.tipo == "spike-ball" then
                    sprite_estado = inimigo.modo == "ataque" and inimigo.cfg.sprite_ataq or inimigo.cfg.sprite_anda
                    frame_use = 1
                elseif inimigo.modo == "ataque" and inimigo.cfg.sprite_ataq then
                    sprite_estado = inimigo.cfg.sprite_ataq
                    if inimigo.tipo == "bomb" then frame_use = inimigo.frame_anim else frame_use = 1 end
                else
                    sprite_estado = inimigo.cfg.sprite_anda
                    frame_use = inimigo.frame_anim
                end
                local sprite = Sprites.sprite(sprite_estado, frame_use)
                if sprite then
                    ui.spr(sprite,
                        math.floor(inimigo.x - cam_x - (sprite.width or 16) / 2),
                        math.floor(inimigo.y - cam_y - (sprite.height or 16) / 2),
                        inimigo.direcao > 0, false)
                end
            end

            if inimigo.tipo == "orbo" and inimigo.orbes_pos then
                local sprite = Sprites.sprite("orbo_orbita", 1)
                if sprite then
                    local hw = (sprite.width or 8) / 2
                    local hh = (sprite.height or 8) / 2
                    for _, o in ipairs(inimigo.orbes_pos) do
                        ui.spr(sprite,
                            math.floor(o.x - cam_x - hw),
                            math.floor(o.y - cam_y - hh),
                            false, false)
                    end
                end
            end
        end
    end

    for _, s in ipairs(Inimigos.segmentos) do
        local sprite_estado = s.is_cabeca and "cater_cabeca" or "cater_segmento"
        local sprite = Sprites.sprite(sprite_estado, 1)
        if sprite then
            ui.spr(sprite,
                math.floor(s.x - cam_x - (sprite.width or 8) / 2),
                math.floor(s.y - cam_y - (sprite.height or 8) / 2),
                false, false)
        end
    end

    for _, p in ipairs(Inimigos.projeteis) do
        local estado = p.sprite_estado or "bala"
        local sprite = Sprites.sprite(estado, p.frame or 1)
        if sprite then
            local flip = false
            if estado == "statue_ataq" and p.vx > 0 then flip = true end
            ui.spr(sprite,
                math.floor(p.x - cam_x - (sprite.width or 8) / 2),
                math.floor(p.y - cam_y - (sprite.height or 8) / 2),
                flip, false)
        end
    end

    for _, e in ipairs(Inimigos.explosoes) do
        local sprite = Sprites.sprite("explode", e.frame)
        if sprite then
            ui.spr(sprite,
                math.floor(e.x - cam_x - (sprite.width or 16) / 2),
                math.floor(e.y - cam_y - (sprite.height or 16) / 2),
                false, false)
        end
    end
end

return Inimigos
