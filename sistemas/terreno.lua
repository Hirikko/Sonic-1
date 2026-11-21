local Terreno = {}

local Dados = nil
local faixas = {}
local faixas_teto = {}
local segmentos = {}
local segmentos_teto = {}
local faixas_paredes = {}
local paredes_temporarias = {}

local abs = math.abs
local floor = math.floor
local min = math.min
local max = math.max
local FAIXA_X = 64

function Terreno.carregar(novos_dados)
    Dados = novos_dados
    faixas = {}
    faixas_teto = {}
    segmentos = {}
    segmentos_teto = {}
    faixas_paredes = {}
    paredes_temporarias = {}

    if not Dados then return end

    local function processar_lista(lista, segs, faixas_alvo)
        if not lista then return end
        for i = 1, #lista do
            local pontos = lista[i].pontos
            local x1, y1, x2, y2 = pontos[1], pontos[2], pontos[3], pontos[4]
            if x1 ~= x2 then
                local segmento = { x1 = x1, y1 = y1, x2 = x2, y2 = y2, inicio = min(x1, x2), fim = max(x1, x2), inclinacao = (y2 - y1) / (x2 - x1) }
                segs[#segs + 1] = segmento
                local primeira, ultima = floor(segmento.inicio / FAIXA_X), floor(segmento.fim / FAIXA_X)
                for faixa = primeira, ultima do
                    if not faixas_alvo[faixa] then faixas_alvo[faixa] = {} end
                    table.insert(faixas_alvo[faixa], segmento)
                end
            end
        end
    end

    processar_lista(Dados.superficies, segmentos, faixas)
    processar_lista(Dados.tetos, segmentos_teto, faixas_teto)

    if Dados and Dados.paredes then
        for i = 1, #Dados.paredes do
            local p = Dados.paredes[i]
            local primeira, ultima = floor(p.x / FAIXA_X), floor(p.x / FAIXA_X)
            for faixa = primeira, ultima do
                if not faixas_paredes[faixa] then faixas_paredes[faixa] = {} end
                table.insert(faixas_paredes[faixa], p)
            end
        end
    end
end

function Terreno.get_dados()
    return Dados
end

function Terreno.get_parallax()
    return Dados and Dados.parallax
end

function Terreno.adicionar_parede_temporaria(x, y1, y2)
    if not Dados then return end
    local parede = { x = x, y1 = y1, y2 = y2, temporaria = true }
    table.insert(Dados.paredes, parede)
    table.insert(paredes_temporarias, parede)
    local faixa = floor(x / FAIXA_X)
    if not faixas_paredes[faixa] then faixas_paredes[faixa] = {} end
    table.insert(faixas_paredes[faixa], parede)
end

function Terreno.remover_paredes_temporarias()
    if not Dados then return end
    for _, parede in ipairs(paredes_temporarias) do
        for i = #Dados.paredes, 1, -1 do
            if Dados.paredes[i] == parede then
                table.remove(Dados.paredes, i)
                break
            end
        end
        local faixa = floor(parede.x / FAIXA_X)
        local lista = faixas_paredes[faixa]
        if lista then
            for i = #lista, 1, -1 do
                if lista[i] == parede then
                    table.remove(lista, i)
                    break
                end
            end
        end
    end
    paredes_temporarias = {}
end

local function altura_segmento(segmento, x)
    if x < segmento.inicio or x > segmento.fim then return nil end
    return segmento.y1 + (x - segmento.x1) * segmento.inclinacao
end

local function segmentos_em(x) return faixas[floor(x / FAIXA_X)] end
local function segmentos_teto_em(x) return faixas_teto[floor(x / FAIXA_X)] end

function Terreno.altura(x, y_referencia)
    local lista = segmentos_em(x)
    if not lista then return nil, 0 end
    local melhor_y, melhor_inclinacao = nil, 0
    for _, segmento in ipairs(lista) do
        local y = altura_segmento(segmento, x)
        if y then
            local valido = true
            if y_referencia and abs(y - y_referencia) > 32 then valido = false end
            if valido and (not melhor_y or y < melhor_y) then
                melhor_y, melhor_inclinacao = y, segmento.inclinacao
            end
        end
    end
    return melhor_y, melhor_inclinacao
end

function Terreno.inclinacao(x, y_referencia) local _, inc = Terreno.altura(x, y_referencia); return inc end

function Terreno.altura_suporte(x, y_referencia, margem)
    margem = margem or 16
    local lista = segmentos_em(x)
    if not lista then return nil end
    local melhor_y, menor_distancia = nil, math.huge
    for _, segmento in ipairs(lista) do
        local y = altura_segmento(segmento, x)
        if y then
            local distancia = abs(y - y_referencia)
            if distancia <= margem and distancia < menor_distancia then
                melhor_y, menor_distancia = y, distancia
            end
        end
    end
    -- dentro de altura_suporte(x, y, margem):
    local y_sup = _suporte_em(x)
    if y_sup and y_sup >= y - (margem or 0) and y_sup <= y + (margem or 0) then
        return y_sup
    end
    -- dentro de aterrissagem(x, ya, yb, margem):
    local y_sup = _suporte_em(x)
    if y_sup and ya <= y_sup and yb >= y_sup then
        return y_sup
    end
    return melhor_y
end

function Terreno.suporte_info(x, y_referencia, margem)
    margem = margem or 16
    local lista = segmentos_em(x)
    if not lista then return nil end
    local melhor_y, melhor_segmento, menor_distancia = nil, nil, math.huge
    for _, segmento in ipairs(lista) do
        local y = altura_segmento(segmento, x)
        if y then
            local distancia = abs(y - y_referencia)
            if distancia <= margem and distancia < menor_distancia then
                melhor_y, melhor_segmento, menor_distancia = y, segmento, distancia
            end
        end
    end
    -- dentro de altura_suporte(x, y, margem):
    local y_sup = _suporte_em(x)
    if y_sup and y_sup >= y - (margem or 0) and y_sup <= y + (margem or 0) then
        return y_sup
    end
    -- dentro de aterrissagem(x, ya, yb, margem):
    local y_sup = _suporte_em(x)
    if y_sup and ya <= y_sup and yb >= y_sup then
        return y_sup
    end
    return melhor_y, melhor_segmento
end

function Terreno.aterrissagem(x, y_anterior, y_atual, margem)
    margem = margem or 10
    if y_atual < y_anterior then return nil end
    local lista = segmentos_em(x)
    if not lista then return nil end
    local melhor_y
    for _, segmento in ipairs(lista) do
        local y = altura_segmento(segmento, x)
        if y and y >= y_anterior - margem and y <= y_atual + margem then
            if not melhor_y or y < melhor_y then melhor_y = y end
        end
    end
    return melhor_y
end

function Terreno.colide_teto(x, y_anterior, y_atual)
    if y_atual >= y_anterior then return nil end
    local lista = segmentos_teto_em(x)
    if not lista then return nil end
    local melhor_y
    for _, segmento in ipairs(lista) do
        local y = altura_segmento(segmento, x)
        if y and y >= y_atual and y <= y_anterior then
            if not melhor_y or y > melhor_y then melhor_y = y end
        end
    end
    return melhor_y
end

local MAXIMO_DEGRAU = 24
local RAIO_HORIZONTAL_PLAYER = 10

-- ============================================================
-- SUPORTES DINÂMICOS (ponte falsa etc.)
-- Têm prioridade sobre o tilemap (ficam sobre buracos).
-- ============================================================
local suportes_dinamicos = {}

function Terreno.limpar_suportes_dinamicos()
    suportes_dinamicos = {}
end

function Terreno.adicionar_suporte(x, y, w, h, id)
    local s = { x = x, y = y, w = w, h = h, ativo = true, id = id }
    table.insert(suportes_dinamicos, s)
    return s
end

function Terreno.remover_suporte(s)
    if s then s.ativo = false end
end

-- Retorna o Y do topo do suporte mais alto cobrindo x, ou nil.
-- "mais alto" = menor Y (topo).
local function _suporte_em(x)
    local melhor = nil
    for _, s in ipairs(suportes_dinamicos) do
        if s.ativo and x >= s.x and x < s.x + s.w then
            if not melhor or s.y < melhor then melhor = s.y end
        end
    end
    return melhor
end

local function limitar_parede(x_anterior, x_novo, pes_y, altura_player)
    if not Dados or not Dados.paredes then return x_novo, false end
    local topo, baixo = pes_y - altura_player, pes_y
    local menor_x, maior_x = min(x_anterior, x_novo), max(x_anterior, x_novo)

    local faixa_ini = floor(menor_x / FAIXA_X)
    local faixa_fim = floor(maior_x / FAIXA_X)

    for f = faixa_ini, faixa_fim do
        local paredes = faixas_paredes[f]
        if paredes then
            for i = 1, #paredes do
                local parede = paredes[i]
                local dentro_vertical = baixo > parede.y1 + 2 and topo < parede.y2
                if dentro_vertical and menor_x <= parede.x and maior_x >= parede.x then
                    if x_novo > x_anterior then return parede.x - RAIO_HORIZONTAL_PLAYER, true end
                    if x_novo < x_anterior then return parede.x + RAIO_HORIZONTAL_PLAYER, true end
                end
            end
        end
    end
    return x_novo, false
end

function Terreno.movimento_horizontal(x_anterior, x_novo, pes_y, altura_player)
    local x_limitado, bateu = limitar_parede(x_anterior, x_novo, pes_y, altura_player)
    x_novo = x_limitado
    if bateu then return x_novo, nil, true end
    local altura_anterior = Terreno.altura_suporte(x_anterior, pes_y)
    local altura_nova = Terreno.altura_suporte(x_novo, pes_y)
    if not altura_anterior or not altura_nova then return x_novo, nil, false end
    local diferenca = altura_nova - altura_anterior
    if diferenca > MAXIMO_DEGRAU then return x_novo, nil, false end
    return x_novo, altura_nova, false
end

function Terreno.colide_dano(x, y, largura, altura)
    if not Dados or not Dados.danos then return false end
    local direita, baixo = x + largura, y + altura
    for i = 1, #Dados.danos do
        local d = Dados.danos[i]
        if x < d.x + d.largura and direita > d.x and y < d.y + d.altura and baixo > d.y then return true end
    end
    return false
end

function Terreno.colide_joga(x, y, largura, altura)
    if not Dados or not Dados.joga then return false end
    local direita, baixo = x + largura, y + altura
    for i = 1, #Dados.joga do
        local j = Dados.joga[i]
        if x < j.x + j.largura and direita > j.x and y < j.y + j.altura and baixo > j.y then return true end
    end
    return false
end

function Terreno.colide_mola(x, y, largura, altura)
    if not Dados or not Dados.molas then return false end
    local direita, baixo = x + largura, y + altura
    for i = 1, #Dados.molas do
        local m = Dados.molas[i]
        if x < m.x + m.largura and direita > m.x and y < m.y + m.altura and baixo > m.y then return true end
    end
    return false
end

function Terreno.colide_projetil(x, y, w, h)
    if not Dados then return false end
    if Dados.paredes then
        local topo, baixo = y, y + h
        local esq, dir = x, x + w
        local faixa_ini = floor(esq / FAIXA_X)
        local faixa_fim = floor(dir / FAIXA_X)
        for f = faixa_ini, faixa_fim do
            local paredes = faixas_paredes[f]
            if paredes then
                for i = 1, #paredes do
                    local p = paredes[i]
                    if dir > p.x and esq < p.x and baixo > p.y1 and topo < p.y2 then return true end
                end
            end
        end
    end
    local cx = x + w * 0.5
    local chao = Terreno.altura_suporte(cx, y + h, 48)
    if chao and (y + h) >= chao then return true end
    return false
end

function Terreno.get_areas_agua() return Dados and Dados.areas_agua or {} end
function Terreno.get_sensores_queda() return Dados and Dados.sensores_queda or {} end
function Terreno.get_molas() return Dados and Dados.molas or {} end
function Terreno.get_aneis() return Dados and Dados.aneis or {} end
function Terreno.get_spawn() return Dados and Dados.spawn_x or 100, Dados and Dados.spawn_y or 240 end

return Terreno
