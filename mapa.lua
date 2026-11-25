local Terreno = require("sistemas.terreno")

local Mapa = {
    largura = 0,
    altura = 0,
    carregando = false,
    fila_chunks = {}
}

local Gh_Atual = nil
local TILE_SIZE = 16
local MAP_WIDTH = 0
local MAP_HEIGHT = 0
local CHUNK_W = 32
local CHUNK_H = 32

local CHUNKS_POR_FRAME = 4

-- Parallax: valores padrão globais
local PADRAO_PARALLAX = {
    x = 0.5,
    y = 0.5,
    offset_x = 0,
    offset_y = -11
}

-- Configuração ativa (preenchida em Mapa.preparar)
local parallax_cfg = {
    x = PADRAO_PARALLAX.x,
    y = PADRAO_PARALLAX.y,
    offset_x = PADRAO_PARALLAX.offset_x,
    offset_y = PADRAO_PARALLAX.offset_y
}

local chunks = { fundo = {}, chao = {}, objetos = {}, deco = {}, agua = {} }
local tilesets_por_camada = { fundo = {}, chao = {}, objetos = {}, deco = {}, agua = {} }
-- ============================================================
-- TILESETS ANIMADOS (Bridge Zone)
-- O codec gera _tilesets como nome -> NOME DO ASSET (string),
-- não como objeto de sprite. A engine resolve o nome no ui.map.
-- Portanto a animação troca STRING por STRING.
-- As CHAVES nunca mudam (são o que os dados das camadas usam),
-- então os GIDs continuam válidos e os chunks já gerados — que
-- compartilham a mesma tabela _tilesets — desenham o novo frame
-- sem precisar de reconstrução.
-- ============================================================
local ANIM_TILESETS = {
    -- gh_tile_f1   = { "gh_tile_f1", "gh_tile_f2", "gh_tile_f3" },
    bd_tile_f1_1 = { "bd_tile_f1_1", "bd_tile_f2_1", "bd_tile_f3_1" },
    bd_tile_f1_2 = { "bd_tile_f1_2", "bd_tile_f2_2", "bd_tile_f3_2" },

    --[[ PROXIMAS ZONAS — descomentar quando o mapa usar esses tilesets.
    A CHAVE e o nome do tileset no Tiled; confira no .lua gerado
    (local _tilesets = { ["nome"] = "nome" }) antes de ligar.

    jz_tile_f1   = { "jz_tile_f1", "jz_tile_f2", "jz_tile_f3" },
    lz_tile_f1   = { "lz_tile_f1", "lz_tile_f2", "lz_tile_f3", "lz_tile_f4" },
    sb_tile_f1   = { "sb_tile_f1", "sb_tile_f2", "sb_tile_f3", "sb_tile_f4" },
    sbz_tile_f1  = { "sbz_tile_f1", "sbz_tile_f2", "sbz_tile_f3", "sbz_tile_f4",
    "sbz_tile_f5", "sbz_tile_f6", "sbz_tile_f7", "sbz_tile_f8" },
    sbz3_tile_f1 = { "sbz3_tile_f1", "sbz3_tile_f2", "sbz3_tile_f3", "sbz3_tile_f4" },
    ]]--
}

local ANIM_CADENCIA = 8      -- 60/8 = 7,5 fps por frame de tile
local anim_timer  = 0
local anim_frame  = 1
local anim_ativos = nil

