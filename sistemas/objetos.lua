local Objetos = {}
local Mapa = require("mapa")
local PlayerSys = require("sistemas.player")
local Sprites = require("sistemas.sprites")
local Timer = require("sistemas.timer")
local State = require("state")

local GRAVIDADE = 0.0090
local AMORTECIMENTO = 1.0
local LARGURA_PLATAFORMA = 16

local MONITOR_FRAME = {
    monitor_anel = 2,
    monitor_sapato_rapido = 3,
    monitor_vida = 4,
    monitor_escudo = 5,
    monitor_invenc = 6,
    monitor_salva = 7,
    monitor_cont = 8,
}

local monitor_estatica_fase = 1
local monitor_estatica_timer = 0
local MONITOR_ESTATICA_CADENCIA = 30

-- NOVO: caches de sprite (preenchidos lazy na primeira chamada)
local cache_monitor = {}     -- [frame] -> sprite
local cache_placa = {}       -- [estado][frame] -> sprite
local cache_esmeralda = nil  -- sprite único

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

local function sprite_esmeralda()
    if cache_esmeralda then return cache_esmeralda end
    cache_esmeralda = Sprites.sprite("esmeralda", 1)
    return cache_esmeralda
end

function Objetos.init(dados_terreno)
    Objetos.lista = {}
    Objetos.outros = {}
    Objetos.plataformas = {}
    Objetos.esmeraldas = {}
    Objetos.placa = nil

    -- Limpa caches entre fases (evita referência a sprites antigos se Sprites recarregar)
    cache_monitor = {}
    cache_placa = {}
    cache_esmeralda = nil

    Objetos.map_plataforma = {
        metadata = { width = 2, height = 1, tile_size = 16 },
        tilesets = Mapa.get_tilesets(),
        licgrenhll = { 130, 130 }
    }

    if not dados_terreno then return end

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
        if pl.x > pl.x_inicial + pl.amplitude then pl.direcao = -1
        elseif pl.x < pl.x_inicial - pl.amplitude then pl.direcao = 1 end
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
        end
    end

    if State.placa and State.placa.ativa then
        State.placa.timer = State.placa.timer + 1
        if State.placa.timer <= 60 then
            State.placa.y = State.placa.y - 1.5
        elseif State.placa.timer <= 90 then
        elseif State.placa.timer <= 150 then
            State.placa.y = State.placa.y + 1.5
        else
            State.resultado = "vitoria"
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

function Objetos._iniciar_placa_final(o, state_ref)
    state_ref.placa.ativa = true
    state_ref.placa.x = o.x
    state_ref.placa.y = o.y
    state_ref.placa.timer = 0

    local aneis = state_ref.inventory.aneis or 0
    local tempo_segundos = Timer.segundos
    state_ref.tempo_final = tempo_segundos

    local bonus_aneis = aneis * 100
    state_ref.bonus_aneis = bonus_aneis

    local bonus_tempo = 0
    if tempo_segundos <= 19 then bonus_tempo = 300000
    elseif tempo_segundos == 20 then bonus_tempo = 200000
    elseif tempo_segundos == 21 then bonus_tempo = 100000
    elseif tempo_segundos == 22 then bonus_tempo = 80000
    elseif tempo_segundos == 23 then bonus_tempo = 50000
    elseif tempo_segundos == 24 then bonus_tempo = 40000
    elseif tempo_segundos >= 25 and tempo_segundos <= 29 then bonus_tempo = 30000
    elseif tempo_segundos >= 30 and tempo_segundos <= 59 then bonus_tempo = 10000
    elseif tempo_segundos >= 60 and tempo_segundos <= 89 then bonus_tempo = 5000
    elseif tempo_segundos >= 90 and tempo_segundos <= 119 then bonus_tempo = 3000
    elseif tempo_segundos >= 120 and tempo_segundos <= 149 then bonus_tempo = 1000
    elseif tempo_segundos >= 150 and tempo_segundos <= 179 then bonus_tempo = 500
    elseif tempo_segundos >= 180 and tempo_segundos <= 299 then bonus_tempo = 100
    end
    state_ref.bonus_tempo = bonus_tempo

    state_ref.pontuacao = state_ref.pontuacao + bonus_aneis + bonus_tempo

    if aneis >= 50 then
        state_ref.placa.resultado = "placa_especial"
    elseif aneis >= 11 and aneis <= 19 then
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
    if Objetos.lista then
        for _, p in ipairs(Objetos.lista) do
            local ax, ay = p.x - cam_x, p.y - cam_y
            local px, py = p.x_plataforma - cam_x, p.y_plataforma - cam_y
            ui.line(ax, ay, px, py, 0)
            ui.map(Objetos.map_plataforma, math.floor(px - LARGURA_PLATAFORMA), math.floor(py))
            ui.circfill(ax, ay, 4, 6)
        end
    end

    if Objetos.map_plataforma then
        for _, pl in ipairs(Objetos.plataformas) do
            ui.map(Objetos.map_plataforma, math.floor(pl.x - cam_x - LARGURA_PLATAFORMA), math.floor(pl.y - cam_y))
        end
    end

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
                if State.placa.timer > 90 then
                    sprite_estado = State.placa.resultado or "placa_normal"; frame_use = 1
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

    for _, e in ipairs(Objetos.esmeraldas) do
        if not e.coletado then
            local sprite = sprite_esmeralda()
            if sprite then
                ui.spr(sprite, math.floor(e.x - cam_x - 8), math.floor(e.y - cam_y - 8), false, false)
            end
        end
    end
end

return Objetos
