local Objetos = {}
local Mapa = require("mapa")
local PlayerSys = require("sistemas.player")
local Sprites = require("sistemas.sprites")
local Timer = require("sistemas.timer")
local State = require("state")
local UI = require("sistemas.ui")
local Animacao = require("sistemas.animacao")

local GRAVIDADE = 0.0090
local AMORTECIMENTO = 1.0
local LARGURA_PLATAFORMA = 16
-- map_plataforma tem 2 tiles de 16 = 32px de largura
local LARGURA_MAPA_PLAT  = 32

-- Zonas que dão acesso à fase especial (as 4 primeiras do Sonic 1 SMS).
-- Usa o sigla que já existe em State.stages, sem campo novo.
local ZONAS_COM_ESP = { gh = true, bz = true, jz = true, lz = true }

-- Queda de monitor atingido por baixo
local MONITOR_GRAVIDADE = 0.30
local MONITOR_VY_MAX    = 8

local MONITOR_FRAME = {
    monitor_anel = 2,
    monitor_sapato_rapido = 3,
    monitor_vida = 4,
    monitor_escudo = 5,
    monitor_invenc = 6,
    monitor_salva = 7,
    monitor_cont = 8,
}

-- Sprites.sprite NÃO lê frame_fixo do ANIMACOES (só animacao.lua lê).
-- Por isso o frame do resultado da placa é resolvido aqui.
local PLACA_RESULTADO_FRAME = {
    placa_normal   = 1,
    placa_especial = 2,   -- "!"  -> fase especial
    placa_aneis    = 3,   -- anel -> +10 anéis
    placa_vida     = 4,   -- Sonic -> +1 vida
    placa_chefe    = 5,   -- Eggman -> nada
}

local monitor_estatica_fase = 1
local monitor_estatica_timer = 0
local MONITOR_ESTATICA_CADENCIA = 30
local anim_timer = 0

local cache_monitor = {}
local cache_placa = {}

local function sprite_monitor(frame)
    local s = cache_monitor[frame]
    if s then return s end
    s = Sprites.sprite("monitor_anel", frame)
    if s then cache_monitor[frame] = s end
    return s
end

local function sprite_placa(estado, frame)
    local cache_estado = cache_placa[estado]
    if not cache_estado then
        cache_estado = {}
        cache_placa[estado] = cache_estado
    end
    local s = cache_estado[frame]
    if s then return s end
    s = Sprites.sprite(estado, frame)
    if s then cache_estado[frame] = s end
    return s
end

-- ============================================================
-- PONTE FALSA (Bridge Zone)
-- Cai após o Sonic ficar em cima por ~1 segundo.
-- ============================================================
local PONTES_FALSAS = {}

local PONTE_TREMER_FRAMES = 60        -- 1 s tremendo antes de cair
local PONTE_GRAVIDADE     = 0.35      -- px/frame²
local PONTE_Y_SUMIU       = 400       -- offset vertical da câmera → some

local SPRITE_PONTE = "obj_fases/BZ/ponte-W16xH8"

local function init_pontes_falsas(dados)
    PONTES_FALSAS = {}
    local Terreno = require("sistemas.terreno")
    Terreno.limpar_suportes_dinamicos()
    local lista = dados and dados.ponte_falsa or {}
    for i, p in ipairs(lista) do
        local ponte = {
            x = p.x, y = p.y,
            w = p.w or 16, h = p.h or 8,
            estado = "parada",
            timer  = 0,
            vel_y  = 0,
            dx_draw = 0, dy_draw = 0,
        }
        ponte.suporte = Terreno.adicionar_suporte(p.x, p.y, ponte.w, ponte.h, "ponte_" .. i)
        table.insert(PONTES_FALSAS, ponte)
    end
end

local function sonic_em_cima(ponte, player)
    local px = player.x + 8                          -- centro do Sonic
    local py = player.y + player.h or player.y + 16  -- pé do Sonic
    if px < ponte.x or px > ponte.x + ponte.w then return false end
    if math.abs(py - ponte.y) > 4 then return false end           -- em cima do topo
    if (player.velocidade_y or 0) < 0 then return false end       -- subindo = não
    return true
end

