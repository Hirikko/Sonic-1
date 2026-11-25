local UI = {}
local BTN = require("btn")
local Sprites = require("sistemas.sprites")
local Timer = require("sistemas.timer")

local ui_frame = 0
-- Guarda de recorte: quando ativa, os helpers de tile restauram ESTE
-- clip em vez de limpar para a tela cheia. Usado pelo preview de
-- brilho/contraste, que desenha a fase dentro de uma janela.
local clip_guard = nil

function UI.set_clip_guard(x, y, w, h)
    if x then clip_guard = { x, y, w, h } else clip_guard = nil end
end

local function fechar_clip()
    if clip_guard then
        ui.clip(clip_guard[1], clip_guard[2], clip_guard[3], clip_guard[4])
    else
        ui.clip()
    end
end
local titulo_frame = 1
local titulo_timer = 0
local TITULO_CADENCIA = 18
local botao_frame = 1
local botao_timer = 0
local BOTAO_CADENCIA = 30
local preview_anim_timer = 0

-- =====================================================================
-- AJUSTES FINOS DA TRILHA DO PREVIEW
-- =====================================================================
local GH1_TRILHA_OFFSET_X = 40
local GH1_TRILHA_OFFSET_Y = 90
local GH2_TRILHA_OFFSET_X = 34
local GH2_TRILHA_OFFSET_Y = 66
-- BZ1: tile 2 da trilha-ilha-41x35 (sx = 82).
local BZ1_TRILHA_OFFSET_X = 57
local BZ1_TRILHA_OFFSET_Y = 67
local BZ1_TILE_INDEX = 2
local TST1_TRILHA_OFFSET_X = 13
local TST1_TRILHA_OFFSET_Y = 13
local TST1_TILE_INDEX = 5

-- =====================================================================
-- PARÂMETROS DA TELA DE VITÓRIA
-- =====================================================================
local LARGURA_BRANCA = 14
local ALTURA_BRANCA = 17
local MARGEM_X_BRANCA = 0
local MARGEM_Y_BRANCA = 0

local POS_X_ATO = 286
local POS_Y_ATO = 66
local DISTANCIA_ATO_NUMERO = 25
local OFFSET_Y_NUMERO = -20
-- =====================================================================

local function get_indice_cor(cor)
    if _G.Palette then
        for i, v in pairs(_G.Palette) do
            if v == cor then return i - 1 end
        end
        for i, v in pairs(_G.Palette) do
            if v == 0x7EA0 then return i - 1 end
        end
    end
    return 4
end

local FONTE_UI_16 = nil
local FONTE_BRANCA = nil
local FONTE_AMARELA = nil
local FONTE_MAPA = nil
local IMG_MAPA = nil
local IMG_TRILHA_GH = nil
local IMG_TRILHA_TST = nil
local FONTES_CARREGADAS = false

local function buscar_sprite(nome)
    local r = _G.Sprites
    if not r then return nil end
    local sufixos = { "", ".png" }
    local prefixos = { "", "assets/", "assets/ui/", "assets/mapa/", "assets/objetos/cela/", "objetos/cela/" }

    for _, prefixo in ipairs(prefixos) do
        for _, sufixo in ipairs(sufixos) do
            local n1 = prefixo .. nome .. sufixo
            if r[n1] then return r[n1] end

            local n2 = prefixo .. string.gsub(nome, "%-", "_") .. sufixo
            if r[n2] then return r[n2] end

            local n3 = prefixo .. string.gsub(nome, "_", "-") .. sufixo
            if r[n3] then return r[n3] end
        end
    end

    if r.ui and r.ui[nome] then return r.ui[nome] end
    if r.mapa and r.mapa[nome] then return r.mapa[nome] end
    if r.assets then
        if r.assets[nome] then return r.assets[nome] end
        if r.assets.ui and r.assets.ui[nome] then return r.assets.ui[nome] end
        if r.assets.mapa and r.assets.mapa[nome] then return r.assets.mapa[nome] end
        if r.assets.objetos and r.assets.objetos.cela then
            local t = r.assets.objetos.cela
            if t[nome] then return t[nome] end
            if t[nome .. ".png"] then return t[nome .. ".png"] end
        end
    end
    if r.objetos and r.objetos.cela then
        local t = r.objetos.cela
        if t[nome] then return t[nome] end
        if t[nome .. ".png"] then return t[nome .. ".png"] end
    end
    return nil
end