local function preparar_animacao()
    anim_timer  = 0
    anim_frame  = 1
    anim_ativos = nil
    local ts = Gh_Atual and Gh_Atual.tilesets
    if type(ts) ~= "table" then return end
    local lista = {}
    for chave, nomes in pairs(ANIM_TILESETS) do
        if ts[chave] ~= nil then
            lista[#lista + 1] = { chave = chave, nomes = nomes }
        end
    end
    if #lista > 0 then anim_ativos = lista end
end

local function atualizar_animacao()
    if not anim_ativos then return end
    anim_timer = anim_timer + 1
    if anim_timer < ANIM_CADENCIA then return end
    anim_timer = 0
    anim_frame = anim_frame + 1
    if anim_frame > #anim_ativos[1].nomes then anim_frame = 1 end
    local ts = Gh_Atual and Gh_Atual.tilesets
    if type(ts) ~= "table" then return end
    for _, a in ipairs(anim_ativos) do
        ts[a.chave] = a.nomes[anim_frame]
    end
end

function Mapa.preparar(caminho_json)
    chunks = { fundo = {}, chao = {}, objetos = {}, deco = {}, agua = {} }
    tilesets_por_camada = { fundo = {}, chao = {}, objetos = {}, deco = {}, agua = {} }
    Mapa.fila_chunks = {}

    -- NOVO: Lê o parallax do terreno (se existir)
    local parallax_terreno = Terreno.get_parallax()
    parallax_cfg.x = (parallax_terreno and parallax_terreno.x) or PADRAO_PARALLAX.x
    parallax_cfg.y = (parallax_terreno and parallax_terreno.y) or PADRAO_PARALLAX.y
    parallax_cfg.offset_x = (parallax_terreno and parallax_terreno.offset_x) or PADRAO_PARALLAX.offset_x
    parallax_cfg.offset_y = (parallax_terreno and parallax_terreno.offset_y) or PADRAO_PARALLAX.offset_y

    Gh_Atual = require(caminho_json)

    TILE_SIZE = Gh_Atual.metadata.tile_size
    MAP_WIDTH = Gh_Atual.metadata.width
    MAP_HEIGHT = Gh_Atual.metadata.height

    Mapa.largura = MAP_WIDTH * TILE_SIZE
    Mapa.altura = MAP_HEIGHT * TILE_SIZE

    local camadas = {"fundo", "chao", "objetos", "deco", "agua"}
    for _, nome_camada in ipairs(camadas) do
        local camada = Gh_Atual[nome_camada]
        if camada then
            chunks[nome_camada] = {}
            tilesets_por_camada[nome_camada] = {}
            for tileset, data in pairs(camada) do
                local tabela_tileset = {}
                chunks[nome_camada][tileset] = tabela_tileset
                table.insert(tilesets_por_camada[nome_camada], tabela_tileset)

                local num_chunks_x = math.ceil(MAP_WIDTH / CHUNK_W)
                local num_chunks_y = math.ceil(MAP_HEIGHT / CHUNK_H)

                for cx = 0, num_chunks_x - 1 do
                    for cy = 0, num_chunks_y - 1 do
                        table.insert(Mapa.fila_chunks, {
                            nome_camada = nome_camada,
                            tileset = tileset,
                            data = data,
                            cx = cx,
                            cy = cy,
                            tabela_tileset = tabela_tileset,
                        })
                    end
                end
            end
        end
    end

    Mapa.carregando = (#Mapa.fila_chunks > 0)
    preparar_animacao()
end

local function processar_chunk(tarefa)
    local cx, cy, data = tarefa.cx, tarefa.cy, tarefa.data
    local start_col = cx * CHUNK_W
    local end_col = math.min(MAP_WIDTH - 1, start_col + CHUNK_W - 1)
    local start_row = cy * CHUNK_H
    local end_row = math.min(MAP_HEIGHT - 1, start_row + CHUNK_H - 1)

    local col_count = end_col - start_col + 1
    local row_count = end_row - start_row + 1
    local chunk_data = {}
    local tem_tile = false

    for y = start_row, end_row do
        local base_original = y * MAP_WIDTH
        local base_chunk = (y - start_row) * col_count
        for x = start_col, end_col do
            local original_index = base_original + x + 1
            local tile = data[original_index]
            if tile and tile ~= 0 then
                chunk_data[base_chunk + (x - start_col) + 1] = tile
                tem_tile = true
            end
        end
    end

    if not tem_tile then
        return
    end

    local tabela = tarefa.tabela_tileset
    if not tabela[cx] then
        tabela[cx] = {}
    end

    tabela[cx][cy] = {
        data = chunk_data,
        width = col_count,
        height = row_count,
        start_col = start_col,
        start_row = start_row,
        map_data = {
            metadata = { width = col_count, height = row_count, tile_size = TILE_SIZE },
            tilesets = Gh_Atual.tilesets,
            [tarefa.tileset] = chunk_data
        }
    }
end

function Mapa.update()
    atualizar_animacao()
    if not Mapa.carregando then return end

    for _ = 1, CHUNKS_POR_FRAME do
        local tarefa = table.remove(Mapa.fila_chunks, 1)
        if not tarefa then
            Mapa.carregando = false
            return
        end
        processar_chunk(tarefa)
    end
end

function Mapa.get_tilesets()
    return Gh_Atual and Gh_Atual.tilesets or {}
end

-- vw/vh opcionais: janela de desenho. Sem eles, tela cheia (480x270).
-- O preview de brilho e o futuro split-screen passam a janela real,
-- senao cada vista emite chunks para 4x a area visivel e o drawlist
-- estoura (teto de 18432 bytes).
local function desenhar_camada(nome, cam_x, cam_y, vw, vh)
    local tilesets = tilesets_por_camada[nome]
    if not tilesets or #tilesets == 0 or not Gh_Atual then return end
    vw = vw or 480
    vh = vh or 270

    local start_col = math.floor(-cam_x / TILE_SIZE)
    local end_col = math.ceil((-cam_x + vw) / TILE_SIZE)
    local start_row = math.floor(-cam_y / TILE_SIZE)
    local end_row = math.ceil((-cam_y + vh) / TILE_SIZE)

    local start_cx = math.max(0, math.floor(start_col / CHUNK_W))
    local end_cx = math.min(math.ceil(MAP_WIDTH / CHUNK_W) - 1, math.floor(end_col / CHUNK_W))
    local start_cy = math.max(0, math.floor(start_row / CHUNK_H))
    local end_cy = math.min(math.ceil(MAP_HEIGHT / CHUNK_H) - 1, math.floor(end_row / CHUNK_H))

    local num_tilesets = #tilesets
    for cx = start_cx, end_cx do
        for cy = start_cy, end_cy do
            for i = 1, num_tilesets do
                local cx_table = tilesets[i]
                if cx_table then
                    local cy_table = cx_table[cx]
                    if cy_table then
                        local chunk = cy_table[cy]
                        if chunk then
                            ui.map(chunk.map_data, cam_x + (chunk.start_col * TILE_SIZE), cam_y + (chunk.start_row * TILE_SIZE))
                        end
                    end
                end
            end
        end
    end
end

function Mapa.get_areas_agua() return Terreno.get_areas_agua() end

-- Fundo com parallax: usa a configuração ativa (lida do terreno ou padrão)
function Mapa.draw_fundo(cam_x, cam_y, vw, vh)
local fx = cam_x * parallax_cfg.x + parallax_cfg.offset_x
local fy = cam_y * parallax_cfg.y + parallax_cfg.offset_y
desenhar_camada("fundo", fx, fy, vw, vh)
end

function Mapa.draw_chao(cam_x, cam_y, vw, vh) desenhar_camada("chao", cam_x, cam_y, vw, vh) end
function Mapa.draw_objetos(cam_x, cam_y, vw, vh) desenhar_camada("objetos", cam_x, cam_y, vw, vh) end
function Mapa.draw_agua(cam_x, cam_y, vw, vh) desenhar_camada("agua", cam_x, cam_y, vw, vh) end
function Mapa.draw_deco(cam_x, cam_y, vw, vh) desenhar_camada("deco", cam_x, cam_y, vw, vh) end

function Mapa.altura_chao(x) return Terreno.altura(x) end
function Mapa.altura_suporte(x, y, margem) return Terreno.altura_suporte(x, y, margem) end
function Mapa.suporte_info(x, y, margem) return Terreno.suporte_info(x, y, margem) end
function Mapa.aterrissagem(x, ya, yb, margem) return Terreno.aterrissagem(x, ya, yb, margem) end
function Mapa.colide_teto(x, y_ant, y_atual) return Terreno.colide_teto(x, y_ant, y_atual) end
function Mapa.movimento_horizontal(x, y, z, w) return Terreno.movimento_horizontal(x, y, z, w) end
function Mapa.inclinacao(x, y) return Terreno.inclinacao(x, y) end
function Mapa.colide_dano(x, y, w, h) return Terreno.colide_dano(x, y, w, h) end
function Mapa.colide_joga(x, y, w, h) return Terreno.colide_joga(x, y, w, h) end
function Mapa.colide_mola(x, y, w, h) return Terreno.colide_mola(x, y, w, h) end
function Mapa.colide_projetil(x, y, w, h) return Terreno.colide_projetil(x, y, w, h) end
function Mapa.get_aneis() return Terreno.get_aneis() end
function Mapa.get_molas() return Terreno.get_molas() end
function Mapa.get_sensores_queda() return Terreno.get_sensores_queda() end
function Mapa.limitar_x(x) return math.max(0, math.min(x, Mapa.largura - 16)) end
function Mapa.get_spawn() return Terreno.get_spawn() end

return Mapa
