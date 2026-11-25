-- ============================================================
-- COOP: regras de vidas compartilhadas, morte e respawn.
-- Nao desenha nem le input: o host (game.lua/state.lua) chama
-- estas funcoes e age conforme o retorno.
-- ============================================================
local BTN = require("btn")
local Coop = {}

Coop.MAX_PLAYERS    = 3
Coop.VIDAS_POR_PLAYER = 3   -- 1p=3, 2p=6, 3p=9 (pool compartilhado)
function Coop.vidas_iniciais(n) return Coop.VIDAS_POR_PLAYER * (n or 1) end
Coop.RESPAWN_FRAMES = 120   -- 2 segundos a 60fps
Coop.INVENC_RESPAWN = 90    -- 1,5s piscando ao voltar

Coop.ativo   = false
Coop.players = {}

function Coop.init(players)
    Coop.players = players or {}
    Coop.ativo = #Coop.players > 1
    for i, p in ipairs(Coop.players) do
        p.pad = i - 1
        p.coop_esperando = false
        p.coop_timer = 0
    end
end

function Coop.vivos()
    local n = 0
    for _, p in ipairs(Coop.players) do
        if not p.morto and not p.coop_esperando then n = n + 1 end
    end
    return n
end

function Coop.todos_mortos()
    if #Coop.players == 0 then return false end
    return Coop.vivos() == 0
end

-- Reposiciona um player no checkpoint dele e devolve o controle.
function Coop.reviver(p)
    p.morto            = false
    p.coop_esperando   = false
    p.coop_travado     = false
    p.coop_timer       = 0
    p.timer_morte      = 0
    p.x, p.y           = p.spawn_x, p.spawn_y
    p.velocidade_x     = 0
    p.velocidade_y     = 0
    p.em_dano          = false
    p.em_queda         = false
    p.rodando          = false
    p.esta_pulando     = false
    p.pulou_mola       = false
    p.plataforma_atual = nil
    p.pendulo_atual    = nil
    p.saiu_da_tela     = false
    p.morte_queda      = false
    p.morte_dy         = 0
    p.timer_invencivel = Coop.INVENC_RESPAWN
    if p.oxigenio then
        p.oxigenio.tempo_restante = p.oxigenio.tempo_maximo
        p.oxigenio.na_agua   = false
        p.oxigenio.morrendo  = false
        p.oxigenio.timer_morte = 0
    end
end

-- Chamado DEPOIS da animacao de morte do player (60f).
-- Custo de vida do pool compartilhado.
function Coop.ao_morrer(p, State)
    p.coop_esperando = true
    p.coop_timer = 0
    -- Morreu com o pool zerado: fica TRAVADO. Se o outro player
    -- ganhar uma vida depois, ele nao revive sozinho -- precisa
    -- apertar confirmar para gastar essa vida.
    p.coop_travado = (State.vidas <= 0)
    if State.vidas > 0 then State.vidas = State.vidas - 1 end
end

-- Tick por frame. Devolve a acao que o host deve tomar:
--   nil            -> segue o jogo
--   "resetar_fase" -> todos mortos, ainda ha vidas
--   "game_over"    -> todos mortos e vidas zeradas
function Coop.atualizar(State)
    if not Coop.ativo then return nil end

    for _, p in ipairs(Coop.players) do
        if p.coop_esperando then
            p.coop_timer = (p.coop_timer or 0) + 1
            if p.coop_travado then
                -- Travado: so sai com confirmar DO PROPRIO player e
                -- com vida disponivel no pool.
                if State.vidas > 0 and ui.btnp(BTN_Z, p.pad or 0) ~= false then
                    State.vidas = State.vidas - 1
                    p.coop_travado = false
                    Coop.reviver(p)
                end
            elseif p.coop_timer >= Coop.RESPAWN_FRAMES and State.vidas > 0 then
                Coop.reviver(p)
            end
        end
    end

    if Coop.todos_mortos() then
        if State.vidas <= 0 then return "game_over" end
        return "resetar_fase"
    end
    return nil
end

-- Fim de ato: revive todo mundo SEM custo de vida. Se o pool zerou
-- mas alguem terminou vivo, o grupo volta com 1 vida.
function Coop.ao_concluir_ato(State)
    if not Coop.ativo then return end
    for _, p in ipairs(Coop.players) do
        if p.morto or p.coop_esperando then Coop.reviver(p) end
    end
    if State.vidas <= 0 then State.vidas = 1 end
end

-- Media dos vivos para a camera. Devolve nil se ninguem vivo.
function Coop.centro_vivos()
    local sx, sy, n = 0, 0, 0
    for _, p in ipairs(Coop.players) do
        if not p.morto and not p.coop_esperando then
            sx = sx + p.x
            sy = sy + p.y + 16
            n = n + 1
        end
    end
    if n == 0 then return nil end
    return sx / n, sy / n
end

-- Player vivo mais distante de um ponto (para o teleporte).
function Coop.mais_distante(cx, cy)
    local melhor, dist = nil, -1
    for _, p in ipairs(Coop.players) do
        if not p.morto and not p.coop_esperando then
            local dx, dy = p.x - cx, (p.y + 16) - cy
            local d = dx * dx + dy * dy
            if d > dist then dist = d; melhor = p end
        end
    end
    return melhor, math.sqrt(dist > 0 and dist or 0)
end

-- ============================================================
-- SETAS DE IDENTIFICACAO (botao Y = BTN_Q, por player)
-- ============================================================
local CORES_HEROI = {
    sonic = 0x7C00,  -- azul
    tails = 0x03FF,  -- amarelo
    knux  = 0x001F,  -- vermelho
    amy   = 0x515F,  -- rosa
    cream = 0x2A9C,  -- marrom claro
    rouge = 0x64B4,  -- roxo
}

Coop.setas = { false, false, false }

local cache_cor_setas = {}
local function cor_seta(hex)
    local c = cache_cor_setas[hex]
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
    cache_cor_setas[hex] = melhor
    return melhor
end

function Coop.toggle_setas()
    for i, p in ipairs(Coop.players) do
        if ui.btnp(BTN.Q, p.pad or 0) ~= false then
            Coop.setas[i] = not Coop.setas[i]
        end
    end
end

function Coop.draw_setas(cam_x, cam_y)
    if not Coop.ativo then return end
    for i, p in ipairs(Coop.players) do
        if Coop.setas[i] and not p.morto and not p.coop_esperando then
            local sx = math.floor(p.x - cam_x)
            local sy = math.floor(p.y - cam_y) - 22
            if sx > -20 and sx < 500 and sy > -20 and sy < 280 then
                local c = cor_seta(CORES_HEROI[p.heroi or "sonic"] or 0x7FFF)
                local preto = cor_seta(0x0000)
                -- seta apontando para baixo, com contorno
                ui.trisfill(sx, sy + 10, sx - 7, sy, sx + 7, sy, preto)
                ui.trisfill(sx, sy + 7, sx - 5, sy + 1, sx + 5, sy + 1, c)
                local label = "P" .. i
                local lx = sx - math.floor(#label * 6 / 2)
                ui.print(label, lx - 1, sy - 12, preto)
                ui.print(label, lx + 1, sy - 12, preto)
                ui.print(label, lx, sy - 13, preto)
                ui.print(label, lx, sy - 11, preto)
                ui.print(label, lx, sy - 12, c)
            end
        end
    end
end

return Coop