local function carregar_fontes()
    if FONTES_CARREGADAS then return end
    FONTES_CARREGADAS = true

    FONTE_UI_16 = buscar_sprite("ui-16x16")
    FONTE_BRANCA = buscar_sprite("fonte-vitoria-14x17")
    FONTE_AMARELA = buscar_sprite("ui-vitoria_10x15")
    FONTE_MAPA = buscar_sprite("fonte-mapa-10x10")
    IMG_MAPA = buscar_sprite("southislandmap")
    IMG_TRILHA_GH = buscar_sprite("trilha-ilha-41x35")
    IMG_TRILHA_TST = buscar_sprite("topo-trilha-33x46")
end

local function get_coord_numero(id)
    if id == 1 then return 0, 0 end
    if id == 2 then return 16, 0 end
    if id == 3 then return 32, 0 end
    if id == 4 then return 48, 0 end
    if id == 5 then return 0, 16 end
    if id == 6 then return 16, 16 end
    if id == 7 then return 32, 16 end
    if id == 8 then return 48, 16 end
    if id == 9 then return 0, 32 end
    if id == 10 then return 16, 32 end
    if id == 11 then return 32, 32 end
    if id == 12 then return 48, 32 end
    if id == 13 then return 0, 48 end
    if id == 14 then return 16, 48 end
    if id == 15 then return 32, 48 end
    if id == 16 then return 48, 48 end
    if id == 17 then return 0, 64 end
    if id == 18 then return 16, 64 end
    if id == 19 then return 32, 64 end
    if id == 20 then return 48, 64 end
    return 0, 0
end

function UI.desenhar_tile_ui(id, x, y)
    carregar_fontes()
    if not FONTE_UI_16 then return end
    local sx, sy = get_coord_numero(id)
    ui.clip(x, y, 16, 16)
    ui.spr(FONTE_UI_16, x - sx, y - sy)
    fechar_clip()
end

function UI.desenhar_parte_ui(sx, sy, w, h, dx, dy)
    carregar_fontes()
    if not FONTE_UI_16 then return end
    ui.clip(dx, dy, w, h)
    ui.spr(FONTE_UI_16, dx - sx, dy - sy)
    fechar_clip()
end

local function desenhar_char_ui(char, x, y)
    local id = nil
    if char == "0" then id = 1
    elseif char == "1" then id = 2
    elseif char == "2" then id = 3
    elseif char == "3" then id = 4
    elseif char == "4" then id = 5
    elseif char == "5" then id = 6
    elseif char == "6" then id = 7
    elseif char == "7" then id = 8
    elseif char == "8" then id = 9
    elseif char == "9" then id = 10
    elseif char == "x" or char == "X" then id = 11
    elseif char == ":" then id = 12
    elseif char == "sonic" then id = 13
    elseif char == "anel" then id = 14
    end
    if id then UI.desenhar_tile_ui(id, x, y) end
end

local function desenhar_texto_ui(texto, x, y, espacamento)
    espacamento = espacamento or 16
    local cx = x
    for i = 1, #texto do
        desenhar_char_ui(texto:sub(i, i), cx, y)
        cx = cx + espacamento
    end
    return cx
end

local COORD_BRANCA = {}
local letras = "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
for i = 1, #letras do
    local char = letras:sub(i, i)
    local col = (i - 1) % 9
    local lin = math.floor((i - 1) / 9)
    COORD_BRANCA[char] = { MARGEM_X_BRANCA + (col * LARGURA_BRANCA), MARGEM_Y_BRANCA + (lin * ALTURA_BRANCA) }
end

local function desenhar_char_branco(char, x, y)
    carregar_fontes()
    if not FONTE_BRANCA or not COORD_BRANCA[char] then return end
    local sx, sy = COORD_BRANCA[char][1], COORD_BRANCA[char][2]
    ui.clip(x, y, LARGURA_BRANCA, ALTURA_BRANCA)
    ui.spr(FONTE_BRANCA, x - sx, y - sy)
    ui.clip()
end

local function desenhar_texto_branco(texto, x, y)
    local cx = x
    for i = 1, #texto do
        local char = texto:sub(i, i)
        if char ~= " " then desenhar_char_branco(char, cx, y) end
        cx = cx + LARGURA_BRANCA
    end
    return cx
end