local function atualizar_pontes_falsas(player)
    if not player then return end
    local Terreno = require("sistemas.terreno")
    for _, ponte in ipairs(PONTES_FALSAS) do
        if ponte.estado == "parada" then
            if sonic_em_cima(ponte, player) then
                ponte.estado = "tremendo"
                ponte.timer  = 0
            end
        elseif ponte.estado == "tremendo" then
            ponte.timer = ponte.timer + 1
            if ponte.timer % 2 == 0 then
                ponte.dx_draw = (ponte.timer % 4 == 0) and 1 or -1
                ponte.dy_draw = (ponte.timer % 4 == 0) and 1 or -1
            end
            if ponte.timer >= PONTE_TREMER_FRAMES then
                ponte.estado = "caindo"
                ponte.timer  = 0
                ponte.vel_y  = 0
                ponte.dx_draw, ponte.dy_draw = 0, 0
                Terreno.remover_suporte(ponte.suporte)
            end
        elseif ponte.estado == "caindo" then
            ponte.vel_y = ponte.vel_y + PONTE_GRAVIDADE
            ponte.y     = ponte.y + ponte.vel_y
            if ponte.y - player.y > PONTE_Y_SUMIU then
                ponte.estado = "sumiu"
            end
        end
    end
end

local function desenhar_pontes_falsas(cam_x, cam_y)
    for _, ponte in ipairs(PONTES_FALSAS) do
        if ponte.estado ~= "sumiu" then
            local dx = math.floor(ponte.x - cam_x + ponte.dx_draw)
            local dy = math.floor(ponte.y - cam_y + ponte.dy_draw)
            local cols = math.max(1, math.ceil(ponte.w / 16))
            for c = 0, cols - 1 do
                ui.spr(SPRITE_PONTE, dx + c * 16, dy)
            end
        end
    end
end

-- ============================================================
-- CELA / CÁPSULA PÓS-CHEFE (mesmo sistema para todos os chefes)
--   cela-W34xH64.png    : 4 tiles de 34x64 (4 col x 1 lin)
--   animais-W18xH16.png : 12 tiles de 18x16 (4 col x 3 lin)
--   coelho-W16xH24.png  : 2 tiles de 16x24 (2 col x 1 lin)
-- ============================================================
local CELA_TW,   CELA_TH,   CELA_COLS   = 34, 64, 4
local ANIM_TW,   ANIM_TH,   ANIM_COLS   = 18, 16, 4
local COELHO_TW, COELHO_TH, COELHO_COLS = 16, 24, 2

local CELA_TEMPO_ABRINDO1 = 60    -- 1 segundo parado no tile 1
local CELA_TEMPO_BOTAO    = 30    -- descida do botão (tile 2)
local CELA_TEMPO_EXPLOSAO = 90    -- explosões antes de virar tile 3
local CELA_BOTAO_DESCIDA  = 8     -- px que o botão desce
local CELA_ANIMAIS_MIN    = 1
local CELA_ANIMAIS_MAX    = 7
local ANIMAL_VIDA         = 900
local ANIMAL_GRAVIDADE    = 0.25
local ANIMAL_CADENCIA     = 8
local ANIMAL_RAIO         = 110   -- os animais pulam dentro de cx ± 110px
local CELA_TEMPO_ANIMAIS  = 180   -- 3s de pausa com os animais antes da vitória

-- via State.chefe_liberou_animais. Manter nil para não tocar em dobro.
local BGM_VITORIA_CELA = nil

local IMG_CELA, IMG_ANIMAIS, IMG_COELHO = nil, nil, nil
local cela_sprites_buscados = false

local cela_anim = {
    fase = "fechada",   -- fechada > abrindo1 > abrindo2 > explosoes > aberta > animais
    timer = 0,
    botao_dy = 0,
    animais = {},
    bgm_tocada = false,
    finalizado = false,
}

local function carregar_sprites_cela()
    if cela_sprites_buscados then return end
    cela_sprites_buscados = true
    IMG_CELA    = UI.buscar_sprite("cela-W34xH64")
    IMG_ANIMAIS = UI.buscar_sprite("animais-W18xH16")
    IMG_COELHO  = UI.buscar_sprite("coelho-W16xH24")
end

-- Recorta 1 tile de um spritesheet via clip + ui.spr.
-- Com flip, ui.spr espelha a FOLHA inteira: o offset é compensado
-- para o tile desejado cair na janela de clip (mesma técnica do Eggman do mapa).
local function desenhar_tile_sheet(img, tile, cols, tw, th, x, y, flip)
    if not img then return end
    local sx = (tile % cols) * tw
    local sy = math.floor(tile / cols) * th
    local dx = x - sx
    if flip then
        local largura_folha = img.width or (cols * tw)
        dx = x - (largura_folha - sx - tw)
    end
    ui.clip(x, y, tw, th)
    ui.spr(img, dx, y - sy, flip, false)
    ui.clip()
end

