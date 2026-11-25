local SpritesAnim = {}

local ANIMACOES = {
        -- Sonic (mantém)
        parado           = { pasta = "parado",          frames = 1,  cadencia = 1,  loop = false,   frame_fixo = 1 },
        esperar          = { pasta = "esperar",         frames = 3,  cadencia = 30, loop = true },
        andar            = { pasta = "andar",           frames = 6,  cadencia = 8,  loop = true },
        correr           = { pasta = "correr",          frames = 4,  cadencia = 4,  loop = true },
        rodar            = { pasta = "rodar",           frames = 5,  cadencia = 6,  loop = true },
        pular            = { pasta = "rodar",           frames = 5,  cadencia = 6,  loop = true },
        pula_mola        = { pasta = "pula_mola",       frames = 1,  cadencia = 1,  loop = false,   frame_fixo = 1 },
        olha_cima        = { pasta = "olha_cima",       frames = 1,  cadencia = 1,  loop = false,   frame_fixo = 1 },
        olha_baixo       = { pasta = "olha_baixo",      frames = 1,  cadencia = 1,  loop = false,   frame_fixo = 1 },
        dano             = { pasta = "dano",            frames = 1,  cadencia = 1,  loop = false,   frame_fixo = 1 },
        morre            = { pasta = "morre",           frames = 1,  cadencia = 1,  loop = false,   frame_fixo = 1 },
        afogado          = { pasta = "afogado",         frames = 1,  cadencia = 1,  loop = false,   frame_fixo = 1 },
        ar               = { pasta = "ar",              frames = 1,  cadencia = 1,  loop = false,   frame_fixo = 1 },
        vira_rapido      = { pasta = "vira_rapido",     frames = 1,  cadencia = 1,  loop = false,   frame_fixo = 1 },
        escudo_ativado   = { pasta = "escudo_ativado",  frames = 10, cadencia = 1,  loop = false },
        aneis            = { pasta = "objetos/aneis",   frames = 6,  cadencia = 1,  loop = false },

        -- Título
        titulo = { pasta = "titulo", frames = 2, cadencia = 20, loop = true },
        titulo_botao = { pasta = "titulo/botao/iniciar", frames = 1, cadencia = 1, loop = false, frame_fixo = 1 },

        -- Inimigos
        motobug_anda   = { pasta = "inimigos/motobug",            frames = 2, cadencia = 8,  loop = true },
        crabghz_anda   = { pasta = "inimigos/crab-ghz/andar",     frames = 3, cadencia = 10, loop = true },
        crabghz_ataq   = { pasta = "inimigos/crab-ghz/ataq",      frames = 1, cadencia = 1,  loop = false,  frame_fixo = 1 },
        crabjz_anda    = { pasta = "inimigos/crab-jz/andar",      frames = 3, cadencia = 10, loop = true },
        crabjz_ataq    = { pasta = "inimigos/crab-jz/ataq",       frames = 1, cadencia = 1,  loop = false,  frame_fixo = 1 },
        buzz_anda      = { pasta = "inimigos/buzz/andar",         frames = 2, cadencia = 6,  loop = true },
        buzz_ataq      = { pasta = "inimigos/buzz/ataq",          frames = 2, cadencia = 6,  loop = true },
        bala           = { pasta = "inimigos/balas",              frames = 2, cadencia = 6,  loop = true },
        explode        = { pasta = "inimigos/explode",            frames = 3, cadencia = 5,  loop = false },
        burr_anda      = { pasta = "inimigos/burr/andar",         frames = 2, cadencia = 8,  loop = true },
        burr_ataq      = { pasta = "inimigos/burr/ataq",          frames = 1, cadencia = 1,  loop = false,  frame_fixo = 1 },
        cater_anda     = { pasta = "inimigos/cater/andar",        frames = 3, cadencia = 10, loop = true },
        cater_cabeca   = { pasta = "inimigos/cater/cabeca",       frames = 1, cadencia = 1,  loop = false,  frame_fixo = 1 },
        cater_segmento = { pasta = "inimigos/cater/ataq",         frames = 1, cadencia = 1,  loop = false,  frame_fixo = 1 },
        ballhog_anda    = { pasta = "inimigos/ballhog/andar",     frames = 2, cadencia = 10, loop = true },
        ballhog_ataq    = { pasta = "inimigos/ballhog/ataq",      frames = 1, cadencia = 1,  loop = false, frame_fixo = 1 },
        ballhog_bala    = { pasta = "inimigos/ballhog/ataq/bala", frames = 1, cadencia = 1,  loop = false, frame_fixo = 1 },
        statue_anda     = { pasta = "inimigos/statue/corpo",      frames = 1, cadencia = 1,  loop = false, frame_fixo = 1 },
        statue_ataq     = { pasta = "inimigos/statue/ataq",       frames = 1, cadencia = 1,  loop = false, frame_fixo = 1 },
        bomb_anda       = { pasta = "inimigos/bomb/andar",   frames = 2, cadencia = 8,  loop = true },
        bomb_ataq       = { pasta = "inimigos/bomb/ataq",    frames = 2, cadencia = 6,  loop = true },
        neutron_anda    = { pasta = "inimigos/neutron/andar",      frames = 1, cadencia = 1,  loop = false, frame_fixo = 1 },
        neutron_fade    = { pasta = "inimigos/neutron/fade", frames = 3, cadencia = 5,  loop = false },
        orbo_anda    = { pasta = "inimigos/orbo/andar", frames = 1, cadencia = 1, loop = false, frame_fixo = 1 },
        orbo_orbita  = { pasta = "inimigos/orbo/ataq",  frames = 1, cadencia = 1, loop = false, frame_fixo = 1 },
        jaws_anda    = { pasta = "inimigos/jaws/andar", frames = 1, cadencia = 1, loop = false, frame_fixo = 1 },
        jaws_ataq    = { pasta = "inimigos/jaws/ataq",  frames = 1, cadencia = 1, loop = false, frame_fixo = 1 },
        chopper_anda = { pasta = "inimigos/chopper", frames = 2, cadencia = 8, loop = true },
        spikes_anda  = { pasta = "inimigos/spikes",  frames = 2, cadencia = 10, loop = true },
        spike_ball_anda = { pasta = "inimigos/spike-ball", frames = 1, cadencia = 1, loop = false, frame_fixo = 1 },

        -- Chefes
        chefe_gh3_andar  = { pasta = "inimigos/chefes/gh3/andar",  frames = 2, cadencia = 1, loop = false, },
        chefe_gh3_ataq   = { pasta = "inimigos/chefes/gh3/ataq",   frames = 1, cadencia = 1, loop = false, frame_fixo = 1 },
        chefe_gh3_doeu   = { pasta = "inimigos/chefes/gh3/doeu",   frames = 1, cadencia = 1, loop = false, frame_fixo = 1 },
        chefe_gh3_perdeu = { pasta = "inimigos/chefes/gh3/perdeu", frames = 2, cadencia = 8, loop = true },

        -- Monitores (estática = f1 + fX alternando; fX = efeito)
        monitor_anel          = { pasta = "objetos/monitores",   frames = 1, cadencia = 1, loop = false, frame_fixo = 1 },
        monitor_sapato_rapido = { pasta = "objetos/monitores",   frames = 1, cadencia = 1, loop = false, frame_fixo = 1 },
        monitor_vida          = { pasta = "objetos/monitores",   frames = 1, cadencia = 1, loop = false, frame_fixo = 1 },
        monitor_escudo        = { pasta = "objetos/monitores",   frames = 1, cadencia = 1, loop = false, frame_fixo = 1 },
        monitor_invenc        = { pasta = "objetos/monitores",   frames = 1, cadencia = 1, loop = false, frame_fixo = 1 },
        monitor_salva         = { pasta = "objetos/monitores",   frames = 1, cadencia = 1, loop = false, frame_fixo = 1 },
        monitor_cont          = { pasta = "objetos/monitores",   frames = 1, cadencia = 1, loop = false, frame_fixo = 1 },

        -- Placas (giro: girar/f1..f3; resultado: f1..f5)
        placa_giro     = { pasta = "objetos/placa_final/girar",  frames = 3, cadencia = 8, loop = true },
        placa_normal   = { pasta = "objetos/placa_final",        frames = 1, cadencia = 1, loop = false, frame_fixo = 1 },
        placa_especial = { pasta = "objetos/placa_final",        frames = 1, cadencia = 1, loop = false, frame_fixo = 2 },
        placa_aneis    = { pasta = "objetos/placa_final",        frames = 1, cadencia = 1, loop = false, frame_fixo = 3 },
        placa_vida     = { pasta = "objetos/placa_final",        frames = 1, cadencia = 1, loop = false, frame_fixo = 4 },
        placa_chefe    = { pasta = "objetos/placa_final",        frames = 1, cadencia = 1, loop = false, frame_fixo = 5 },
    }