local BLOCOS = {
    PONTOS   = { largura = 60, altura = 15, sx = 0, sy = 15 },
    BONUS    = { largura = 50, altura = 15, sx = 0, sy = 60 },
    DE       = { largura = 30, altura = 15, sx = 50, sy = 60 },
    TEMPO    = { largura = 50, altura = 15, sx = 0, sy = 30 },
    ANEIS    = { largura = 50, altura = 15, sx = 0, sy = 45 },
}

local function desenhar_bloco(nome, x, y)
    carregar_fontes()
    local b = BLOCOS[nome]
    if not FONTE_AMARELA or not b then return end
    ui.clip(x, y, b.largura, b.altura)
    ui.spr(FONTE_AMARELA, x - b.sx, y - b.sy)
    ui.clip()
end

-- ============================================================
-- UI POR HEROI
-- Sonic nao tem obj_ui: os helpers devolvem nil e o chamador
-- mantem o desenho legado (ui-16x16 / ui-vitoria_10x15).
-- ============================================================
local NOME_HEROI = {
    sonic = "SONIC", tails = "TAILS", knux = "KNUCKLES",
    amy = "AMY", cream = "CREAM", rouge = "ROUGE",
}

local cache_ui_heroi = {}

local function sprite_ui_heroi(heroi, chave)
    heroi = heroi or "sonic"
    if heroi == "sonic" then return nil end
    local k = heroi .. "/" .. chave
    local s = cache_ui_heroi[k]
    if s == nil then
        s = Sprites.asset("herois/" .. heroi .. "/obj_ui/ui/" .. chave) or false
        cache_ui_heroi[k] = s
    end
    return s or nil
end

-- Icone de vida num slot de 16x16, centralizado.
local function desenhar_vida_heroi(heroi, x, y)
    local s = sprite_ui_heroi(heroi, "vida")
    if s then
        ui.spr(s, x + math.floor((16 - (s.width or 16)) / 2),
                  y + math.floor((16 - (s.height or 16)) / 2), false, false)
    else
        desenhar_char_ui("sonic", x, y)
    end
end

-- Icones de vida de TODOS os players do grupo, lado a lado.
-- Devolve o x onde continua o "x NN".
local function desenhar_icones_grupo(state, x, y)
    local lista = state.players
    local n = 0
    -- passo 19 = 16 do icone + 3 de respiro entre players
    if lista then
        for _, p in ipairs(lista) do
            desenhar_vida_heroi(p.heroi, x + n * 19, y)
            n = n + 1
        end
    end
    if n == 0 then
        desenhar_vida_heroi(state.player and state.player.heroi, x, y)
        n = 1
    end
    return x + (n - 1) * 19 + 16
end

local function desenhar_esmeralda_vitoria(x, y, heroi)
    carregar_fontes()
    local s = sprite_ui_heroi(heroi, "esmeralda")
    if s then
        ui.spr(s, x + math.floor((14 - (s.width or 14)) / 2),
                  y + math.floor((16 - (s.height or 16)) / 2), false, false)
        return
    end
    if not FONTE_AMARELA then return end
    ui.clip(x, y, 14, 16)
    ui.spr(FONTE_AMARELA, x - 97, y - 0)
    ui.clip()
end

-- Esmeralda para HUD/fase. Tenta o PNG do heroi; sem ele (Sonic),
-- recorta a do ui-vitoria_10x15. O tile 15 do ui-16x16 NAO e esmeralda,
-- e da familia das estrelas de invencibilidade (16 e 20).
local function desenhar_esmeralda_ui(x, y, heroi)
    carregar_fontes()
    local s = sprite_ui_heroi(heroi, "esmeralda")
    if s then
        ui.spr(s, x + math.floor((16 - (s.width or 16)) / 2),
                  y + math.floor((16 - (s.height or 16)) / 2), false, false)
        return
    end
    if not FONTE_AMARELA then return end
    ui.clip(x + 1, y, 14, 16)
    ui.spr(FONTE_AMARELA, (x + 1) - 97, y)
    fechar_clip()
end

local function desenhar_x_vitoria(x, y)
    carregar_fontes()
    if not FONTE_AMARELA then return end
    ui.clip(x, y, 8, 8)
    ui.spr(FONTE_AMARELA, x - 116, y - 23)
    ui.clip()
end

local function desenhar_estrela_continue(x, y)
    carregar_fontes()
    if not FONTE_AMARELA then return end
    ui.clip(x, y, 9, 12)
    ui.spr(FONTE_AMARELA, x - 99, y - 18)
    ui.clip()
end