local function atualizar_cela(player)
    if not (State.chefe_derrotado and Objetos.cela) then return end

    local c = Objetos.cela
    local cx = c.x + c.w / 2      -- centro horizontal da capsula
    local base_y = c.y            -- base da capsula = linha do chao

    -- Ativacao por PRESSAO (pousar em cima), em Objetos.resolver_cela.
    if cela_anim.fase == "fechada" then return end

    cela_anim.timer = cela_anim.timer + 1

    if cela_anim.fase == "abrindo1" then
        -- tile 1, espera 1 segundo
        if cela_anim.timer >= CELA_TEMPO_ABRINDO1 then
            cela_anim.fase  = "abrindo2"
            cela_anim.timer = 0
        end

    elseif cela_anim.fase == "abrindo2" then
        -- tile 2 + botao descendo
        local t = math.min(1, cela_anim.timer / CELA_TEMPO_BOTAO)
        cela_anim.botao_dy = CELA_BOTAO_DESCIDA * t
        if cela_anim.timer >= CELA_TEMPO_BOTAO then
            cela_anim.fase  = "explosoes"
            cela_anim.timer = 0
        end

    elseif cela_anim.fase == "explosoes" then
        -- explosoes criadas no update, nao no draw
        local Inimigos = require("sistemas.inimigos")
        if cela_anim.timer % 12 == 0 then
            Inimigos.criar_explosao(
                cx + math.random(-14, 14),
                base_y - 32 + math.random(-24, 24)
            )
        end
        if cela_anim.timer >= CELA_TEMPO_EXPLOSAO then
            cela_anim.fase  = "aberta"
            cela_anim.timer = 0
        end

    elseif cela_anim.fase == "aberta" then
        -- capsula quebrada (tile 3): saem os 7 animais, um de cada tipo
        for i = 1, 7 do
            local dir = (i % 2 == 0) and 1 or -1
            table.insert(cela_anim.animais, {
                tipo  = i,
                x     = cx + math.random(-4, 4),
                y     = base_y - 32,
                vx    = dir * (0.6 + math.random() * 0.8),
                vy    = -(2.5 + math.random() * 1.5),
                frame = 1, timer_anim = 0,
                vida  = ANIMAL_VIDA,
            })
        end
        if not cela_anim.bgm_tocada then
            cela_anim.bgm_tocada = true
            if BGM_VITORIA_CELA and music then
                music.loop(BGM_VITORIA_CELA, 1.5)
            end
        end
        cela_anim.fase  = "animais"
        cela_anim.timer = 0

    elseif cela_anim.fase == "animais" then
        -- pausa com os animais pulando; depois puxa a tela de vitoria
        if cela_anim.timer >= CELA_TEMPO_ANIMAIS then
            cela_anim.fase = "fim"
            Objetos._finalizar_ato_cela()
        end
    end

    -- fisica dos animais: quicam de um lado para o outro em volta da capsula,
    -- sem sair da tela. Nao colidem com a capsula (atravessam o sprite quebrado).
    local lim_esq = cx - ANIMAL_RAIO
    local lim_dir = cx + ANIMAL_RAIO
    for i = #cela_anim.animais, 1, -1 do
        local a = cela_anim.animais[i]
        local th = (a.tipo == 7) and COELHO_TH or ANIM_TH
        a.vy = a.vy + ANIMAL_GRAVIDADE
        a.x  = a.x + a.vx
        if a.x < lim_esq then
            a.x = lim_esq; a.vx = math.abs(a.vx)
        elseif a.x > lim_dir then
            a.x = lim_dir; a.vx = -math.abs(a.vx)
        end
        a.y = a.y + a.vy
        local chao = Mapa.altura_suporte(a.x, a.y + th / 2, 24)
        if chao and a.y + th / 2 >= chao and a.vy > 0 then
            a.y  = chao - th / 2
            a.vy = -2.6
        end
        a.timer_anim = a.timer_anim + 1
        if a.timer_anim >= ANIMAL_CADENCIA then
            a.timer_anim = 0
            a.frame = (a.frame == 1) and 2 or 1
        end
        a.vida = a.vida - 1
        if a.vida <= 0 then table.remove(cela_anim.animais, i) end
    end
end

