-- ============================================================
-- MENUS: titulo > menu > opcoes > volume / brilho
-- Autocontido: resolve fontes/fundo via Sprites.asset.
-- ORDEM IMPORTA: toda local precisa ser declarada ANTES das
-- funcoes que a usam, senao vira global nil dentro delas.
-- ============================================================
local Sprites = require("sistemas.sprites")
local BTN     = require("btn")

local Menus = {}

local W, H = 480, 270

-- ---------- paleta (exato, com fallback por distancia) ----------
local cache_cor = {}
local function cor(hex)
    local c = cache_cor[hex]
    if c then return c end
    local P = _G.Palette
    local melhor, dist = 1, math.huge
    if P then
        for i, v in pairs(P) do
            if v == hex then melhor = i - 1; dist = 0; break end
            local dr = ((v >> 10) & 31) - ((hex >> 10) & 31)
            local dg = ((v >> 5)  & 31) - ((hex >> 5)  & 31)
            local db = (v & 31) - (hex & 31)
            local d = dr * dr + dg * dg + db * db
            if d < dist then dist = d; melhor = i - 1 end
        end
    end
    cache_cor[hex] = melhor
    return melhor
end

-- ---------- assets ----------
local cache_asset = {}
local function asset(caminho)
    local s = cache_asset[caminho]
    if s == nil then
        s = Sprites.asset(caminho) or false
        cache_asset[caminho] = s
    end
    return s or nil
end

-- ---------- acentos ----------
-- [posicao do caractere] = "til" | "cedilha"
-- til     = tile 26 (~) sobre a letra
-- cedilha = tile 27 (´) invertido 180 graus, sob a letra
local ACENTOS = {
    OPCOES = { [3] = "cedilha", [4] = "til" },
    ["MODO HISTORIA"] = { [10] = "agudo" },
}
local ACENTO_TIL_DX = 0
local ACENTO_TIL_DY = -8
local ACENTO_CED_DX = -4
local ACENTO_CED_DY = 4
-- Agudo (tile 27 SEM flip) sobre a letra. Ajuste fino aqui.
local ACENTO_AGU_DX = 0
local ACENTO_AGU_DY = -8
-- Flip do tile 27 para virar cedilha. Teste as 4 combinacoes:
--   false,false = como esta na folha
--   true ,false = espelhado na horizontal
--   false,true  = espelhado na vertical   <- padrao atual
--   true ,true  = girado 180 (o que estava antes, virou "g")
local CED_FLIP_X, CED_FLIP_Y = false, false

-- ---------- fontes ----------
-- fonte-titl-W10xH11: 7 col x 4 lin, celula 10x11 (A..Z, ~, ´)
-- fonte-mapa-10x10 : 9 col x 3 lin, celula 10x10 (A..Z)
local function texto(fonte, str, x, y, passo)
    local img, cw, ch, cols
    if fonte == "titl" then
        img = asset("ui/fonte-titl-W10xH11"); cw, ch, cols = 10, 11, 7
    else
        img = asset("mapa/fonte-mapa-10x10"); cw, ch, cols = 10, 10, 9
    end
    passo = passo or cw
    if not img then ui.print(str, x, y, 7); return x + #str * passo end
    str = string.upper(str)
    local acentos = (fonte == "titl") and ACENTOS[str] or nil
    local cx = x
    for i = 1, #str do
        local b = string.byte(str, i)
        if b >= 65 and b <= 90 then
            local idx = b - 65
            local sx = (idx % cols) * cw
            local sy = math.floor(idx / cols) * ch
            ui.clip(cx, y, cw, ch)
            ui.spr(img, cx - sx, y - sy)
            ui.clip()
        end
        if acentos and acentos[i] then
            local tipo = acentos[i]
            local ai = (tipo == "til") and 26 or 27
            local ax = (ai % cols) * cw
            local ay = math.floor(ai / cols) * ch
            if tipo == "til" then
                local dx_ac = cx + ACENTO_TIL_DX
                local dy = y + ACENTO_TIL_DY
                ui.clip(dx_ac, dy, cw, ch)
                ui.spr(img, dx_ac - ax, dy - ay)
                ui.clip()
            elseif tipo == "agudo" then
                local dx_ac = cx + ACENTO_AGU_DX
                local dy = y + ACENTO_AGU_DY
                ui.clip(dx_ac, dy, cw, ch)
                ui.spr(img, dx_ac - ax, dy - ay)
                ui.clip()
            else
                local dx_ac = cx + ACENTO_CED_DX
                local dy = y + ACENTO_CED_DY
                -- tile 27 e o ultimo da folha nos DOIS eixos: com o flip
                -- ligado o offset compensado vira zero; desligado, usa
                -- o offset normal do recorte.
                local ddx = CED_FLIP_X and dx_ac or (dx_ac - ax)
                local ddy = CED_FLIP_Y and dy or (dy - ay)
                ui.clip(dx_ac, dy, cw, ch)
                ui.spr(img, ddx, ddy, CED_FLIP_X, CED_FLIP_Y)
                ui.clip()
            end
        end
        cx = cx + passo
    end
    return cx