local function desenhar_palavra_continuar(x, y)
    carregar_fontes()
    if not FONTE_AMARELA then return end
    ui.clip(x, y, 88, 13)
    ui.spr(FONTE_AMARELA, x - 1, y - 1)
    ui.clip()
end

local function desenhar_ato_e_numero(ato, x, y)
    carregar_fontes()
    if not FONTE_AMARELA then return end

    ui.clip(x, y, 24, 12)
    ui.spr(FONTE_AMARELA, x - 56, y - 49)
    ui.clip()

    local num_x = x + DISTANCIA_ATO_NUMERO
    local num_y = y + OFFSET_Y_NUMERO

    local sx, sy, sw, sh
    if ato == 1 then sx, sy, sw, sh = 86, 44, 6, 30
    elseif ato == 2 then sx, sy, sw, sh = 103, 44, 13, 30
    elseif ato == 3 then sx, sy, sw, sh = 123, 44, 13, 30
    else return end

    ui.clip(num_x, num_y, sw, sh)
    ui.spr(FONTE_AMARELA, num_x - sx, num_y - sy)
    ui.clip()
end

local COORD_MAPA = {
    A = {0,0},   B = {10,0},  C = {20,0},  D = {30,0},  E = {40,0},  F = {50,0},  G = {60,0},  H = {70,0},I = {80,0},
    J = {0,10},  K = {10,10}, L = {20,10}, M = {30,10}, N = {40,10}, O = {50,10}, P = {60,10},Q = {70,10}, R = {80,10},
    S = {0,20},  T = {10,20}, U = {20,20}, V = {30,20}, W = {40,20}, X = {50,20}, Y = {60,20}, Z = {70,20}
}

local function desenhar_texto_mapa(texto, x, y)
    carregar_fontes()
    if not FONTE_MAPA then
        ui.print(texto, x, y, 7)
        return
    end
    local cx = x
    for i = 1, #texto do
        local char = texto:sub(i, i)
        if char == " " then
            cx = cx + 10
        else
            local pos = COORD_MAPA[char]
            if pos then
                ui.clip(cx, y, 10, 10)
                ui.spr(FONTE_MAPA, cx - pos[1], y - pos[2])
                ui.clip()
            end
            cx = cx + 10
        end
    end
end

-- Dígitos do ui-16x16 recortados para caber na célula de 10px do mapa.
-- Ajuste MAPA_NUM_H / MAPA_NUM_DY se o número ficar cortado ou desalinhado.
local MAPA_NUM_W  = 10
local MAPA_NUM_H  = 11
local MAPA_NUM_DY = -1

local function desenhar_numero_mapa(digito, x, y)
    local id = digito + 1          -- ids 1..10 = dígitos 0..9
    if id < 1 or id > 10 then return end
    local sx, sy = get_coord_numero(id)
    UI.desenhar_parte_ui(sx, sy, MAPA_NUM_W, MAPA_NUM_H, x, y + MAPA_NUM_DY)
end

local function desenhar_informacoes(state)
desenhar_char_ui("anel", 10, 10)
local aneis_str = tostring(state.inventory.aneis or 0)
while #aneis_str < 2 do aneis_str = "0" .. aneis_str end
desenhar_texto_ui(aneis_str, 26, 10, 12)