SpritesAnim.ANIMACOES = ANIMACOES

-- Navega em árvore: partes = {"inimigos", "motobug", "f1"}
local function buscar_em_arvore(raiz, partes)
    local atual = raiz
    for _, parte in ipairs(partes) do
        if type(atual) ~= "table" then return nil end
        atual = atual[parte]
        if atual == nil then return nil end
    end
    return atual
end

-- Tenta múltiplos formatos até achar o sprite
local function resolver_frame_robusto(raiz, pasta, frame)
    -- 1) Chave flat com barra
    if raiz[pasta .. "/" .. frame] then return raiz[pasta .. "/" .. frame] end

    -- 2) Árvore: pasta / frame
    local partes = {}
    for p in pasta:gmatch("[^/]+") do partes[#partes + 1] = p end
    table.insert(partes, frame)

    local via_arvore = buscar_em_arvore(raiz, partes)
    if via_arvore then return via_arvore end

    -- 3) assets.pasta
    if type(raiz.assets) == "table" then
        local via_assets = buscar_em_arvore(raiz.assets, partes)
        if via_assets then return via_assets end
    end

    -- 4) Tenta com prefixo "assets/" em flat
    if raiz["assets/" .. pasta .. "/" .. frame] then return raiz["assets/" .. pasta .. "/" .. frame] end

    return nil
