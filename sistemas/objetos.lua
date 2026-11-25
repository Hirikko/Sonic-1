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
local LARGURA_MAPA_PLAT  = 32

local ZONAS_COM_ESP = { gh = true, bz = true, jz = true, lz = true }

local MONITOR_GRAVIDADE = 0.30
local MONITOR_VY_MAX    = 8
-- Checkpoint: sobrevive ao reset da fase (morte). So o continue limpa.
-- Fica em local do modulo, que o Objetos.init nao zera.
local CHECKPOINT_RECUO = 24   -- px atras do monitor
local checkpoint_mem = nil
local checkpoint_pendente = false

-- Ponte (piso_falso): cada tabua cai 1s depois de pisada, sem respawn.
local PONTE_ATRASO    = 60
local PONTE_GRAVIDADE = 0.35
local PONTE_VY_MAX    = 10
local PONTE_TREMOR    = 1     -- px de aviso durante o 1s (0 = sem tremor)

-- Afundamento das plataformas sob o peso do Sonic.
-- Teto de 6px: o carry do Player.update so regruda o y com diff < 8.
local PLAT_AFUNDA     = 4
local PLAT_AF_VEL     = 0.5

-- BALANCA: catapulta em dois tempos.
-- Impacto -> lado pisado afunda, outro sobe, peso voa 80px.
-- Peso cai de volta -> plataformas trocam de lugar e quem estiver
-- em cima e lancado. Sem ninguem em cima, so trocam de lugar.
local BAL_OFF        = 20    -- deslocamento SIMETRICO: um desce 20, outro sobe 20
local BAL_PESO_ALTO  = 80    -- altura do voo do peso
local BAL_GRAV_PESO  = 0.15
local BAL_TEMPO_HOLD = 4    -- segura a posicao trocada p/ o Sonic pousar (0,75s)
local BAL_LANC_MIN   = 7
local BAL_LANC_MAX   = 13
local BAL_F_PESO     = 1.6   -- ganho sobre a velocidade de impacto do PESO
local BAL_F_SONIC    = 0.4   -- parcela do impacto original do Sonic
local BAL_VEL_OFF    = 2.5   -- px/frame indo ao alvo
local BAL_VEL_VOLTA  = 0.5   -- px/frame voltando ao repouso

local function aproxima(valor, alvo, passo)
    if valor < alvo then return math.min(alvo, valor + passo) end
    if valor > alvo then return math.max(alvo, valor - passo) end
    return valor
end

local MONITOR_FRAME = {
    monitor_anel = 2,
    monitor_sapato_rapido = 3,
    monitor_vida = 4,
    monitor_escudo = 5,
    monitor_invenc = 6,
    monitor_salva = 7,
    monitor_cont = 8,
}

local PLACA_RESULTADO_FRAME = {
    placa_normal   = 1,
    placa_especial = 2,
    placa_aneis    = 3,
    placa_vida     = 4,
    placa_chefe    = 5,
}

local monitor_estatica_fase = 1
local monitor_estatica_timer = 0
local MONITOR_ESTATICA_CADENCIA = 30
local anim_timer = 0

local cache_monitor = {}
local cache_placa = {}

local function sprite_monitor(frame, heroi)
    heroi = heroi or "sonic"
    local k = heroi .. ":" .. frame
    local s = cache_monitor[k]
    if s then return s end
    -- f4/f5/f6 = vida, escudo, invenc: arte por heroi
    if heroi ~= "sonic" and frame >= 4 and frame <= 6 then
        s = Sprites.asset("herois/" .. heroi .. "/obj_ui/monitores/f" .. frame)
    end
    if not s then s = Sprites.sprite("monitor_anel", frame) end
    if s then cache_monitor[k] = s end
    return s
end

local function sprite_placa(estado, frame, heroi)
    heroi = heroi or "sonic"
    local kk = heroi .. ":" .. estado
    local cache_estado = cache_placa[kk]
    if not cache_estado then
        cache_estado = {}
        cache_placa[kk] = cache_estado
    end
    local s = cache_estado[frame]
    if s then return s end
    if heroi ~= "sonic" then
        local base = "herois/" .. heroi .. "/obj_ui/placa_final/"
        if estado == "placa_vida" then
            -- resultado 4 = rosto do heroi (1UP)
            s = Sprites.asset(base .. "placa_" .. heroi)
        elseif estado == "placa_giro" and (frame == 1 or frame == 3) then
            s = Sprites.asset(base .. "girar/f" .. frame)
        end
    end
    if not s then s = Sprites.sprite(estado, frame) end
    if s then cache_estado[frame] = s end
    return s