local esp = state.especial
if esp then
    -- SALA ESPECIAL: countdown de 60s no topo, centralizado
    local segs = math.ceil(esp.tempo / 60)
    if segs < 0 then segs = 0 end
    local txt = tostring(segs)
    if #txt < 2 then txt = "0" .. txt end
    local urgente = segs <= 10
    local visivel = (not urgente) or (math.floor(ui_frame / 8) % 2 == 0)
    local passo = 14
    local x0 = 240 - (#txt * passo) / 2
    if visivel then desenhar_texto_ui(txt, x0, 8, passo) end
    local bw, bh = 120, 3
    local bx, by = 240 - bw / 2, 28
    ui.rectfill(bx, by, bx + bw, by + bh, 12)
    local total = state.SP_TEMPO or (60 * 60)
    local frac = esp.tempo / total
    if frac < 0 then frac = 0 end
    if frac > 1 then frac = 1 end
    local fw = math.floor(bw * frac)
    if fw > 0 then
        ui.rectfill(bx, by, bx + fw, by + bh, urgente and 21 or 6)
    end
else
    local time_str = string.format("%d:%02d", math.floor(Timer.segundos / 60), Timer.segundos % 60)
    desenhar_texto_ui(time_str, 10, 30, 12)
end

local cx_vidas = desenhar_icones_grupo(state, 10, 230)
desenhar_char_ui("x", cx_vidas, 230)
desenhar_texto_ui(tostring(state.vidas or 0), cx_vidas + 16, 230, 12)
end

local function desenhar_vitoria(state)
    local cor_fundo = get_indice_cor(0x7DE0)
    ui.rectfill(0, 0, 480, 270, cor_fundo)

    local heroi_v = (state.player and state.player.heroi) or "sonic"
    local grupo = state.players
    local em_coop = grupo and #grupo > 1
    local t1
    if em_coop then
        local nomes = {}
        for _, p in ipairs(grupo) do
            nomes[#nomes + 1] = NOME_HEROI[p.heroi or "sonic"] or "SONIC"
        end
        t1 = table.concat(nomes, " E ")
    else
        t1 = NOME_HEROI[heroi_v] or "SONIC"
    end
    desenhar_texto_branco(t1, 240 - (#t1 * LARGURA_BRANCA) / 2, 20)
    local stage_v = state.stages[state.stage_atual]
    if stage_v and stage_v.especial then
        local t2 = "FASE ESPECIAL"
        desenhar_texto_branco(t2, 240 - (#t2 * LARGURA_BRANCA) / 2, 45)
        desenhar_ato_e_numero(state.ato_atual or 1, POS_X_ATO, POS_Y_ATO)
    else
        local t2 = em_coop and "VENCERAM O" or "VENCEU O"
        desenhar_texto_branco(t2, 240 - (#t2 * LARGURA_BRANCA) / 2, 45)
        desenhar_ato_e_numero(state.ato_atual or 1, POS_X_ATO, POS_Y_ATO)
    end

    local score_exibir = state.pontuacao
    local bonus_tempo_exibir = 0
    local bonus_aneis_exibir = 0

    if state.vitoria_anim then
        score_exibir = state.pontuacao - (state.bonus_aneis or 0) - (state.bonus_tempo or 0) + state.vitoria_anim.pontos
        bonus_tempo_exibir = state.vitoria_anim.pontos_tempo
        bonus_aneis_exibir = state.vitoria_anim.pontos_aneis
    end

    local RIGHT_ALIGN_X = 420

    desenhar_bloco("PONTOS", 60, 110)
    local score_str = tostring(score_exibir)
    desenhar_texto_ui(score_str, RIGHT_ALIGN_X - (#score_str * 16), 105, 16)

    desenhar_bloco("BONUS", 60, 140)
    desenhar_bloco("DE", 115, 140)
    desenhar_bloco("TEMPO", 155, 140)
    local tempo_str = tostring(bonus_tempo_exibir)
    desenhar_texto_ui(tempo_str, RIGHT_ALIGN_X - (#tempo_str * 16), 135, 16)

    desenhar_bloco("BONUS", 60, 170)
    desenhar_bloco("DE", 115, 170)
    desenhar_bloco("ANEIS", 155, 170)

    local aneis_str = tostring(state.inventory.aneis or 0)
    local pos_num_aneis = 220
    local fim_aneis = desenhar_texto_ui(aneis_str, pos_num_aneis, 165, 16)

    desenhar_x_vitoria(fim_aneis + 8, 173)
    desenhar_texto_ui("100", fim_aneis + 24, 165, 16)

    local bonus_aneis_str = tostring(bonus_aneis_exibir)
    if state.vitoria_anim then
        desenhar_texto_ui(bonus_aneis_str, RIGHT_ALIGN_X - (#bonus_aneis_str * 16), 165, 16)
    else
        desenhar_texto_ui(tostring(state.bonus_aneis or 0), RIGHT_ALIGN_X - (#tostring(state.bonus_aneis or 0) * 16), 165, 16)
    end

    local vidas_str = string.format("%02d", state.vidas or 0)
    local cx_vidas = desenhar_icones_grupo(state, 60, 200)
    desenhar_char_ui("x", cx_vidas, 200)
    desenhar_texto_ui(vidas_str, cx_vidas + 26, 200, 16)

    if state.esmeraldas_coletadas and state.esmeraldas_coletadas > 0 then
        desenhar_esmeralda_vitoria(160, 197, heroi_v)
        desenhar_x_vitoria(182, 203)
        desenhar_char_ui(tostring(state.esmeraldas_coletadas), 198, 200)
        ui.print("/", 214, 206, 7)
        desenhar_char_ui("6", 222, 200)
    end

    if math.floor(ui_frame / 30) % 2 == 0 then
        local txt = "APERTE BOTAO A"
        desenhar_texto_branco(txt, 240 - (#txt * LARGURA_BRANCA) / 2, 235)
    end
end

-- =====================================================================
-- TELA DE PRÓXIMA FASE E SELEÇÃO
-- =====================================================================
-- EGGMAN DO MAPA — eggman-map-31x26.png = 4 tiles de 31x26
--   tile 0 e 1 = frames voando para a ESQUERDA (aplicar flip p/ direita)
--   tile 2     = flutuando parado no mapa
--   tile 3     = fase especial (uso futuro)
-- =====================================================================
local EGG_TILE_W      = 31
local EGG_TILE_H      = 26
local EGG_TILE_ESQ_A  = 0
local EGG_TILE_ESQ_B  = 1
local EGG_TILE_PARADO = 2
local EGG_TILES_TOTAL = 4
-- Atos com chefe: chave = sigla da zona (já existe em State.stages).
-- Autocontido aqui, não depende de função nova no state.lua.
local ATOS_CHEFE_MAPA = { gh = 3, bz = 3, jz = 3, lz = 3, sb = 3, sbz = 3 }
-- Trajetória da entrada no PREVIEW (total 220 frames):
--   espera fora -> cruza p/ direita -> desce fora -> volta p/ o ponto
local EGG_T_ESPERA   = 20
local EGG_T_CRUZA    = 100
local EGG_T_DESCE    = 20
local EGG_T_VOLTA    = 60
local EGG_X_FORA_ESQ = -40
local EGG_X_FORA_DIR = 490
local EGG_Y_CRUZA    = -68   -- offset sobre base_y durante o cruzamento
local EGG_Y_MEIO     = -24   -- offset depois da descida fora da tela

local function desenhar_tile_eggman(img, tile, x, y, flip)
local sx = tile * EGG_TILE_W
local draw_x = x - sx
if flip then
    -- ui.spr espelha a FOLHA INTEIRA, não o tile recortado.
    -- Sem esta compensação o clip mostraria o tile (3 - tile) espelhado.
    local largura_folha = img.width or (EGG_TILE_W * EGG_TILES_TOTAL)
    draw_x = x - (largura_folha - sx - EGG_TILE_W)
    end
    ui.clip(x, y, EGG_TILE_W, EGG_TILE_H)
    ui.spr(img, draw_x, y, flip, false)
    ui.clip()
    end

local function desenhar_mapa_e_trilha(state, piscar)
    local cor_rosa = get_indice_cor(0x56BF)
    ui.rectfill(0, 0, 480, 270, cor_rosa)

    carregar_fontes()

    local map_x, map_y = 138, 45

    if IMG_MAPA then
        ui.spr(IMG_MAPA, map_x, map_y)
    end

    local stage = state.stages[state.stage_atual]
    if stage then
        local caixa_x = map_x + 86
        local caixa_y = map_y + 136
        if stage.especial then
            -- "FASE ESP" + ponto + número do ato (1..6)
            local prefixo = "FASE ESP"
            desenhar_texto_mapa(prefixo, caixa_x, caixa_y)
            local px = caixa_x + #prefixo * 10
            ui.rectfill(px + 3, caixa_y + 8, px + 5, caixa_y + 10, 0)
            desenhar_numero_mapa(state.ato_atual or 1, px + 10, caixa_y)
     else
         desenhar_texto_mapa(stage.nome, caixa_x, caixa_y)
         if desenhar_numero_mapa then
             local px = caixa_x + (#stage.nome + 1) * 10
             desenhar_numero_mapa(state.ato_atual or 1, px, caixa_y)
         end
     end
    end

 -- Relógio da cena: State.tempo_preview É zerado ao entrar no preview.
 -- O contador interno antigo só zerava na tela de seleção, então no modo
 -- história (GH2 -> GH3 sem passar pela seleção) ele já chegava em GH3
 -- com valor > 180 e a animação inteira era pulada.
 preview_anim_timer = piscar and (state.tempo_preview or 0) or 0
 local eh_ato_chefe = stage and ATOS_CHEFE_MAPA[stage.sigla] == state.ato_atual
 if eh_ato_chefe then
     local img_eggman = buscar_sprite("eggman-map-31x26")
     if img_eggman then
         local base_x = map_x + 40
         local base_y = map_y + 40
         local flutuacao_y = math.sin(ui_frame * 0.1) * 4
         local ex, ey, tile, flip
         if not piscar then
             -- SELEÇÃO: parado no ponto da trilha, flutuando
             ex, ey = base_x, base_y + flutuacao_y
             tile, flip = EGG_TILE_PARADO, false
         else
             -- PREVIEW: entra pela esquerda, atravessa, desce fora da tela,
             -- reentra pela direita e desce até o ponto da trilha.
             local t  = preview_anim_timer
             local t1 = EGG_T_ESPERA
             local t2 = t1 + EGG_T_CRUZA
             local t3 = t2 + EGG_T_DESCE
             local t4 = t3 + EGG_T_VOLTA
             local voando = (math.floor(t / 8) % 2 == 0)
                            and EGG_TILE_ESQ_A or EGG_TILE_ESQ_B
             if t < t1 then
                 ex, ey = EGG_X_FORA_ESQ, base_y + EGG_Y_CRUZA
                 tile, flip = voando, true
             elseif t < t2 then
                 local p = (t - t1) / EGG_T_CRUZA
                 ex = EGG_X_FORA_ESQ + (EGG_X_FORA_DIR - EGG_X_FORA_ESQ) * p
                 ey = base_y + EGG_Y_CRUZA
                 tile, flip = voando, true          -- voando p/ direita
             elseif t < t3 then
                 local p = (t - t2) / EGG_T_DESCE
                 ex = EGG_X_FORA_DIR
                 ey = base_y + EGG_Y_CRUZA + (EGG_Y_MEIO - EGG_Y_CRUZA) * p
                 tile, flip = voando, true
             elseif t < t4 then
                 local p = (t - t3) / EGG_T_VOLTA
                 ex = EGG_X_FORA_DIR + (base_x - EGG_X_FORA_DIR) * p
                 ey = base_y + EGG_Y_MEIO * (1 - p)
                 tile, flip = voando, false         -- voando p/ esquerda
             else
                 ex, ey = base_x, base_y + flutuacao_y
                 tile, flip = EGG_TILE_PARADO, false
             end
         end
         desenhar_tile_eggman(img_eggman, tile, ex, ey, flip)
     end
 elseif math.floor(preview_anim_timer / 30) % 2 == 0 then
        -- Por SIGLA, nao por indice: inserir zonas em State.stages
        -- deslocava os indices e a BZ1 pegava a trilha da PESQUISA.
        local sigla_t = (stage and stage.sigla) or ""
        if sigla_t == "gh" or sigla_t == "bz" then
            if IMG_TRILHA_GH then
                local trilha_x, trilha_y, sx
                if sigla_t == "bz" then
                    sx = BZ1_TILE_INDEX * 41
                    trilha_x = map_x + BZ1_TRILHA_OFFSET_X
                    trilha_y = map_y + BZ1_TRILHA_OFFSET_Y
                elseif state.ato_atual == 2 then
                    sx = 41
                    trilha_x = map_x + GH2_TRILHA_OFFSET_X
                    trilha_y = map_y + GH2_TRILHA_OFFSET_Y
                else
                    sx = 0
                    trilha_x = map_x + GH1_TRILHA_OFFSET_X
                    trilha_y = map_y + GH1_TRILHA_OFFSET_Y
                end
                ui.clip(trilha_x, trilha_y, 41, 35)
                ui.spr(IMG_TRILHA_GH, trilha_x - sx, trilha_y)
                ui.clip()
            end
        elseif sigla_t == "tst" then
            if IMG_TRILHA_TST then
                local trilha_x = map_x + TST1_TRILHA_OFFSET_X
                local trilha_y = map_y + TST1_TRILHA_OFFSET_Y

                local col = TST1_TILE_INDEX % 3
                local lin = math.floor(TST1_TILE_INDEX / 3)
                local sx = col * 33
                local sy = lin * 46

                ui.clip(trilha_x, trilha_y, 33, 46)
                ui.spr(IMG_TRILHA_TST, trilha_x - sx, trilha_y - sy)
                ui.clip()
            end
        end
    end

    local vidas_str = string.format("%02d", state.vidas or 0)
    local cx_vidas = desenhar_icones_grupo(state, 20, 230)
    desenhar_char_ui("x", cx_vidas, 230)
    desenhar_texto_ui(vidas_str, cx_vidas + 13, 230, 8)
end

local function desenhar_stage_preview(state)
    desenhar_mapa_e_trilha(state, true)
end

local function desenhar_stage_select(state)
    desenhar_mapa_e_trilha(state, false)

    local txt1 = "SETAS PARA NAVEGAR"
    local txt2 = "APERTE A PARA CONFIRMAR"

    local cx1 = 240 - (#txt1 * 10) / 2
    desenhar_texto_mapa(txt1, cx1, 10)

    local cx2 = 240 - (#txt2 * 10) / 2
    desenhar_texto_mapa(txt2, cx2, 22)
end

local function animar_titulo()
    titulo_timer = titulo_timer + 1
    if titulo_timer >= TITULO_CADENCIA then
        titulo_timer = 0
        titulo_frame = titulo_frame + 1
        if titulo_frame > 2 then titulo_frame = 1 end
    end
    return titulo_frame
end

local function animar_botao()
    botao_timer = botao_timer + 1
    if botao_timer >= BOTAO_CADENCIA then
        botao_timer = 0
        botao_frame = (botao_frame == 1) and 2 or 1
    end
    return botao_frame
end

local function desenhar_titulo()
    ui.rectfill(0, 0, 480, 270, 0)
    local frame = animar_titulo()
    local sprite = Sprites.sprite("titulo", frame)
    local base_y = 200
    if sprite then
        local w = sprite.width or 256
        local h = sprite.height or 128
        ui.spr(sprite, math.floor((480 - w) / 2), math.floor(base_y - h), false, false)
    else
        ui.print("Sonic SMS", 175, 90, 17)
        ui.print("LUPINHO", 200, 120, 21)
    end
    local b_frame = animar_botao()
    local botao_sprite = Sprites.sprite("titulo_botao", 1)
    if botao_sprite and b_frame == 1 then
        local w = botao_sprite.width or 64
        ui.spr(botao_sprite, math.floor((480 - w) / 2), base_y + 10, false, false)
    elseif b_frame == 1 then
        ui.rectfill(180, base_y + 10, 300, base_y + 30, 12)
        ui.print("BOTAO", 210, base_y + 15, 0)
    end
end

local function desenhar_game_over(state)
    ui.rectfill(0, 0, 480, 270, 0)

    local txt_go = "FIM DE JOGO"
    desenhar_texto_branco(txt_go, 240 - (#txt_go * LARGURA_BRANCA) / 2, 30)

    if state.continuacoes and state.continuacoes > 0 then
        local cx = 80
        local cy = 90

        desenhar_palavra_continuar(cx, cy)

        local segs = math.ceil((state.timer_game_over or 0) / 60)
        if segs < 0 then segs = 0 end
        local txt_time = tostring(segs)

        desenhar_texto_ui(txt_time, cx + 100, cy - 2, 16)
        desenhar_estrela_continue(cx + 40, cy + 25)

        local txt_a = "APERTE A"
        desenhar_texto_branco(txt_a, 240 - (#txt_a * LARGURA_BRANCA) / 2, 200)
    else
        local txt_a = "APERTE A"
        desenhar_texto_branco(txt_a, 240 - (#txt_a * LARGURA_BRANCA) / 2, 160)
    end
end

function UI.draw_hud(state)
    ui_frame = ui_frame + 1

    if state.pausado_opcoes then
        local Menus = require("sistemas.menus")
        Menus.draw()
        return
    elseif state.current_scene == state.SCREEN_MENUS then
        local Menus = require("sistemas.menus")
        Menus.draw()
        return
    elseif state.current_scene == state.SCREEN_TITLE then
        desenhar_titulo()
        return
    elseif state.current_scene == state.SCREEN_STAGE_PREVIEW then
        desenhar_stage_preview(state)
        return
    elseif state.current_scene == state.SCREEN_STAGE_SELECT then
        desenhar_stage_select(state)
        return
    elseif state.current_scene == state.SCREEN_VICTORY then
        desenhar_vitoria(state)
        return
    elseif state.current_scene == state.SCREEN_GAME_OVER then
        desenhar_game_over(state)
        return
    end
    desenhar_informacoes(state)
end

UI.desenhar_texto_ui = desenhar_texto_ui
UI.buscar_sprite = buscar_sprite
UI.sprite_ui_heroi = sprite_ui_heroi
UI.desenhar_esmeralda_ui = desenhar_esmeralda_ui
return UI