end
-- Estados de animacao do PERSONAGEM: resolvidos em herois/<heroi>/<pasta>.
-- escudo_ativado ficou FORA porque se divide: f1..f8 compartilhado em
-- objetos/, f9+ (aura) por heroi.
local HEROI_ESTADOS = {
    parado=true, esperar=true, andar=true, correr=true, rodar=true, pular=true,
    pula_mola=true, olha_cima=true, olha_baixo=true, dano=true, morre=true,
    afogado=true, ar=true, vira_rapido=true,
}

-- Cache por heroi: o mesmo estado/frame resolve em arquivos diferentes.
local cache_sprites = {}

function SpritesAnim.sprite(estado, frame, heroi)
    heroi = heroi or "sonic"
    local f = frame or 1

    local cache_h = cache_sprites[heroi]
    if cache_h and cache_h[estado] and cache_h[estado][f] then
        return cache_h[estado][f]
    end

    local configuracao = ANIMACOES[estado]
    if not configuracao then return nil, "animação desconhecida: " .. tostring(estado) end
    local raiz = _G.Sprites
    if type(raiz) ~= "table" then return nil, "_G.Sprites ausente ou inválido" end

    local frame_nome = "f" .. tostring(f)
    local sprite = nil

    if HEROI_ESTADOS[estado] then
        local base = "herois/" .. heroi .. "/" .. configuracao.pasta
        sprite = resolver_frame_robusto(raiz, base, frame_nome)
        -- Rede de seguranca: se o heroi tem a pasta mas falta esse frame
        -- (ex.: amy/andar so vai ate f5), usa f1 do PROPRIO heroi em vez
        -- de mostrar o Sonic no meio da animacao dele.
        if not sprite and f ~= 1 then
            sprite = resolver_frame_robusto(raiz, base, "f1")
        end
        -- Sem a pasta nenhuma (ex.: amy nao tem dano/): cai no Sonic.
        if not sprite and heroi ~= "sonic" then
            sprite = resolver_frame_robusto(raiz, "herois/sonic/" .. configuracao.pasta, frame_nome)
        end

    elseif estado == "escudo_ativado" then
        if f <= 8 then
            sprite = resolver_frame_robusto(raiz, "objetos/escudo_ativado", frame_nome)
        else
            sprite = resolver_frame_robusto(raiz, "herois/" .. heroi .. "/escudo_ativado", frame_nome)
            if not sprite and heroi ~= "sonic" then
                sprite = resolver_frame_robusto(raiz, "herois/sonic/escudo_ativado", frame_nome)
            end
        end

    elseif estado == "titulo" then
        sprite = resolver_frame_robusto(raiz, "titulo", frame_nome)
        if not sprite and type(raiz.titulo) == "table" then
            sprite = raiz.titulo[frame_nome]
        end

    else
        sprite = resolver_frame_robusto(raiz, configuracao.pasta, frame_nome)
    end

    if sprite then
        if not cache_h then cache_h = {}; cache_sprites[heroi] = cache_h end
        if not cache_h[estado] then cache_h[estado] = {} end
        cache_h[estado][f] = sprite
    end

    return sprite