end

-- Resolve um caminho de asset dentro de _G.Sprites.
-- Aceita tanto chave plana ("a/b/c") quanto aninhada (Sprites.a.b.c).
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

-- ============================================================
-- PONTE FALSA (Bridge Zone)
-- Estados: parada → tremendo (60f) → caindo → sumiu
-- ============================================================
local PONTES_FALSAS = {}

local PONTE_TREMER_FRAMES = 60

local PONTE_Y_SUMIU       = 400

local SPRITE_PONTE_PATH = "fases/obj_fases/BZ/ponte-W16xH8"
local sprite_ponte_cache = nil

local function obter_sprite_ponte()
    if sprite_ponte_cache ~= nil then return sprite_ponte_cache end
    sprite_ponte_cache = resolver_asset(SPRITE_PONTE_PATH) or false
    return sprite_ponte_cache
end

local function init_pontes_falsas(dados)
    PONTES_FALSAS = {}
    local Terreno = require("sistemas.terreno")
    Terreno.limpar_suportes_dinamicos()
    local lista = dados and dados.ponte_falsa or {}
    for i, p in ipairs(lista) do
        local ponte = {
            x = p.x, y = p.y,
            y_inicial = p.y,
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
    if not player or player.morto then return false end
    local px0, py0, px1, py1 = PlayerSys.get_hitbox(player)
    local pcx = (px0 + px1) * 0.5
    if pcx < ponte.x or pcx > ponte.x + ponte.w then return false end
    -- pé (py1) tem que estar no topo da ponte (±6px de tolerância)
    if math.abs(py1 - ponte.y) > 6 then return false end
    if (player.velocidade_y or 0) < 0 then return false end
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
            if ponte.y - ponte.y_inicial > PONTE_Y_SUMIU then
                ponte.estado = "sumiu"
            end
        end
    end
end

local function desenhar_pontes_falsas(cam_x, cam_y)
    local spr = obter_sprite_ponte()
    if not spr then return end
    for _, ponte in ipairs(PONTES_FALSAS) do
        if ponte.estado ~= "sumiu" then
            local dx = math.floor(ponte.x - cam_x + ponte.dx_draw)
            local dy = math.floor(ponte.y - cam_y + ponte.dy_draw)
            local cols = math.max(1, math.ceil(ponte.w / 16))
            for c = 0, cols - 1 do
                ui.spr(spr, dx + c * 16, dy)
            end
        end
    end
end

-- ============================================================
-- CELA / CÁPSULA PÓS-CHEFE
-- ============================================================
local CELA_TW,   CELA_TH,   CELA_COLS   = 34, 64, 4
local ANIM_TW,   ANIM_TH,   ANIM_COLS   = 18, 16, 4
local COELHO_TW, COELHO_TH, COELHO_COLS = 16, 24, 2

local CELA_TEMPO_ABRINDO1 = 60
local CELA_TEMPO_BOTAO    = 30
local CELA_TEMPO_EXPLOSAO = 90
local CELA_BOTAO_DESCIDA  = 8
local CELA_ANIMAIS_TOTAL  = 11    -- 7 tipos garantidos + 4 repetidos
local ANIMAL_TIPOS        = 7     -- 6 do animais-W18xH16 + o coelho
local ANIMAL_VIDA         = 900
local ANIMAL_GRAVIDADE    = 0.25
local ANIMAL_CADENCIA     = 8
local ANIMAL_RAIO         = 165   -- alcance total a partir do centro da cela
local ANIMAL_FAIXA        = 18    -- cada animal patrulha ±18 em volta da sua faixa
local ANIMAL_VX_SAIDA     = 2.2   -- velocidade para se afastar do meio
local ANIMAL_VX_CALMO     = 1.0   -- passo depois de chegar na faixa
local CELA_TEMPO_ANIMAIS  = 180

local BGM_VITORIA_CELA = nil

local IMG_CELA, IMG_ANIMAIS, IMG_COELHO = nil, nil, nil
local cela_sprites_buscados = false

local cela_anim = {
    fase = "fechada",
    timer = 0,
    botao_dy = 0,
    animais = {},
    bgm_tocada = false,
    finalizado = false,
}

local function carregar_sprites_cela(heroi)
    if cela_sprites_buscados then return end
    cela_sprites_buscados = true
    IMG_CELA = nil
    if heroi and heroi ~= "sonic" then
        local base = "herois/" .. heroi .. "/obj_ui/"
        -- nome inconsistente entre herois: tenta os dois formatos
        IMG_CELA = Sprites.asset(base .. "cela_" .. heroi)
                or Sprites.asset(base .. "cela")
                or Sprites.asset(base .. "cela-W34xH64")
    end
    if not IMG_CELA then IMG_CELA = UI.buscar_sprite("cela-W34xH64") end
    IMG_ANIMAIS = UI.buscar_sprite("animais-W18xH16")
    IMG_COELHO  = UI.buscar_sprite("coelho-W16xH24")
end

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
    local cx = c.x + c.w / 2
    local base_y = c.y

    if cela_anim.fase == "fechada" then return end

    cela_anim.timer = cela_anim.timer + 1

    if cela_anim.fase == "abrindo1" then
        if cela_anim.timer >= CELA_TEMPO_ABRINDO1 then
            cela_anim.fase  = "abrindo2"
            cela_anim.timer = 0
        end

    elseif cela_anim.fase == "abrindo2" then
        local t = math.min(1, cela_anim.timer / CELA_TEMPO_BOTAO)
        cela_anim.botao_dy = CELA_BOTAO_DESCIDA * t
        if cela_anim.timer >= CELA_TEMPO_BOTAO then
            cela_anim.fase  = "explosoes"
            cela_anim.timer = 0
        end

    elseif cela_anim.fase == "explosoes" then
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
        -- Capsula quebrada (tile 3): saem 11 animais do MEIO da cela.
        -- Os 7 primeiros garantem um de cada tipo (inclui o coelho);
        -- os 4 restantes repetem tipo sorteado. Cada um recebe uma
        -- faixa de patrulha propria, espalhada em leque, para nao
        -- voltarem a se juntar no mesmo ponto.
        local total = CELA_ANIMAIS_TOTAL
        local util  = ANIMAL_RAIO - ANIMAL_FAIXA
        for i = 1, total do
            local tipo = (i <= ANIMAL_TIPOS) and i or math.random(1, ANIMAL_TIPOS)
            local frac = (total > 1) and ((i - 1) / (total - 1)) or 0.5
            local centro = cx - util + frac * (util * 2)
            local lado = (centro >= cx) and 1 or -1
            table.insert(cela_anim.animais, {
                tipo    = tipo,
                x       = cx + math.random(-4, 4),
                y       = base_y - 32,
                vx      = lado * ANIMAL_VX_SAIDA,
                vy      = -(2.5 + math.random() * 1.5),
                lim_esq = centro - ANIMAL_FAIXA,
                lim_dir = centro + ANIMAL_FAIXA,
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
        if cela_anim.timer >= CELA_TEMPO_ANIMAIS then
            cela_anim.fase = "fim"
            Objetos._finalizar_ato_cela()
        end
    end

    local lim_esq = cx - ANIMAL_RAIO
    local lim_dir = cx + ANIMAL_RAIO
    for i = #cela_anim.animais, 1, -1 do
        local a = cela_anim.animais[i]
        local th = (a.tipo == 7) and COELHO_TH or ANIM_TH
        a.vy = a.vy + ANIMAL_GRAVIDADE
        a.x  = a.x + a.vx
        local le = a.lim_esq or lim_esq
        local ld = a.lim_dir or lim_dir
        if a.x < le then
            a.x = le; a.vx = math.abs(a.vx)
        elseif a.x > ld then
            a.x = ld; a.vx = -math.abs(a.vx)
        elseif math.abs(a.vx) > ANIMAL_VX_CALMO then
            -- ja chegou na faixa dele: troca o arranque por um pulo calmo
            a.vx = (a.vx > 0) and ANIMAL_VX_CALMO or -ANIMAL_VX_CALMO
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
    carregar_sprites_cela(State.player and State.player.heroi)

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

function Objetos.limpar_checkpoint()
    checkpoint_mem = nil
    checkpoint_pendente = false
    State.checkpoint_ativo = false
    State.checkpoint_x = nil
    State.checkpoint_y = nil
end

function Objetos._acionar_botao_cela()
    if cela_anim.fase ~= "fechada" then return end
    State.chefe_liberou_animais = true
    cela_anim.fase  = "abrindo1"
    cela_anim.timer = 0
    State.cela_cutscene = true
    State.cela_foco_x   = Objetos.cela.x + Objetos.cela.w / 2
    State.cela_foco_y   = Objetos.cela.y - CELA_TH / 2
end

function Objetos.resolver_cela(player)
    if not (State.chefe_derrotado and Objetos.cela) then return end
    if not player or player.morto then return end

    local x0, y0, x1, y1 = caixa_cela()
    local px0, py0, px1, py1 = PlayerSys.get_hitbox(player)
    if not (px0 < x1 and px1 > x0 and py0 < y1 and py1 > y0) then return end

    local ctx = PlayerSys.contexto_ataque(player)
    local overlap_x = math.min(px1, x1) - math.max(px0, x0)
    local overlap_y = math.min(py1, y1) - math.max(py0, y0)

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
        player.y = y0 - PlayerSys.COLISAO_BASE_Y
        player.velocidade_y = 0
        player.no_chao      = true
        player.esta_pulando = false
        if ctx.caindo and ctx.pes_prev <= y0 + 8 then
            Objetos._acionar_botao_cela()
        end
    else
        player.y = y1 - PlayerSys.COLISAO_TOPO_Y
        player.velocidade_y = 0
    end
end

local PLATAFORMA_ASSET = {
    bz = "fases/obj_fases/BZ/plataforma-W32xH16",
}
local plataforma_sprite_cache = {}

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

local ASSET_BZ = {
    ponte   = "fases/obj_fases/BZ/ponte-W16xH8",
    balanca = "fases/obj_fases/BZ/balanca-W24xH16",
    peso    = "fases/obj_fases/BZ/peso-W16xH16",
}
local cache_asset_bz = {}

local function sprite_bz(chave)
    local caminho = ASSET_BZ[chave]
    if not caminho then return nil end
    local s = cache_asset_bz[chave]
    if s == nil then
        s = resolver_asset(caminho) or false
        cache_asset_bz[chave] = s
    end
    return s or nil
end

function Objetos.init(dados_terreno)
    Objetos.lista = {}
    Objetos.outros = {}
    Objetos.plataformas = {}
    Objetos.pontes = {}
    Objetos.balancas = {}
    Objetos.balancas_lados = {}
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
            local yi = p.y_inicial or p.y
            table.insert(Objetos.plataformas, {
                x = p.x, y = p.y,
                largura = p.largura, altura = p.altura,
                x_inicial = p.x_inicial,
                y_inicial = yi,
                y_base = yi,
                amplitude = p.amplitude or 64,
                velocidade = p.velocidade or 1.0,
                direcao = p.direcao or 1,
                modo = p.modo or "horizontal",
                afundamento = 0,
                delta_x = 0, delta_y = 0,
            })
        end
    end

    if dados_terreno.pontes then
        for _, t in ipairs(dados_terreno.pontes) do
            table.insert(Objetos.pontes, {
                x = t.x, y = t.y,
                largura = t.largura or 16,
                altura = t.altura or 8,
                estado = "intacta",   -- intacta > pisada > caindo > gone
                timer = 0, vy = 0, tremor = 0,
                delta_x = 0, delta_y = 0,
                eh_tabua = true,
            })
        end
    end

    if dados_terreno.balancas then
        for _, b in ipairs(dados_terreno.balancas) do
            local g = {
                grupo = b.grupo,
                estado = "repouso",   -- repouso > peso_no_ar > troca > retorno
                off_esq = 0, off_dir = 0,
                alvo_esq = 0, alvo_dir = 0,
                peso_dy = 0, peso_vy = 0,
                timer = 0, energia = 0,
                peso_x = b.peso_x, peso_y = b.peso_y,
                peso_w = b.peso_w or 16, peso_h = b.peso_h or 16,
            }
            g.esq = {
                x = b.x_esq, y = b.y_esq, y_base = b.y_esq,
                largura = b.largura, altura = b.altura,
                delta_x = 0, delta_y = 0,
                eh_balanca = true, impacto = 0,
            }
            g.dir = {
                x = b.x_dir, y = b.y_dir, y_base = b.y_dir,
                largura = b.largura, altura = b.altura,
                delta_x = 0, delta_y = 0,
                eh_balanca = true, impacto = 0,
            }
            table.insert(Objetos.balancas, g)
            table.insert(Objetos.balancas_lados, g.esq)
            table.insert(Objetos.balancas_lados, g.dir)
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

        -- Checkpoint do monitor_salva: mantem entre mortes do mesmo ato.
    if checkpoint_mem and (checkpoint_mem.stage ~= State.stage_atual
                        or checkpoint_mem.ato ~= State.ato_atual) then
        checkpoint_mem = nil
    end
    if checkpoint_mem then
        for _, o in ipairs(Objetos.outros) do
            if o.tipo == 'monitores'
               and (o.nome == 'monitor_salva' or o.nome == 'monitor_seta')
               and math.abs((o.x + o.w / 2) - checkpoint_mem.mx) < 4 then
                o.coletado = true
            end
        end
        checkpoint_pendente = true
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

    -- Aplicado AQUI (e nao no init) porque o resetar_estado_fase ainda
    -- pode reescrever o spawn depois do init. Este update roda antes do
    -- Player.update e antes do draw, entao nao ha frame errado na tela.
    if checkpoint_pendente then
        checkpoint_pendente = false
        if checkpoint_mem then
            State.checkpoint_ativo = true
            State.checkpoint_x = checkpoint_mem.x
            State.checkpoint_y = checkpoint_mem.y
            for i, p in ipairs(State.players or { player }) do
                local sx = checkpoint_mem.mx - CHECKPOINT_RECUO + (i - 1) * 20
                local chao = Mapa.altura_suporte(sx, checkpoint_mem.y + 32, 128)
                local sy = chao and (chao - 32) or checkpoint_mem.y
                p.spawn_x, p.spawn_y = sx, sy
                p.x, p.y = sx, sy
                p.velocidade_x, p.velocidade_y = 0, 0
            end
        end
    end

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
                -- COOP: qualquer player pega, e o folego enche SO dele.
                for _, p in ipairs(State.players or { player }) do
                    if not b.coletada and not p.morto and not p.coop_esperando then
                        local px0, py0, px1, py1 = PlayerSys.get_hitbox(p)
                        if px0 < b.x + 8 and px1 > b.x - 8 and py0 < b.y + 8 and py1 > b.y - 8 then
                            b.coletada = true
                            b.timer_coleta = 15
                            local oxi = p.oxigenio
                            if oxi then oxi.tempo_restante = oxi.tempo_maximo end
                            Animacao.iniciar(p, "ar", 30)
                        end
                    end
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
        local antigo_x, antigo_y = pl.x, pl.y
        local ocupada = (player.plataforma_atual == pl)

        -- leve descida sob o peso do Sonic, volta suave ao sair
        local alvo_af = ocupada and PLAT_AFUNDA or 0
        if pl.afundamento < alvo_af then
            pl.afundamento = math.min(alvo_af, pl.afundamento + PLAT_AF_VEL)
        elseif pl.afundamento > alvo_af then
            pl.afundamento = math.max(alvo_af, pl.afundamento - PLAT_AF_VEL)
        end

        if pl.modo == "vertical" then
            pl.y_base = pl.y_base + pl.velocidade * pl.direcao
            if pl.amplitude > 0 then
                if pl.y_base > pl.y_inicial + pl.amplitude then pl.direcao = -1
                elseif pl.y_base < pl.y_inicial - pl.amplitude then pl.direcao = 1 end
            end
            pl.x = pl.x_inicial
            pl.y = pl.y_base + pl.afundamento
        else
            pl.x = pl.x + pl.velocidade * pl.direcao
            if pl.amplitude > 0 then
                if pl.x > pl.x_inicial + pl.amplitude then pl.direcao = -1
                elseif pl.x < pl.x_inicial - pl.amplitude then pl.direcao = 1 end
            end
            pl.y = pl.y_inicial + pl.afundamento
        end

        pl.delta_x = pl.x - antigo_x
        pl.delta_y = pl.y - antigo_y

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

    -- PONTES: o gatilho vem de graca do plataforma_atual que o
    -- atualizar_vertical ja seta ao pousar. Sem colisao nova.
    local limite_queda = (Mapa.altura or 1024) + 64
    for _, tb in ipairs(Objetos.pontes) do
        if tb.estado == "intacta" then
            if player.plataforma_atual == tb then
                tb.estado = "pisada"
                tb.timer = 0
            end
        elseif tb.estado == "pisada" then
            tb.timer = tb.timer + 1
            tb.tremor = (tb.timer % 4 < 2) and PONTE_TREMOR or -PONTE_TREMOR
            if tb.timer >= PONTE_ATRASO then
                tb.estado = "caindo"
                tb.vy = 0
                tb.tremor = 0
                -- MANTEM o Sonic apoiado na tabua. O carry passa a seguir
                -- delta_y sem teto, e o pouso aceita estado "caindo".
                -- Assim ele fica estavel e consegue pular para outra plataforma.
            end
        elseif tb.estado == "caindo" then
            tb.vy = math.min(tb.vy + PONTE_GRAVIDADE, PONTE_VY_MAX)
            tb.y = tb.y + tb.vy
            tb.delta_y = tb.vy
            if tb.y > limite_queda then
                tb.estado = "gone"
                tb.delta_y = 0
                if player.plataforma_atual == tb then
                    player.plataforma_atual = nil
                    player.no_chao = false
                end
            end
        end
    end

    -- BALANCAS: o gatilho vem do plataforma_atual + impacto que o
    -- atualizar_vertical grava ao pousar. O peso e so visual e nunca
    -- e destruido/empurrado: a posicao dele e derivada, nao fisica.
    for _, b in ipairs(Objetos.balancas) do
        local lado = nil
        if player.plataforma_atual == b.esq then lado = b.esq
        elseif player.plataforma_atual == b.dir then lado = b.dir end

        if b.estado == "repouso" then
            if lado and (lado.impacto or 0) > 1 then
                b.energia = lado.impacto
                lado.impacto = 0
                b.alvo_esq = (lado == b.esq) and BAL_OFF or -BAL_OFF
                b.alvo_dir = (lado == b.dir) and BAL_OFF or -BAL_OFF
                b.peso_vy = -math.sqrt(2 * BAL_GRAV_PESO * BAL_PESO_ALTO)
                b.peso_dy = 0
                b.timer = 0
                b.estado = "peso_no_ar"
            end

        elseif b.estado == "peso_no_ar" then
            b.peso_vy = b.peso_vy + BAL_GRAV_PESO
            b.peso_dy = b.peso_dy + b.peso_vy
            if b.peso_dy >= 0 and b.peso_vy > 0 then
                -- velocidade REAL do peso ao bater: sai da altura do voo,
                -- entao o lancamento e coerente com o impacto dele
                local v_peso = b.peso_vy
                b.peso_dy = 0
                b.peso_vy = 0
                b.alvo_esq, b.alvo_dir = -b.alvo_esq, -b.alvo_dir
                if lado then
                    local lanc = v_peso * BAL_F_PESO + b.energia * BAL_F_SONIC
                    lanc = math.max(BAL_LANC_MIN, math.min(BAL_LANC_MAX, lanc))
                    player.velocidade_y = -lanc
                    player.no_chao = false
                    player.plataforma_atual = nil
                    player.pendulo_atual = nil
                    player.pulou_mola = true
                    lado.impacto = 0
                end
                b.timer = 0
                b.estado = "troca"
            end

        elseif b.estado == "troca" then
            -- PAUSA na posicao trocada: sem isto o Sonic nao tinha
            -- tempo de pousar no lado que ficou alto.
            if b.off_esq == b.alvo_esq and b.off_dir == b.alvo_dir then
                b.timer = b.timer + 1
                if b.timer >= BAL_TEMPO_HOLD then
                    b.alvo_esq, b.alvo_dir = 0, 0
                    b.estado = "retorno"
                end
            end

        elseif b.estado == "retorno" then
            if b.off_esq == 0 and b.off_dir == 0 then
                -- limpa impactos acumulados durante a pausa, senao um
                -- pouso velho dispararia outra catapulta na hora
                b.esq.impacto = 0
                b.dir.impacto = 0
                b.estado = "repouso"
            end
        end

        local vel = (b.estado == "retorno") and BAL_VEL_VOLTA or BAL_VEL_OFF
        b.off_esq = aproxima(b.off_esq, b.alvo_esq, vel)
        b.off_dir = aproxima(b.off_dir, b.alvo_dir, vel)

        local ny_esq = b.esq.y_base + b.off_esq
        local ny_dir = b.dir.y_base + b.off_dir
        b.esq.delta_y = ny_esq - b.esq.y
        b.dir.delta_y = ny_dir - b.dir.y
        b.esq.y = ny_esq
        b.dir.y = ny_dir
    end

    for _, e in ipairs(Objetos.esmeraldas) do
        if not e.coletado then
            for _, p in ipairs(State.players or { player }) do
                if not e.coletado and not p.morto and not p.coop_esperando then
                    local px0, py0, px1, py1 = PlayerSys.get_hitbox(p)
                    if px0 < e.x + 8 and px1 > e.x - 8 and py0 < e.y + 8 and py1 > e.y - 8 then
                        e.coletado = true
                        State.esmeraldas_coletadas = (State.esmeraldas_coletadas or 0) + 1
                        State.esmeralda_no_ato = true
                        State.pontuacao = State.pontuacao + 1000

                        -- 20 aneis no pool, com rollover de 100 -> vida
                        State.inventory.aneis = (State.inventory.aneis or 0) + 20
                        while State.inventory.aneis >= 100 do
                            State.inventory.aneis = State.inventory.aneis - 100
                            State.vidas = State.vidas + 1
                        end
                        State.vidas = State.vidas + 1

                        -- invencibilidade compartilhada (buffs do grupo)
                        for _, q in ipairs(State.players or { player }) do
                            local b = q.buffs or State.buffs
                            if b then b.invencivel = 7 * 60 end
                        end
                    end
                end
            end
        end
    end

    for _, o in ipairs(Objetos.outros) do
        if o.tipo == 'venceu' and not o.coletado then
            -- COOP: qualquer player dispara. Guarda o heroi de quem
            -- cruzou primeiro para a placa usar a arte dele.
            for _, p in ipairs(State.players or { player }) do
                if not o.coletado and not p.morto and not p.coop_esperando then
                    local px0, py0, px1, py1 = PlayerSys.get_hitbox(p)
                    if px0 < o.x + o.w and px1 > o.x and py0 < o.y + o.h and py1 > o.y then
                        o.coletado = true
                        State.placa.heroi = p.heroi
                        Objetos._iniciar_placa_final(o, State)
                    end
                end
            end
        elseif o.tipo == 'monitores' and o.caindo and not o.coletado then
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

function Objetos._aplicar_monitor(nome, state_ref, x, y, quem)
    local Inimigos = require("sistemas.inimigos")
    if Inimigos.criar_explosao then Inimigos.criar_explosao(x, y) end
    -- COOP: o efeito vai para QUEM quebrou, nao para o grupo.
    local alvo = quem or state_ref.player
    local buffs = (alvo and alvo.buffs) or state_ref.buffs

    if nome == 'monitor_anel' then
        state_ref.inventory.aneis = state_ref.inventory.aneis + 10
        while state_ref.inventory.aneis >= 100 do
            state_ref.inventory.aneis = state_ref.inventory.aneis - 100
            state_ref.vidas = state_ref.vidas + 1
        end
    elseif nome == 'monitor_sapato_rapido' then
        buffs.velocidade_extra = 20 * 60
    elseif nome == 'monitor_vida' then
        state_ref.vidas = state_ref.vidas + 1
    elseif nome == 'monitor_escudo' then
        state_ref.buffs.escudo = true
    elseif nome == 'monitor_invenc' then
        state_ref.buffs.invencivel = 7 * 60
    elseif nome == 'monitor_salva' or nome == 'monitor_seta' then
        -- COOP: o checkpoint vale para O GRUPO, nao so para quem quebrou.
        local quem = alvo or state_ref.player
        checkpoint_mem = {
            x = quem.x, y = quem.y, mx = x,
            stage = state_ref.stage_atual, ato = state_ref.ato_atual,
        }
        state_ref.checkpoint_ativo = true
        state_ref.checkpoint_x = quem.x
        state_ref.checkpoint_y = quem.y
        for i, p in ipairs(state_ref.players or { quem }) do
            p.spawn_x = x - CHECKPOINT_RECUO + (i - 1) * 20
            p.spawn_y = quem.y
        end
    elseif nome == 'monitor_cont' then
        state_ref.continuacoes = (state_ref.continuacoes or 0) + 1
    end
end

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
    -- Reusa a cutscene de fim de ato da capsula: o game.lua ja troca o
    -- input por auto-direita e o camera.lua ja trava o foco nesses flags.
    -- Aqui o foco e a placa; o Sonic corre para fora da tela enquanto
    -- ela sobe, gira e desce, ate puxar a vitoria.
    state_ref.cela_cutscene = true
    state_ref.cela_foco_x   = o.x + (o.w or 0) / 2
    state_ref.cela_foco_y   = o.y + (o.h or 32) / 2
    local aneis = Objetos._calcular_bonus_ato(state_ref)
    if state_ref.stage_e_especial and state_ref.stage_e_especial() then
        state_ref.placa.resultado = "placa_normal"
        return
    end
    local stage = state_ref.stages[state_ref.stage_atual]
    local sigla = (stage and stage.sigla) or ""
    if aneis >= 50 and aneis <= 99 and ZONAS_COM_ESP[sigla] then
        state_ref.placa.resultado = "placa_especial"
    elseif aneis >= 40 and aneis <= 49 then
        state_ref.placa.resultado = "placa_vida"
        state_ref.vidas = state_ref.vidas + 1
    elseif aneis > 0 and aneis % 10 == 0 then
        state_ref.placa.resultado = "placa_aneis"
        state_ref.inventory.aneis = state_ref.inventory.aneis + 10
    else
        state_ref.placa.resultado = "placa_chefe"
    end
end

function Objetos.draw(cam_x, cam_y)
local heroi = (State.player and State.player.heroi) or "sonic"
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

        local spr_ponte = sprite_bz("ponte")
    for _, tb in ipairs(Objetos.pontes) do
        if tb.estado ~= "gone" then
            local dx = math.floor(tb.x - cam_x)
            local dy = math.floor(tb.y - cam_y + tb.tremor)
            if spr_ponte then
                ui.spr(spr_ponte, dx, dy, false, false)
            else
                ui.rectfill(dx, dy, dx + tb.largura, dy + tb.altura, 12)
            end
        end
    end

    local spr_bal  = sprite_bz("balanca")
    local spr_peso = sprite_bz("peso")
    for _, s in ipairs(Objetos.balancas_lados) do
        local dx = math.floor(s.x - cam_x)
        local dy = math.floor(s.y - cam_y)
        if spr_bal then
            ui.spr(spr_bal, dx, dy, false, false)
        else
            ui.rectfill(dx, dy, dx + s.largura, dy + s.altura, 12)
        end
    end
    for _, b in ipairs(Objetos.balancas) do
        -- peso ancorado na direita: acompanha off_dir + o voo peso_dy
        local pcx = b.peso_x + b.peso_w / 2
        local px = math.floor(pcx - 8 - cam_x)
        local py = math.floor(b.peso_y + b.off_dir + b.peso_dy - cam_y)
        if spr_peso then
            ui.spr(spr_peso, px, py, false, false)
        else
            ui.rectfill(px, py, px + 16, py + 16, 6)
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

    monitor_estatica_timer = monitor_estatica_timer + 1
    if monitor_estatica_timer >= MONITOR_ESTATICA_CADENCIA then
        monitor_estatica_timer = 0
        monitor_estatica_fase = (monitor_estatica_fase == 1) and 2 or 1
    end

    for _, o in ipairs(Objetos.outros) do
        if o.tipo == 'monitores' and not o.coletado then
            local f_efeito = MONITOR_FRAME[o.nome] or 1
            local f = (monitor_estatica_fase == 2) and f_efeito or 1
            local sprite = sprite_monitor(f, heroi)
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
            local heroi_placa = (State.placa and State.placa.heroi) or heroi
            local sprite = sprite_placa(sprite_estado, frame_use, heroi_placa)
            if sprite then ui.spr(sprite, math.floor(px - cam_x), math.floor(py - cam_y), false, false) end
        end
    end

    local piscar = math.floor(anim_timer / 10) % 2 == 0
    -- COOP: a esmeralda da fase usa sempre o heroi do PLAYER 1.
    local heroi_esm = (State.player and State.player.heroi) or heroi
    local spr_esm = UI.sprite_ui_heroi(heroi_esm, "esmeralda")
    for _, e in ipairs(Objetos.esmeraldas) do
        if not e.coletado and piscar then
            local ex = math.floor(e.x - cam_x - 8)
            local ey = math.floor(e.y - cam_y - 8)
            if spr_esm then
                ui.spr(spr_esm,
                    ex + math.floor((16 - (spr_esm.width or 16)) / 2),
                    ey + math.floor((16 - (spr_esm.height or 16)) / 2), false, false)
            else
                UI.desenhar_tile_ui(15, ex, ey)
            end
        end
    end
end

return Objetos