end

local function texto_centrado(fonte, str, y, passo)
    passo = passo or 10
    return texto(fonte, str, math.floor((W - #str * passo) / 2), y, passo)
end

-- Digito do ui-16x16: ids 1..10 = 0..9, grid de 4 colunas de 16x16.
-- A fonte-mapa so tem A-Z, por isso o numero precisa vir daqui.
local function digito_ui(d, x, y)
    local img = asset("ui/ui-16x16")
    if not img then ui.print(tostring(d), x, y, 7); return end
    local id = d + 1
    if id < 1 or id > 10 then return end
    local sx = ((id - 1) % 4) * 16
    local sy = math.floor((id - 1) / 4) * 16
    ui.clip(x, y, 16, 16)
    ui.spr(img, x - sx, y - sy)
    ui.clip()
end

-- Numero com os digitos do ui-16x16 (a fonte-mapa nao tem numeros).
local function numero_ui(valor, x, y, passo)
    local s = tostring(valor)
    passo = passo or 14
    local cx = x
    for i = 1, #s do
        local d = tonumber(s:sub(i, i))
        if d then
            digito_ui(d, cx, y)
            cx = cx + passo
        end
    end
    return cx
end

local function numero_ui_centrado(valor, y, passo)
    passo = passo or 14
    local s = tostring(valor)
    return numero_ui(valor, math.floor((W - #s * passo) / 2), y, passo)
end

-- ---------- listas ----------
local ITENS_MENU   = { "MODO HISTORIA", "MODOS EXTRAS", "OPCOES" }
local ITENS_OPCOES = { "VOLUME DO JOGO", "BRILHO E CONTRASTE", "ESCOLHA DE FASE", "VOLTAR" }
-- No pause in-game a escolha de fase fica oculta. Ligue para true
-- durante o desenvolvimento para te-la disponivel no L1+R1.
local ESCOLHA_FASE_NO_PAUSE = false
local ITENS_OPCOES_PAUSE = { "VOLUME DO JOGO", "BRILHO E CONTRASTE", "VOLTAR" }
local ITENS_AUDIO  = { "VOLUME GERAL", "TESTAR MUSICAS", "CANAIS", "VOLTAR" }
local ITENS_EXTRAS = {
    "MODO COOP", "REI DOS ANEIS", "VELOCISTA",
    "TESTE DE AGILIDADE", "SOBREVIVENTE", "PERSEGUICAO", "VOLTAR",
}

-- Ordem dos tiles do sel_heroi (480x270 = 3 col x 2 lin de 160x135).
local HEROIS = { "sonic", "tails", "knux", "amy", "cream", "rouge" }
-- Paleta BGR555: bits ALTOS = azul, baixos = vermelho.
local CORES_HEROI = {
    sonic = 0x7C00, tails = 0x03FF, knux = 0x001F,
    amy   = 0x515F, cream = 0x2A9C, rouge = 0x64B4,
}
local SEL_TW, SEL_TH, SEL_COLS = 160, 135, 3

local sel_num    = 2
local sel_cursor = { 0, 1, 2 }
local sel_ok     = { false, false, false }
local sel_timer  = 0

-- Espelha audio/bgm do manifest. Acrescentar linha quando criar BGM nova.
local MUSICAS = {
    "audio/bgm/titulo", "audio/bgm/greenhill", "audio/bgm/bridgezn",
    "audio/bgm/junglezn", "audio/bgm/labyrinthzn", "audio/bgm/scrapbrainzn",
    "audio/bgm/skybasezn", "audio/bgm/chefe", "audio/bgm/salabonus",
    "audio/bgm/invenc", "audio/bgm/venceu", "audio/bgm/vence_esmeralda",
    "audio/bgm/perdeu", "audio/bgm/fim", "audio/bgm/final",
    "audio/bgm/skysanct-unused", "audio/bgm/marblezn-unused",
    "audio/fx/actstart",
}

local CANAIS = { CH_1, CH_2, CH_3, CH_4, CH_5, CH_6, CH_7, CH_8 }

-- ---------- estado ----------
local tela = "menu"
local idx = 1
local aviso = 0
local fundo_t = 0
local vol = 100
local mus_idx, mus_scroll = 1, 1
local ch_idx = 1
local ch_mudo = {}

local brilho = 0        -- -16 .. +16 (por canal, escala 0..31)
local contraste = 100   -- 50 .. 150 (por cento)
local bc_idx = 1
local preview_tst = nil
local PALETA_ORIG = nil

local overlay = false   -- true = aberto por L1+R1 durante o jogo

local PREVIEW_W, PREVIEW_H = 240, 136
local PREVIEW_X = math.floor((W - PREVIEW_W) / 2)
local PREVIEW_Y = 46

-- ---------- paleta: brilho / contraste ----------
local function guardar_paleta()
    if PALETA_ORIG then return end
    local P = _G.Palette
    if not P then return end
    PALETA_ORIG = {}
    for i = 1, #P do PALETA_ORIG[i] = P[i] end
end

local function restaurar_paleta()
    if not PALETA_ORIG then return end
    local P = _G.Palette
    if not P then return end
    for i = 1, #PALETA_ORIG do P[i] = PALETA_ORIG[i] end
end

-- Escreve a paleta ajustada lendo da ORIGEM (nao acumula). O loop de
-- palset do game.lua aplica isto, e o Transicao.aplicar multiplica o
-- fator do fade por cima -- o preto do fade continua preto.
local function aplicar_paleta()
    guardar_paleta()
    if not PALETA_ORIG then return end
    local P = _G.Palette
    if not P then return end
    local k = contraste / 100
    for i = 1, #PALETA_ORIG do
        local v = PALETA_ORIG[i]
        local r = math.floor(((v >> 10) & 31) * 1)
        local g = (v >> 5) & 31
        local b = v & 31
        local function ajuste(c)
            c = math.floor((c - 16) * k + 16 + brilho + 0.5)
            if c < 0 then c = 0 elseif c > 31 then c = 31 end
            return c
        end
        P[i] = (ajuste(r) << 10) | (ajuste(g) << 5) | ajuste(b)
    end
end

-- ---------- preview da fase PESQUISA ----------
local function iniciar_preview_tst()
    local State = require("state")
    for i, s in ipairs(State.stages) do
        if s.sigla == "tst" then
            State.stage_atual = i
            State.ato_atual = 1
            State.preparar_carregamento()
            preview_tst = i
            return
        end
    end
end

-- Desenha o mundo ja carregado dentro de uma janela, na camera dada.
-- Serve tanto para o tst1 (opcoes do titulo) quanto para o estado
-- atual pausado (opcoes abertas com L1+R1 no meio da fase).
local function desenhar_janela_mundo(cam_x, cam_y)
    local Mapa     = require("mapa")
    local State    = require("state")
    local Objetos  = require("sistemas.objetos")
    local Aneis    = require("sistemas.aneis")
    local Inimigos = require("sistemas.inimigos")
    local Player   = require("sistemas.player")
    local UI       = require("sistemas.ui")

    local x0, y0 = PREVIEW_X, PREVIEW_Y
    local x1, y1 = PREVIEW_X + PREVIEW_W, PREVIEW_Y + PREVIEW_H

    local b = cor(0x7FFF)
    ui.rectfill(x0 - 2, y0 - 2, x1 + 2, y0, b)
    ui.rectfill(x0 - 2, y1, x1 + 2, y1 + 2, b)
    ui.rectfill(x0 - 2, y0, x0, y1, b)
    ui.rectfill(x1, y0, x1 + 2, y1, b)

    if Mapa.carregando then
        ui.rectfill(x0, y0, x1, y1, cor(0x0000))
        texto("mapa", "CARREGANDO", x0 + 70, y0 + 62)
        return
    end

    local dx, dy = -cam_x, -cam_y
    ui.rectfill(x0, y0, x1, y1, cor(0x7EA0))

    UI.set_clip_guard(x0, y0, PREVIEW_W, PREVIEW_H)
    local function recorte() ui.clip(x0, y0, PREVIEW_W, PREVIEW_H) end
    local vw, vh = PREVIEW_W, PREVIEW_H
    recorte(); Mapa.draw_fundo(dx, dy, vw, vh)
    recorte(); Mapa.draw_deco(dx, dy, vw, vh)
    recorte(); Mapa.draw_agua(dx, dy, vw, vh)
    recorte(); Mapa.draw_objetos(dx, dy, vw, vh)
    recorte(); Objetos.draw(cam_x, cam_y)
    recorte(); Aneis.draw(cam_x, cam_y)
    recorte(); Inimigos.draw(cam_x, cam_y)
    for _, p in ipairs(State.players or { State.player }) do
        if p then recorte(); Player.draw(p, cam_x, cam_y) end
    end
    recorte(); Mapa.draw_chao(dx, dy, vw, vh)
    UI.set_clip_guard(nil)
    ui.clip()
    end

    local function desenhar_preview_tst()
    if overlay then
        -- Centra no PRIMEIRO PLAYER VIVO, nao na camera: em coop a
        -- camera fica na media do grupo e, com os dois afastados,
        -- nenhum deles caia dentro da janela.
        local State = require("state")
        local alvo = nil
        for _, p in ipairs(State.players or { State.player }) do
            if p and not p.morto and not p.coop_esperando then alvo = p; break end
        end
        alvo = alvo or State.player
        if alvo then
            desenhar_janela_mundo(
                math.floor(alvo.x - PREVIEW_W / 2),
                math.floor(alvo.y + 16 - PREVIEW_H / 2))
        end
        return
    end
    if not preview_tst then
        ui.rectfill(PREVIEW_X, PREVIEW_Y, PREVIEW_X + PREVIEW_W, PREVIEW_Y + PREVIEW_H, cor(0x0000))
        texto("mapa", "CARREGANDO", PREVIEW_X + 70, PREVIEW_Y + 62)
        return
    end
    desenhar_janela_mundo(40, 80)
end

-- ---------- borda + fundo diagonal ----------
local BORDA_HEX = { 0x0400, 0x2800, 0x5400, 0x7C00, 0x7D4A, 0x7EA0, 0x7EBF, 0x7FFF }
local BORDA_ESP      = 16   -- 8 faixas de 2px
local BORDA_RAIO_EXT = 28
local BORDA_RAIO_INT = 12

local function rect_round_fill(x0, y0, x1, y1, r, c)
    ui.rectfill(x0 + r, y0, x1 - r, y1, c)
    ui.rectfill(x0, y0 + r, x0 + r, y1 - r, c)
    ui.rectfill(x1 - r, y0 + r, x1, y1 - r, c)
    ui.circfill(x0 + r, y0 + r, r, c)
    ui.circfill(x1 - r, y0 + r, r, c)
    ui.circfill(x0 + r, y1 - r, r, c)
    ui.circfill(x1 - r, y1 - r, r, c)
end

-- Recorta os 4 cantos do miolo para a borda interna ficar redonda.
local function mascarar_cantos()
    local c = cor(BORDA_HEX[#BORDA_HEX])
    local r = BORDA_RAIO_INT
    local bx, by = BORDA_ESP, BORDA_ESP
    local bx2, by2 = W - BORDA_ESP, H - BORDA_ESP
    for j = 0, r - 1 do
        local dy = r - j
        local dx = math.floor(math.sqrt(r * r - dy * dy) + 0.5)
        local m = r - dx
        if m > 0 then
            ui.rectfill(bx, by + j, bx + m, by + j + 1, c)
            ui.rectfill(bx2 - m, by + j, bx2, by + j + 1, c)
            ui.rectfill(bx, by2 - 1 - j, bx + m, by2 - j, c)
            ui.rectfill(bx2 - m, by2 - 1 - j, bx2, by2 - j, c)
        end
    end
end

local function desenhar_fundo()
    -- 0. base na cor da faixa mais externa: o circfill dos cantos nao
    --    alcanca a quina da tela, e sem isto sobrava o ceu ali.
    ui.rectfill(0, 0, W, H, cor(BORDA_HEX[1]))

    -- 1. faixas arredondadas de fora para dentro (escuro -> claro).
    for i, hex in ipairs(BORDA_HEX) do
        local d = (i - 1) * 2
        rect_round_fill(d, d, W - 1 - d, H - 1 - d, BORDA_RAIO_EXT - d, cor(hex))
    end

    -- 2. fundo por cima, recortado no miolo. Um clip so para as 4
    --    copias: cada uma rasteriza apenas a parte que cobre.
    local img = asset("titulo/botao/opcoes/fundo")
    if img then
        fundo_t = fundo_t + 0.35
        local ox = -math.floor(fundo_t % W)
        local oy = -math.floor((fundo_t * 0.5) % H)
        ui.clip(BORDA_ESP, BORDA_ESP, W - 2 * BORDA_ESP, H - 2 * BORDA_ESP)
        ui.spr(img, ox, oy)
        ui.spr(img, ox + W, oy)
        ui.spr(img, ox, oy + H)
        ui.spr(img, ox + W, oy + H)
        ui.clip()
    end

    -- 3. arredonda o canto interno por cima do fundo
    mascarar_cantos()
end

-- ---------- helpers de desenho ----------
local function desenhar_lista(itens, sel, y0, passo, fonte)
    for i, nome in ipairs(itens) do
        local y = y0 + (i - 1) * passo
        local x = math.floor((W - #nome * 10) / 2)
        -- VOLTAR sempre na fonte do titulo, nas outras telas tambem.
        -- As duas fontes tem 10px de largura, entao a centralizacao
        -- acima continua valendo.
        local f = (nome == "VOLTAR") and "titl" or fonte
        texto(f, nome, x, y)
        if i == sel then
            ui.trisfill(x - 14, y + 1, x - 14, y + 9, x - 7, y + 5, cor(0x7FFF))
        end
    end
end

local function lista_opcoes()
    if overlay and not ESCOLHA_FASE_NO_PAUSE then return ITENS_OPCOES_PAUSE end
    return ITENS_OPCOES
end

-- Transicao de cena. Precisa vir ANTES de qualquer funcao que a use
-- (iniciar_coop, por exemplo), senao vira global nil la dentro.
local function ir(cena)
    local State = require("state")
    local Transicao = require("sistemas.transicao")
    State.proxima_cena = cena
    if not Transicao.ativa then Transicao.iniciar() end
end

local function iniciar_coop()
    local State = require("state")
    local Coop  = require("sistemas.coop")
    State.coop_num_players = sel_num
    State.coop_herois = {}
    for i = 1, sel_num do
        State.coop_herois[i] = HEROIS[sel_cursor[i] + 1] or "sonic"
    end
    State.modo = "coop"
    State.vidas = Coop.vidas_iniciais(sel_num)
    -- Coop comeca em GREEN HILL ato 1
    for i, s in ipairs(State.stages) do
        if s.sigla == "gh" then
            State.stage_atual = i
            State.ato_atual = 1
            break
        end
    end
    State.selecao_confirmada = true
    State.espera_soltar = true
    State.preparar_carregamento()
    overlay = false
    restaurar_paleta()
    ir(State.SCREEN_STAGE_PREVIEW)
end

local function abrir_sel_heroi()
    sel_num, sel_timer = 2, 0
    for i = 1, 3 do
        sel_cursor[i] = i - 1
        sel_ok[i] = false
    end
    tela = "sel_heroi"
end

local function barra(x, y, w, h, frac, hex)
    ui.rectfill(x, y, x + w, y + h, cor(0x0000))
    local fw = math.floor(w * frac)
    if fw > 0 then ui.rectfill(x, y, x + fw, y + h, cor(hex)) end
    ui.rect(x, y, x + w, y + h, cor(0x7FFF))
end

local function aplicar_volume(fade)
    if type(music) == "table" and music.volume then
        -- 2 argumentos = volume MASTER. Com 3 args (CH_ALL) mexe no
        -- ganho dos canais, que o crossfade do audio.lua sobrescreve.
        music.volume(vol / 100, fade or 0.1)
    end
    local State = require("state")
    State.volume_master = vol / 100
end

function Menus.reset()
    tela, idx, aviso = "menu", 1, 0
    overlay = false
    restaurar_paleta()
end

-- Abre as opcoes por cima do jogo (L1+R1). O "voltar" fecha o
-- overlay e devolve o controle, em vez de ir para o menu principal.
function Menus.abrir_overlay()
    overlay = true
    tela, idx, aviso = "opcoes", 1, 0
end

local function fechar_overlay()
    local State = require("state")
    overlay = false
    State.pausado_opcoes = false
    restaurar_paleta()
    tela, idx = "menu", 1
end

-- ---------- desenho ----------
function Menus.draw()
    desenhar_fundo()

    if tela == "menu" then
        texto_centrado("titl", "SONIC", 46, 12)
        desenhar_lista(ITENS_MENU, idx, 110, 24, "titl")
        texto_centrado("mapa", "SETAS PARA MOVER", 216)
        texto_centrado("mapa", "BOTAO A PARA CONFIRMAR", 232)
    elseif tela == "extras" then
        texto_centrado("titl", "MODOS EXTRAS", 34, 12)
        desenhar_lista(ITENS_EXTRAS, idx, 76, 22, "mapa")
        texto_centrado("mapa", "X PARA VOLTAR", 232)

    elseif tela == "sel_heroi" then
        local img = asset("titulo/botao/m_extra/sel_heroi")
        if img then
            ui.spr(img, 0, 0)
        else
            ui.rectfill(0, 0, W, H, cor(0x0000))
        end
        local piscar = math.floor(sel_timer / 8) % 2 == 0
        for i = 1, sel_num do
            local t = sel_cursor[i]
            local tx = (t % SEL_COLS) * SEL_TW
            local ty = math.floor(t / SEL_COLS) * SEL_TH
            local c = cor(CORES_HEROI[HEROIS[t + 1]] or 0x7FFF)
            -- confirmado fica fixo; nao confirmado pisca
            if sel_ok[i] or piscar then
                ui.rect(tx + 1, ty + 1, tx + SEL_TW - 2, ty + SEL_TH - 2, c)
                ui.rect(tx + 2, ty + 2, tx + SEL_TW - 3, ty + SEL_TH - 3, c)
                ui.rect(tx + 3, ty + 3, tx + SEL_TW - 4, ty + SEL_TH - 4, c)
            end
            local lx = tx + math.floor(SEL_TW / 2) - 13
            local ly = ty + SEL_TH - 22
            ui.rectfill(lx - 3, ly - 2, lx + 29, ly + 15, cor(0x0000))
            texto("mapa", "P", lx, ly)
            digito_ui(i, lx + 10, ly - 3)
        end
        ui.rectfill(150, 2, 330, 18, cor(0x0000))
        texto("mapa", "PLAYERS", 158, 5)
        digito_ui(sel_num, 226, 2)
        texto("mapa", "L R", 250, 5)
    elseif tela == "opcoes" then
        texto_centrado("titl", "OPCOES", 40, 12)
        desenhar_lista(lista_opcoes(), idx, 100, 24, "mapa")
        texto_centrado("mapa", "X PARA VOLTAR", 226)

    elseif tela == "audio" then
        texto_centrado("titl", "VOLUME DO JOGO", 40, 12)
        desenhar_lista(ITENS_AUDIO, idx, 96, 22, "mapa")
        texto_centrado("mapa", "X PARA VOLTAR", 226)

    elseif tela == "brilho" then
        texto_centrado("titl", "BRILHO E CONTRASTE", 24, 12)
        desenhar_preview_tst()
        local y1, y2 = 192, 210
        texto("mapa", "BRILHO", 70, y1)
        barra(160, y1, 190, 8, (brilho + 16) / 32, 0x03E0)
        texto("mapa", tostring(brilho), 360, y1)
        texto("mapa", "CONTRASTE", 70, y2)
        barra(160, y2, 190, 8, (contraste - 50) / 100, 0x03E0)
        texto("mapa", tostring(contraste), 360, y2)
        local sy = (bc_idx == 1) and y1 or y2
        ui.trisfill(56, sy + 1, 56, sy + 9, 63, sy + 5, cor(0x7FFF))
        texto_centrado("mapa", "ESQ DIR AJUSTA   L R RESETA", 228)
        texto_centrado("mapa", "CIMA BAIXO ESCOLHE   X VOLTA", 240)

    elseif tela == "master" then
        texto_centrado("titl", "VOLUME GERAL", 40, 12)
        barra(120, 110, 240, 12, vol / 100, 0x03E0)
        numero_ui_centrado(vol, 132, 14)
        texto_centrado("mapa", "ESQ DIR MAIS OU MENOS 1", 176)
        texto_centrado("mapa", "CIMA BAIXO MAIS OU MENOS 10", 192)
        texto_centrado("mapa", "L ZERA   R MAXIMO", 208)
        texto_centrado("mapa", "X PARA VOLTAR", 232)

    elseif tela == "musicas" then
        texto_centrado("titl", "TESTAR MUSICAS", 34, 12)
        local visiveis = 10
        if mus_idx > mus_scroll + visiveis - 1 then mus_scroll = mus_idx - visiveis + 1 end
        if mus_idx < mus_scroll then mus_scroll = mus_idx end
        for i = 1, visiveis do
            local k = mus_scroll + i - 1
            local nome = MUSICAS[k]
            if nome then
                local y = 66 + (i - 1) * 14
                local curto = string.gsub(nome, "^audio/", "")
                if k == mus_idx then
                    ui.rectfill(60, y - 2, 420, y + 11, cor(0x5400))
                end
                texto("mapa", curto, 68, y)
            end
        end
        texto_centrado("mapa", "A TOCA   X PARA VOLTAR", 232)

    elseif tela == "canais" then
        texto_centrado("titl", "CANAIS", 34, 12)
        for i = 1, 8 do
            local col = math.floor((i - 1) / 4)
            local lin = (i - 1) % 4
            local x = 130 + col * 140
            local y = 80 + lin * 22
            if i == ch_idx then
                ui.rectfill(x - 6, y - 3, x + 110, y + 12, cor(0x5400))
            end
            texto("mapa", "CANAL", x, y)
            digito_ui(i, x + 54, y - 3)
            texto("mapa", ch_mudo[i] and "MUDO" or "ON", x + 74, y)
        end
        texto_centrado("mapa", "A ALTERNA   L MUDO   R LIGA", 200)
        texto_centrado("mapa", "X PARA VOLTAR", 232)
    end

    if aviso > 0 then
        ui.rectfill(140, 128, 340, 152, cor(0x0000))
        ui.rect(140, 128, 340, 152, cor(0x7FFF))
        texto_centrado("mapa", "EM BREVE", 136)
    end
end

-- ---------- update ----------
local function press(b) return b ~= nil and ui.btnp(b, 0) ~= false end

-- Auto-repeat por botao: 1o passo imediato, espera 24f, depois 6f.
local REP_ATRASO, REP_RATE = 24, 6
local rep_t = {}
local function repetiu(b)
    if b == nil then return false end
    if ui.btn(b, 0) == false then rep_t[b] = nil; return false end
    if ui.btnp(b, 0) ~= false then rep_t[b] = REP_ATRASO; return true end
    local t = (rep_t[b] or REP_ATRASO) - 1
    if t <= 0 then rep_t[b] = REP_RATE; return true end
    rep_t[b] = t
    return false
end

function Menus.update(input)
    local State = require("state")
    aplicar_paleta()
    if aviso > 0 then aviso = aviso - 1; return end

    local cima  = repetiu(BTN.UP)
    local baixo = repetiu(BTN.DOWN)
    local esq   = repetiu(BTN.LEFT)
    local dir   = repetiu(BTN.RIGHT)
    local ok    = press(BTN.Z)
    local volta = press(BTN.X)

    if tela == "menu" then
        if cima  then idx = math.max(1, idx - 1) end
        if baixo then idx = math.min(#ITENS_MENU, idx + 1) end
        if ok then
            if idx == 1 then
                restaurar_paleta()
                State.selecao_confirmada = false
                ir(State.SCREEN_STAGE_SELECT)
            elseif idx == 2 then
                tela, idx = "extras", 1
            else
                tela, idx = "opcoes", 1
            end
        end
        if volta then Menus.reset(); ir(State.SCREEN_TITLE) end
        elseif tela == "extras" then
        if cima  then idx = math.max(1, idx - 1) end
        if baixo then idx = math.min(#ITENS_EXTRAS, idx + 1) end
        local item = ITENS_EXTRAS[idx]
        if ok then
            if item == "MODO COOP" then
                abrir_sel_heroi()
            elseif item == "VOLTAR" then
                tela, idx = "menu", 2
            else
                aviso = 120
            end
        end
        if volta then tela, idx = "menu", 2 end

    elseif tela == "sel_heroi" then
        sel_timer = sel_timer + 1
        local algum_ok = false
        for i = 1, sel_num do if sel_ok[i] then algum_ok = true end end

        -- L/R mudam a contagem enquanto ninguem confirmou
        if not algum_ok then
            if press(BTN.F) then sel_num = math.max(1, sel_num - 1) end
            if press(BTN.G) then sel_num = math.min(3, sel_num + 1) end
        end

        for i = 1, sel_num do
            local pad = i - 1
            if not sel_ok[i] then
                local t = sel_cursor[i]
                local col, lin = t % SEL_COLS, math.floor(t / SEL_COLS)
                if ui.btnp(BTN.LEFT,  pad) ~= false then col = (col + SEL_COLS - 1) % SEL_COLS end
                if ui.btnp(BTN.RIGHT, pad) ~= false then col = (col + 1) % SEL_COLS end
                if ui.btnp(BTN.UP,    pad) ~= false then lin = (lin + 1) % 2 end
                if ui.btnp(BTN.DOWN,  pad) ~= false then lin = (lin + 1) % 2 end
                sel_cursor[i] = lin * SEL_COLS + col
                if ui.btnp(BTN.Z, pad) ~= false then sel_ok[i] = true end
            elseif ui.btnp(BTN.X, pad) ~= false then
                sel_ok[i] = false
            end
        end

        local todos = true
        for i = 1, sel_num do if not sel_ok[i] then todos = false end end
        if todos then
            iniciar_coop()
        elseif volta and not sel_ok[1] then
            -- X com P1 nao confirmado sai da tela; com P1 confirmado
            -- o X dele ja foi consumido acima para desmarcar.
            tela, idx = "extras", 1
        end
    elseif tela == "opcoes" then
        local itens = lista_opcoes()
        if idx > #itens then idx = #itens end
        if cima  then idx = math.max(1, idx - 1) end
        if baixo then idx = math.min(#itens, idx + 1) end
        -- Por NOME: a lista muda entre titulo e pause, e por indice os
        -- itens trocariam de funcao.
        local item = itens[idx]
        if ok then
            if item == "VOLUME DO JOGO" then
                tela, idx = "audio", 1
            elseif item == "BRILHO E CONTRASTE" then
                tela, bc_idx = "brilho", 1
                if not overlay then iniciar_preview_tst() end
            elseif item == "ESCOLHA DE FASE" then
                restaurar_paleta()
                State.pausado_opcoes = false
                State.selecao_confirmada = false
                ir(State.SCREEN_STAGE_SELECT)
            elseif overlay then
                fechar_overlay()
            else
                tela, idx = "menu", 3
            end
        end
        if volta then
            if overlay then fechar_overlay() else tela, idx = "menu", 3 end
        end

    elseif tela == "audio" then
        if cima  then idx = math.max(1, idx - 1) end
        if baixo then idx = math.min(#ITENS_AUDIO, idx + 1) end
        if ok then
            if idx == 1 then tela = "master"
            elseif idx == 2 then tela = "musicas"
            elseif idx == 3 then tela = "canais"
            else tela, idx = "opcoes", 1 end
        end
        if volta then tela, idx = "opcoes", 1 end

    elseif tela == "brilho" then
        if cima  then bc_idx = 1 end
        if baixo then bc_idx = 2 end
        local passo = (bc_idx == 1) and 1 or 5
        if esq then
            if bc_idx == 1 then brilho = math.max(-16, brilho - passo)
            else contraste = math.max(50, contraste - passo) end
        end
        if dir then
            if bc_idx == 1 then brilho = math.min(16, brilho + passo)
            else contraste = math.min(150, contraste + passo) end
        end
        if press(BTN.F) or press(BTN.G) then brilho, contraste = 0, 100 end
        if volta then tela, idx = "opcoes", 2 end

    elseif tela == "master" then
        local antes = vol
        if esq   then vol = math.max(0, vol - 1) end
        if dir   then vol = math.min(100, vol + 1) end
        if cima  then vol = math.min(100, vol + 10) end
        if baixo then vol = math.max(0, vol - 10) end
        if press(BTN.F) then vol = 0 end
        if press(BTN.G) then vol = 100 end
        if vol ~= antes then aplicar_volume() end
        if volta then tela, idx = "audio", 1 end

    elseif tela == "musicas" then
        if cima  then mus_idx = math.max(1, mus_idx - 1) end
        if baixo then mus_idx = math.min(#MUSICAS, mus_idx + 1) end
        if ok and type(music) == "table" and music.loop then
            music.loop(MUSICAS[mus_idx], 0.5)
            aplicar_volume(0.2)
        end
        if volta then tela, idx = "audio", 2 end

    elseif tela == "canais" then
        if cima  then ch_idx = math.max(1, ch_idx - 1) end
        if baixo then ch_idx = math.min(8, ch_idx + 1) end
        if esq   then ch_idx = math.max(1, ch_idx - 4) end
        if dir   then ch_idx = math.min(8, ch_idx + 4) end
        if ok and CANAIS[ch_idx] and type(music) == "table" and music.volume then
            ch_mudo[ch_idx] = not ch_mudo[ch_idx]
            music.volume(ch_mudo[ch_idx] and 0 or 1.0, CANAIS[ch_idx], 0.1)
        end
        if press(BTN.F) or press(BTN.G) then
            local mudo = press(BTN.F)
            for i = 1, 8 do
                ch_mudo[i] = mudo
                if CANAIS[i] and type(music) == "table" and music.volume then
                    music.volume(mudo and 0 or 1.0, CANAIS[i], 0.1)
                end
            end
        end
        if volta then tela, idx = "audio", 3 end
    end
end

return Menus