local function desenhar_cela(cam_x, cam_y)
    if not (State.chefe_derrotado and Objetos.cela and Objetos.botaocela) then return end
    carregar_sprites_cela()

    local c = Objetos.cela
    local cx, base_y = c.x + c.w / 2, c.y

    local tile = 0
    if cela_anim.fase == "abrindo1" then
        tile = 1
    elseif cela_anim.fase == "abrindo2" or cela_anim.fase == "explosoes" then
        tile = 2
    elseif cela_anim.fase == "aberta" or cela_anim.fase == "animais"
        or cela_anim.fase == "fim" then
        tile = 3
    end

    local sx = math.floor(cx - CELA_TW / 2 - cam_x)
    local sy = math.floor(base_y - CELA_TH - cam_y)
    if IMG_CELA then
        desenhar_tile_sheet(IMG_CELA, tile, CELA_COLS, CELA_TW, CELA_TH, sx, sy, false)
    else
        -- fallback visível: se aparecer este retângulo, o lookup do asset falhou
        ui.rectfill(sx, sy, CELA_TW, CELA_TH, 12)
    end

    for _, a in ipairs(cela_anim.animais) do
        local img, tw, th, cols, tile_base
        if a.tipo == 7 then
            img, tw, th, cols = IMG_COELHO, COELHO_TW, COELHO_TH, COELHO_COLS
            tile_base = a.frame - 1
        else
            img, tw, th, cols = IMG_ANIMAIS, ANIM_TW, ANIM_TH, ANIM_COLS
            tile_base = (a.tipo - 1) * 2 + (a.frame - 1)
        end
        desenhar_tile_sheet(img, tile_base, cols, tw, th,
            math.floor(a.x - tw / 2 - cam_x),
            math.floor(a.y - th / 2 - cam_y),
            a.vx < 0)
    end
end

-- Caixa sólida derivada do SPRITE (34x64), não do marcador 16x16 do Tiled.
-- O topo da caixa é o botão de pressão.
local function caixa_cela()
    local c = Objetos.cela
    local cx = c.x + c.w / 2
    local x0 = cx - CELA_TW / 2
    local y0 = c.y - CELA_TH
    return x0, y0, x0 + CELA_TW, y0 + CELA_TH
end

function Objetos.em_cutscene_cela()
    return State.cela_cutscene == true
end

function Objetos._acionar_botao_cela()
    if cela_anim.fase ~= "fechada" then return end
    State.chefe_liberou_animais = true
    cela_anim.fase  = "abrindo1"
    cela_anim.timer = 0
    -- câmera deixa de seguir o Sonic e trava na cela
    State.cela_cutscene = true
    State.cela_foco_x   = Objetos.cela.x + Objetos.cela.w / 2
    State.cela_foco_y   = Objetos.cela.y - CELA_TH / 2
end

-- Rodar DEPOIS de Player.update (mesmo motivo do Inimigos.colisoes_player:
-- o pouso zera velocidade_y, então usamos vy_impacto / pes_prev do contexto).
function Objetos.resolver_cela(player)
    if not (State.chefe_derrotado and Objetos.cela) then return end
    if not player or player.morto then return end
    -- A caixa sólida vale para TODAS as fases, até a tela de vitória.

    local x0, y0, x1, y1 = caixa_cela()
    local px0, py0, px1, py1 = PlayerSys.get_hitbox(player)
    if not (px0 < x1 and px1 > x0 and py0 < y1 and py1 > y0) then return end

    local ctx = PlayerSys.contexto_ataque(player)
    local overlap_x = math.min(px1, x1) - math.max(px0, x0)
    local overlap_y = math.min(py1, y1) - math.max(py0, y0)

    -- lateral: bloqueia (a cela é sólida, não quebra rolando)
    if overlap_x < overlap_y then
        local half_w = PlayerSys.COLISAO_HALF_W
        local off_x  = PlayerSys.COLISAO_OFFSET_X or 0
        if px0 < x0 then
            player.x = x0 - half_w - off_x
        else
            player.x = x1 + half_w - off_x
        end
        player.velocidade_x = 0
        return
    end

    if py0 < y0 then
        -- veio de cima: pousa em cima do botão
        player.y = y0 - PlayerSys.COLISAO_BASE_Y
        player.velocidade_y = 0
        player.no_chao      = true
        player.esta_pulando = false
        if ctx.caindo and ctx.pes_prev <= y0 + 8 then
            Objetos._acionar_botao_cela()
        end
    else
        -- bateu por baixo
        player.y = y1 - PlayerSys.COLISAO_TOPO_Y
        player.velocidade_y = 0
    end
end

-- Plataforma por zona: GH usa tile do tileset (licgrenhll 130);
-- BZ tem sprite próprio 32x16 em fases/obj_fases/BZ/.
local PLATAFORMA_ASSET = {
    bz = "fases/obj_fases/BZ/plataforma-W32xH16",
}
local plataforma_sprite_cache = {}