end

-- ============================================================
-- FRAMES POR HEROI
-- Alguns herois tem contagem diferente do padrao do ANIMACOES
-- (amy/andar tem 5, sonic tem 6). Sondagem automatica: conta os
-- fN que existem na pasta do heroi. Cache por heroi+estado, roda
-- uma vez so. Sao apenas leituras de tabela, nao carregam asset.
-- ============================================================
local MAX_FRAMES_PROBE = 16
local cache_frames = {}

function SpritesAnim.frames(estado, heroi)
    heroi = heroi or "sonic"
    local ch = cache_frames[heroi]
    if not ch then ch = {}; cache_frames[heroi] = ch end
    if ch[estado] then return ch[estado] end

    local cfg = ANIMACOES[estado]
    local n = (cfg and cfg.frames) or 1

    if cfg and HEROI_ESTADOS[estado] then
        local raiz = _G.Sprites
        if type(raiz) == "table" then
            local base = "herois/" .. heroi .. "/" .. cfg.pasta
            local cont = 0
            for i = 1, MAX_FRAMES_PROBE do
                if resolver_frame_robusto(raiz, base, "f" .. i) then
                    cont = i
                else
                    break
                end
            end
            -- cont == 0: heroi sem a pasta. Mantem o padrao, e o
            -- resolver de sprite cai no Sonic pelo fallback.
            if cont > 0 then n = cont end
        end
    end

    ch[estado] = n
    return n
end

-- Resolver publico de caminho completo, para os modulos de UI que
-- buscam assets fora do ANIMACOES (obj_ui, fundo, sel_heroi...).
function SpritesAnim.asset(caminho)
    local raiz = _G.Sprites
    if type(raiz) ~= "table" then return nil end
    if raiz[caminho] then return raiz[caminho] end
    if raiz[caminho .. ".png"] then return raiz[caminho .. ".png"] end
    local partes = {}
    for p in caminho:gmatch("[^/]+") do partes[#partes + 1] = p end
    local via = buscar_em_arvore(raiz, partes)
    if via then return via end
    if type(raiz.assets) == "table" then
        via = buscar_em_arvore(raiz.assets, partes)
        if via then return via end
    end
    return raiz["assets/" .. caminho] or raiz["assets/" .. caminho .. ".png"]
end

return SpritesAnim