local function resolver_asset(caminho)
    local r = _G.Sprites
    if type(r) ~= "table" then return nil end
    if r[caminho] then return r[caminho] end
    if r[caminho .. ".png"] then return r[caminho .. ".png"] end
    local atual = r
    for parte in caminho:gmatch("[^/]+") do
        if type(atual) ~= "table" then return nil end
        atual = atual[parte]
        if atual == nil then return nil end
    end
    return atual
end

local function sprite_plataforma_zona()
    local stage = State.stages[State.stage_atual]
    local caminho = PLATAFORMA_ASSET[stage and stage.sigla or ""]
    if not caminho then return nil end
    local s = plataforma_sprite_cache[caminho]
    if s == nil then
        s = resolver_asset(caminho) or false
        plataforma_sprite_cache[caminho] = s
    end
    return s or nil
end

function Objetos.init(dados_terreno)
    Objetos.lista = {}
    Objetos.outros = {}
    Objetos.plataformas = {}
    Objetos.esmeraldas = {}
    Objetos.placa = nil
    Objetos.emissores = {}
    Objetos.bolhas = {}
    anim_timer = 0
    cache_monitor = {}
    cache_placa = {}
    cela_anim.fase = "fechada"
    cela_anim.timer = 0
    cela_anim.botao_dy = 0
    cela_anim.animais = {}
    cela_anim.bgm_tocada = false
    cela_anim.finalizado = false
    cela_sprites_buscados = false
    State.cela_cutscene = false
    State.cela_foco_x   = nil
    State.cela_foco_y   = nil
    init_pontes_falsas(dados_t)
    Objetos.map_plataforma = {
        metadata = { width = 2, height = 1, tile_size = 16 },
        tilesets = Mapa.get_tilesets(),
        licgrenhll = { 130, 130 }
    }

    if not dados_terreno then return end

    Objetos.cela = dados_terreno.cela
    Objetos.botaocela = dados_terreno.botaocela

    if dados_terreno.pontos_ar then
        for _, p in ipairs(dados_terreno.pontos_ar) do
            table.insert(Objetos.emissores, {
                x = p.x, y = p.y, timer = 0,
                burst_count = 0, burst_timer = 0
            })
        end
    end

    if dados_terreno.pendulos then
        for _, p in ipairs(dados_terreno.pendulos) do
            local angulo_inicial = p.angulo_inicial
            if math.abs(angulo_inicial) < 0.1 then angulo_inicial = math.rad(45) end
            table.insert(Objetos.lista, {
                x = p.x, y = p.y,
                comprimento = p.comprimento,
                angulo = angulo_inicial,
                vel_angulo = 0,
                x_plataforma = p.x + math.sin(angulo_inicial) * p.comprimento,
                y_plataforma = p.y + math.cos(angulo_inicial) * p.comprimento,
                delta_x = 0, delta_y = 0
            })
        end
    end

    if dados_terreno.plataformas_flutuantes then
        for _, p in ipairs(dados_terreno.plataformas_flutuantes) do
            table.insert(Objetos.plataformas, {
                x = p.x, y = p.y,
                largura = p.largura, altura = p.altura,
                x_inicial = p.x_inicial,
                amplitude = p.amplitude or 64,
                velocidade = p.velocidade or 1.0,
                direcao = p.direcao or 1,
                delta_x = 0, delta_y = 0,
            })
        end
    end

    if dados_terreno.outros then
        for _, o in ipairs(dados_terreno.outros) do
            local copia = {}
            for k, v in pairs(o) do copia[k] = v end
            Objetos.outros[#Objetos.outros + 1] = copia
            if copia.tipo == 'venceu' then
                Objetos.placa = copia
            end
        end
    end

    if dados_terreno.esmeraldas then
        for _, e in ipairs(dados_terreno.esmeraldas) do
            local copia = {}
            for k, v in pairs(e) do copia[k] = v end
            Objetos.esmeraldas[#Objetos.esmeraldas + 1] = copia
        end
    end
end

function Objetos.update(player)
    if not Objetos.lista then return end

    anim_timer = anim_timer + 1

    -- Emissores e Bolhas de Ar
    for _, em in ipairs(Objetos.emissores) do
        if em.burst_count > 0 then
            em.burst_timer = em.burst_timer - 1
            if em.burst_timer <= 0 then
                table.insert(Objetos.bolhas, {
                    x = em.x + math.random(-2, 2),
                    y = em.y - 6,
                    timer_coleta = 0,
                    coletada = false,
                    vel_y = -0.6 - (math.random() * 0.2)
                })
                em.burst_count = em.burst_count - 1
                em.burst_timer = 12
            end
        else
            em.timer = em.timer + 1
            if em.timer >= 240 then
                em.timer = 0
                em.burst_count = 3
                em.burst_timer = 0
            end
        end
    end

    for i = #Objetos.bolhas, 1, -1 do
        local b = Objetos.bolhas[i]
        if b.coletada then
            b.timer_coleta = b.timer_coleta - 1
            if b.timer_coleta <= 0 then
                table.remove(Objetos.bolhas, i)
            end
        else
            b.y = b.y + b.vel_y

            local fora_agua = true
            for _, area in ipairs(Mapa.get_areas_agua()) do
                if b.x >= area.x and b.x <= area.x + area.w and b.y >= area.y and b.y <= area.y + area.h then
                    fora_agua = false
                    break
                end
            end

            if fora_agua or b.y < 0 then
                table.remove(Objetos.bolhas, i)
            else
                local px0, py0, px1, py1 = PlayerSys.get_hitbox(player)
                if px0 < b.x + 8 and px1 > b.x - 8 and py0 < b.y + 8 and py1 > b.y - 8 then
                    b.coletada = true
                    b.timer_coleta = 15
                    if State.oxigenio then
                        State.oxigenio.tempo_restante = State.oxigenio.tempo_maximo
                    end
                    Animacao.iniciar(player, "ar", 30)
                end
            end
        end
    end

    for _, p in ipairs(Objetos.lista) do
        local forca = -(GRAVIDADE / p.comprimento) * math.sin(p.angulo)
        p.vel_angulo = (p.vel_angulo + forca) * AMORTECIMENTO
        p.angulo = p.angulo + p.vel_angulo
        local novo_x = p.x + math.sin(p.angulo) * p.comprimento
        local novo_y = p.y + math.cos(p.angulo) * p.comprimento
        p.delta_x = novo_x - p.x_plataforma
        p.delta_y = novo_y - p.y_plataforma
        p.x_plataforma = novo_x
        p.y_plataforma = novo_y
    end

    for _, pl in ipairs(Objetos.plataformas) do
        local antigo_x = pl.x
        pl.x = pl.x + pl.velocidade * pl.direcao
        if pl.amplitude > 0 then
            if pl.x > pl.x_inicial + pl.amplitude then pl.direcao = -1
            elseif pl.x < pl.x_inicial - pl.amplitude then pl.direcao = 1 end
        end
        pl.delta_x = pl.x - antigo_x
        pl.delta_y = 0

        local player_em_cima = (
            player.x + 16 > pl.x and player.x < pl.x + pl.largura and
            math.abs((player.y + 32) - pl.y) < 8 and
            player.velocidade_y >= 0
        )
        if player_em_cima then
            player.plataforma_atual = pl
        elseif player.plataforma_atual == pl then
            player.plataforma_atual = nil
        end
    end

    for _, e in ipairs(Objetos.esmeraldas) do
        if not e.coletado then
            local px0, py0, px1, py1 = PlayerSys.get_hitbox(player)
            if px0 < e.x + 8 and px1 > e.x - 8 and py0 < e.y + 8 and py1 > e.y - 8 then
                e.coletado = true
                State.esmeraldas_coletadas = (State.esmeraldas_coletadas or 0) + 1
                State.esmeralda_no_ato = true
                State.pontuacao = State.pontuacao + 1000
                State.buffs.invencivel = 7 * 60
            end
        end
    end

    for _, o in ipairs(Objetos.outros) do
        if o.tipo == 'venceu' and not o.coletado then
            local px0, py0, px1, py1 = PlayerSys.get_hitbox(player)
            if px0 < o.x + o.w and px1 > o.x and py0 < o.y + o.h and py1 > o.y then
                o.coletado = true
                Objetos._iniciar_placa_final(o, State)
            end
        elseif o.tipo == 'monitores' and o.caindo and not o.coletado then
            -- Monitor atingido por baixo: desce até o chão mais próximo.
            o.vy = math.min((o.vy or 0) + MONITOR_GRAVIDADE, MONITOR_VY_MAX)
            local novo_y    = o.y + o.vy
            local base_nova = novo_y + o.h
            local chao = Mapa.altura_suporte(o.x + o.w / 2, base_nova, 64)
            if chao and base_nova >= chao then
                o.y = chao - o.h
                o.vy = 0
                o.caindo = false
            else
                o.y = novo_y
            end
        end
    end

    atualizar_cela(player)
    atualizar_pontes_falsas(player)

    if State.placa and State.placa.ativa then
        State.placa.timer = State.placa.timer + 1
        if State.placa.timer <= 60 then
            State.placa.y = State.placa.y - 1.5
        elseif State.placa.timer <= 90 then
        elseif State.placa.timer <= 150 then
            State.placa.y = State.placa.y + 1.5
        else
            if State.stage_e_especial and State.stage_e_especial() then
                if State.sp_concluir then State.sp_concluir() end
                State.resultado = "especial_ok"
            else
                State.resultado = "vitoria"
            end
            State.proxima_cena = State.SCREEN_VICTORY
            local Transicao = require("sistemas.transicao")
            if not Transicao.ativa then Transicao.iniciar() end
        end
    end
end

function Objetos._aplicar_monitor(nome, state_ref, x, y)
    local Inimigos = require("sistemas.inimigos")
    if Inimigos.criar_explosao then Inimigos.criar_explosao(x, y) end

    if nome == 'monitor_anel' then
        state_ref.inventory.aneis = state_ref.inventory.aneis + 10
        while state_ref.inventory.aneis >= 100 do
            state_ref.inventory.aneis = state_ref.inventory.aneis - 100
            state_ref.vidas = state_ref.vidas + 1
        end
    elseif nome == 'monitor_sapato_rapido' then
        state_ref.buffs.velocidade_extra = 20 * 60
    elseif nome == 'monitor_vida' then
        state_ref.vidas = state_ref.vidas + 1
    elseif nome == 'monitor_escudo' then
        state_ref.buffs.escudo = true
    elseif nome == 'monitor_invenc' then
        state_ref.buffs.invencivel = 7 * 60
    elseif nome == 'monitor_salva' or nome == 'monitor_seta' then
        local player = state_ref.player
        state_ref.checkpoint_ativo = true
        state_ref.checkpoint_x = player.x
        state_ref.checkpoint_y = player.y
        player.spawn_x = player.x
        player.spawn_y = player.y
    elseif nome == 'monitor_cont' then
        state_ref.continuacoes = (state_ref.continuacoes or 0) + 1
    end
end

-- Bônus de fim de ato: usado pela placa_final E pelo botão da cela.
function Objetos._calcular_bonus_ato(state_ref)
    local aneis = state_ref.inventory.aneis or 0
    local tempo_segundos = Timer.segundos
    state_ref.tempo_final = tempo_segundos
    local bonus_aneis = aneis * 100
    state_ref.bonus_aneis = bonus_aneis
    local bonus_tempo = 0
    if tempo_segundos <= 20 then bonus_tempo = 50000
    elseif tempo_segundos <= 30 then bonus_tempo = 10000
    elseif tempo_segundos <= 40 then bonus_tempo = 5000
    elseif tempo_segundos <= 50 then bonus_tempo = 4000
    elseif tempo_segundos <= 60 then bonus_tempo = 3000
    elseif tempo_segundos <= 120 then bonus_tempo = 2000
    elseif tempo_segundos <= 180 then bonus_tempo = 1000
    elseif tempo_segundos <= 240 then bonus_tempo = 500
    elseif tempo_segundos <= 300 then bonus_tempo = 100
    else bonus_tempo = 0
    end
    state_ref.bonus_tempo = bonus_tempo
    state_ref.pontuacao = (state_ref.pontuacao or 0) + bonus_aneis + bonus_tempo
    return aneis
end

-- Fim de ato sem placa: o botão da cela puxa a tela de vitória
-- pelo mesmo fluxo (Transicao + SCREEN_VICTORY) da placa_final.
function Objetos._finalizar_ato_cela()
    if cela_anim.finalizado then return end
    cela_anim.finalizado = true
    Objetos._calcular_bonus_ato(State)
    State.resultado = "vitoria"
    State.proxima_cena = State.SCREEN_VICTORY
    local Transicao = require("sistemas.transicao")
    if not Transicao.ativa then Transicao.iniciar() end
end

function Objetos._iniciar_placa_final(o, state_ref)
    state_ref.placa.ativa = true
    state_ref.placa.x = o.x
    state_ref.placa.y = o.y
    state_ref.placa.timer = 0
    local aneis = Objetos._calcular_bonus_ato(state_ref)
    -- na sala especial os itens vêm dos monitores, não da placa
    if state_ref.stage_e_especial and state_ref.stage_e_especial() then
        state_ref.placa.resultado = "placa_normal"
        return
    end
    local stage = state_ref.stages[state_ref.stage_atual]
    local sigla = (stage and stage.sigla) or ""
    if aneis >= 50 and aneis <= 99 and ZONAS_COM_ESP[sigla] then
        -- "!" -> sala especial (só nas 4 primeiras zonas)
        state_ref.placa.resultado = "placa_especial"
    elseif aneis >= 40 and aneis <= 49 then
        -- rosto do Sonic -> 1 vida
        state_ref.placa.resultado = "placa_vida"
        state_ref.vidas = state_ref.vidas + 1
    elseif aneis > 0 and aneis % 10 == 0 then
        -- anel -> 10 anéis de pontuação
        state_ref.placa.resultado = "placa_aneis"
        state_ref.inventory.aneis = state_ref.inventory.aneis + 10
    else
        -- Eggman -> nada
        state_ref.placa.resultado = "placa_chefe"
    end
end

function Objetos.draw(cam_x, cam_y)
    if Objetos.lista then
        for _, p in ipairs(Objetos.lista) do
            local px, py = p.x_plataforma - cam_x, p.y_plataforma - cam_y
            ui.map(Objetos.map_plataforma, math.floor(px - LARGURA_PLATAFORMA), math.floor(py))
        end
    end

    if Objetos.map_plataforma then
        local spr_plat = sprite_plataforma_zona()
        for _, pl in ipairs(Objetos.plataformas) do
            local larg  = pl.largura or 32
            local x_ini = pl.x - cam_x
            local y_pos = pl.y - cam_y
            if spr_plat then
                ui.spr(spr_plat, math.floor(x_ini), math.floor(y_pos), false, false)
            else
                for w = 0, math.max(0, larg - LARGURA_MAPA_PLAT), LARGURA_MAPA_PLAT do
                    ui.map(Objetos.map_plataforma, math.floor(x_ini + w), math.floor(y_pos))
                end
            end
        end
    end

    for _, em in ipairs(Objetos.emissores) do
        local pulso_y = math.sin(anim_timer * 0.1) * 1
        UI.desenhar_parte_ui(5, 69, 7, 11, math.floor(em.x - cam_x - 3.5), math.floor(em.y - cam_y - 5.5 + pulso_y))
    end

    for _, b in ipairs(Objetos.bolhas) do
        if b.coletada then
            if b.timer_coleta > 0 then
                UI.desenhar_parte_ui(33, 66, 15, 12, math.floor(b.x - cam_x - 7.5), math.floor(b.y - cam_y - 6))
            end
        else
            UI.desenhar_parte_ui(16, 64, 16, 16, math.floor(b.x - cam_x - 8), math.floor(b.y - cam_y - 8))
        end
    end

    desenhar_cela(cam_x, cam_y)
    desenhar_pontes_falsas(cam_x, cam_y)

    monitor_estatica_timer = monitor_estatica_timer + 1
    if monitor_estatica_timer >= MONITOR_ESTATICA_CADENCIA then
        monitor_estatica_timer = 0
        monitor_estatica_fase = (monitor_estatica_fase == 1) and 2 or 1
    end

    for _, o in ipairs(Objetos.outros) do
        if o.tipo == 'monitores' and not o.coletado then
            local f_efeito = MONITOR_FRAME[o.nome] or 1
            local f = (monitor_estatica_fase == 2) and f_efeito or 1
            local sprite = sprite_monitor(f)
            if sprite then
                ui.spr(sprite, math.floor(o.x - cam_x + (o.w - (sprite.width or 16)) / 2), math.floor(o.y - cam_y + (o.h - (sprite.height or 16)) / 2), false, false)
            end
        elseif o.tipo == 'venceu' then
            local sprite_estado, frame_use, px, py
            if not o.coletado then
                sprite_estado = "placa_normal"; frame_use = 1; px = o.x; py = o.y
            elseif State.placa and State.placa.ativa then
                if State.placa.timer > 60 then
                    sprite_estado = State.placa.resultado or "placa_normal"
                    frame_use = PLACA_RESULTADO_FRAME[sprite_estado] or 1
                else
                    sprite_estado = "placa_giro"; frame_use = 1 + (math.floor(State.placa.timer / 8) % 3)
                end
                px = State.placa.x; py = State.placa.y
            else
                sprite_estado = "placa_normal"; frame_use = 1; px = o.x; py = o.y
            end
            local sprite = sprite_placa(sprite_estado, frame_use)
            if sprite then ui.spr(sprite, math.floor(px - cam_x), math.floor(py - cam_y), false, false) end
        end
    end

    local piscar = math.floor(anim_timer / 10) % 2 == 0
    for _, e in ipairs(Objetos.esmeraldas) do
        if not e.coletado and piscar then
            UI.desenhar_tile_ui(15, math.floor(e.x - cam_x - 8), math.floor(e.y - cam_y - 8))
        end
    end
end

return Objetos
