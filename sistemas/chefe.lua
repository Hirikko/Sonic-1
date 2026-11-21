local Chefe = {}
local PlayerSys = require("sistemas.player")
local Sprites   = require("sistemas.sprites")
local Terreno   = require("sistemas.terreno")
local Camera    = require("sistemas.camera")

Chefe.ativo               = false
Chefe.x                   = 0
Chefe.y                   = 0
Chefe.w                   = 32
Chefe.h                   = 32
Chefe.hp                  = 6
Chefe.invencivel          = 0
Chefe.paredes_adicionadas = false
Chefe.cutscene            = false   -- true = Sonic sem controle
Chefe.tremor_x            = 0
Chefe.tremor_y            = 0

-- Estado interno
local estado       = "aparecer"
local timer_estado = 0
local direcao      = 1
local lado_atual   = 1
local x_inicial    = 0
local y_inicial    = 0
local x_topo       = 0
local y_topo       = 0
local min_x        = 0
local max_x        = 1000
local x_entrada    = 0
local travessias   = 0
local anim_timer   = 0
local anim_frame   = 1

-- Timing (60 fps)
local VEL_HORIZONTAL   = 1.0
local VEL_VERTICAL     = 1.5
local VEL_ATAQUE       = 4.0
local TEMPO_ESPERAR    = 45
local TEMPO_DANO       = 60    -- duração VISUAL do estado "dano"
local TEMPO_INVENCIVEL = 120   -- 2s: impede o combo aéreo
local TEMPO_ENTRADA    = 90    -- 1,5s de voo lento até o topo
local TEMPO_PARADO     = 60    -- 1s PARADO no ar com o Sonic travado
local MARGEM_ARENA_X   = 52    -- recuo das extremidades (sprite > hitbox)
local CHANCE_DESCER    = 0.65
local MAX_TRAVESSIAS   = 3
local TEMPO_MORTE      = 180
local OFFSET_DESCIDA   = 100
local OFFSET_TOPO      = 18

-- Flutuação no topo: parte de y_topo e vai SÓ para baixo,
-- para não voltar a cortar a cabeça do sprite.
local FLUTUA_AMP = 5
local FLUTUA_VEL = 0.09
-- Sprites.sprite ignora frames/cadencia do ANIMACOES; a alternância
-- do andar é feita aqui. 8f = 7,5 fps, igual ao Eggman do mapa.
local CADENCIA_ANDAR = 8


-- Sequência de derrota: morrendo -> derrotado -> fugindo
local TEMPO_DERROTADO  = 60
local VEL_FUGA_X       = 2.5
local VEL_FUGA_Y       = -2.0
local TREMOR_AMP       = 2
local MARGEM_FORA_TELA = 64

local function obter_limites()
    local dados = Terreno.get_dados()
    if dados and dados.initrava and dados.travafim then
        return dados.initrava.x, dados.travafim.x
    end
    return 0, 1000
end

local function adicionar_paredes_temporarias()
    if Chefe.paredes_adicionadas then return end
    local dados = Terreno.get_dados()
    if dados and dados.initrava and dados.travafim then
        Terreno.adicionar_parede_temporaria(dados.initrava.x - 16, 0, 500)
        Terreno.adicionar_parede_temporaria(dados.travafim.x, 0, 500)
        Chefe.paredes_adicionadas = true
    end
end

local function remover_paredes_temporarias()
    Terreno.remover_paredes_temporarias()
    Chefe.paredes_adicionadas = false
end

local function olhar_para_sonic()
    local p = require("state").player
    if p then
        direcao = (p.x < Chefe.x) and -1 or 1
    end
end

local function atualizar_direcao()
    if estado == "aparecer" or estado == "aguardar" then
        olhar_para_sonic()
    elseif estado == "topo_esq" then
        direcao = -1
    elseif estado == "topo_dir" then
        direcao = 1
    elseif estado == "descer_esq" or estado == "descer_dir"
        or estado == "subir_esq" or estado == "subir_dir" then
        olhar_para_sonic()
    elseif estado == "esperar" then
        olhar_para_sonic()
    elseif estado == "atacar" then
        direcao = (lado_atual == -1) and 1 or -1
    elseif estado == "fugindo" then
        direcao = (VEL_FUGA_X >= 0) and 1 or -1
    elseif estado == "dano" then
        olhar_para_sonic()
    end
end

function Chefe.init(dados)
    local State = require("state")
    remover_paredes_temporarias()
    Chefe.cutscene = false
    Chefe.tremor_x = 0
    Chefe.tremor_y = 0

    if dados and dados.chefe then
        Chefe.ativo                 = true
        Chefe.hp                    = 6
        Chefe.invencivel            = 0
        Chefe.w                     = dados.chefe.w or 32
        Chefe.h                     = dados.chefe.h or 32
        State.chefe_derrotado       = false
        State.chefe_ativo           = false
        State.chefe_liberou_animais = false
        Chefe.paredes_adicionadas   = false

        x_inicial = dados.chefe.x
        y_inicial = dados.chefe.y
        min_x, max_x = obter_limites()
        y_topo = y_inicial - OFFSET_TOPO
        x_topo = max_x - MARGEM_ARENA_X

        Chefe.x   = max_x + 60
        Chefe.y   = y_topo
        x_entrada  = Chefe.x
        anim_timer = 0
        anim_frame = 1
        travessias = 0

        estado       = "aparecer"
        timer_estado = 0
        direcao      = -1
        lado_atual   = 1
    else
        -- fase sem chefe: garante que música/arena não fiquem presas
        Chefe.ativo           = false
        State.chefe_ativo     = false
        State.chefe_derrotado = false
    end
end

function Chefe.update(player)
    local State = require("state")
    if not Chefe.ativo then return end

    if State.chefe_derrotado then
        remover_paredes_temporarias()
        Chefe.ativo       = false
        State.chefe_ativo = false
        return
    end

    local dados = Terreno.get_dados()
    if dados and dados.initrava and player.x > dados.initrava.x then
        if not State.chefe_ativo then
            -- acabou de entrar na arena: segura o Sonic durante a entrada
            Chefe.cutscene = true
        end
        State.chefe_ativo = true
        adicionar_paredes_temporarias()
    end
    if not State.chefe_ativo then return end

    if Chefe.invencivel > 0 then
        Chefe.invencivel = Chefe.invencivel - 1
    end
    timer_estado = timer_estado + 1
    anim_timer = anim_timer + 1
    if anim_timer >= CADENCIA_ANDAR then
        anim_timer = 0
        anim_frame = (anim_frame == 1) and 2 or 1
    end

    -- --------------------------------------------------------------
    -- aparecer -> aguardar -> topo -> descer -> esperar -> atacar -> subir
    -- --------------------------------------------------------------
    if estado == "aparecer" then
        local t = math.min(1, timer_estado / TEMPO_ENTRADA)
        Chefe.x = x_entrada + (x_topo - x_entrada) * t
        Chefe.y = y_topo
        if timer_estado >= TEMPO_ENTRADA then
            Chefe.x      = x_topo
            estado       = "aguardar"
            timer_estado = 0
        end

    elseif estado == "aguardar" then
        -- parado no ar, Sonic ainda sem controle, encarando ele
        Chefe.x = x_topo
        Chefe.y = y_topo
        if timer_estado >= TEMPO_PARADO then
            Chefe.cutscene = false   -- libera o controle: começa a batalha
            travessias     = 0
            estado         = "topo_esq"
            timer_estado   = 0
        end

    elseif estado == "topo_esq" then
        local alvo = min_x + MARGEM_ARENA_X
        if Chefe.x > alvo then
            Chefe.x = Chefe.x - VEL_HORIZONTAL
        else
            Chefe.x    = alvo
            travessias = travessias + 1
            if travessias >= MAX_TRAVESSIAS or math.random() < CHANCE_DESCER then
                estado     = "descer_esq"
                lado_atual = -1
                travessias = 0
            else
                estado = "topo_dir"
            end
            timer_estado = 0
        end

    elseif estado == "topo_dir" then
        local alvo = max_x - MARGEM_ARENA_X
        if Chefe.x < alvo then
            Chefe.x = Chefe.x + VEL_HORIZONTAL
        else
            Chefe.x    = alvo
            travessias = travessias + 1
            if travessias >= MAX_TRAVESSIAS or math.random() < CHANCE_DESCER then
                estado     = "descer_dir"
                lado_atual = 1
                travessias = 0
            else
                estado = "topo_esq"
            end
            timer_estado = 0
        end

    elseif estado == "descer_esq" or estado == "descer_dir" then
        local alvo_y = y_inicial + OFFSET_DESCIDA
        if Chefe.y < alvo_y then
            Chefe.y = Chefe.y + VEL_VERTICAL
        else
            Chefe.y      = alvo_y
            estado       = "esperar"
            timer_estado = 0
        end

    elseif estado == "esperar" then
        if timer_estado >= TEMPO_ESPERAR then
            estado       = "atacar"
            timer_estado = 0
        end

    elseif estado == "atacar" then
        local alvo_x = (lado_atual == -1)
                       and (max_x - MARGEM_ARENA_X)
                       or  (min_x + MARGEM_ARENA_X)
        local dx = alvo_x - Chefe.x
        if math.abs(dx) > VEL_ATAQUE then
            Chefe.x = Chefe.x + (dx > 0 and VEL_ATAQUE or -VEL_ATAQUE)
        else
            Chefe.x      = alvo_x
            estado       = (lado_atual == -1) and "subir_dir" or "subir_esq"
            timer_estado = 0
        end

    elseif estado == "subir_esq" or estado == "subir_dir" then
        if Chefe.y > y_topo then
            Chefe.y = Chefe.y - VEL_VERTICAL
        else
            Chefe.y = y_topo
            -- vai para o lado OPOSTO de onde está
            local meio = (min_x + max_x) / 2
            estado       = (Chefe.x > meio) and "topo_esq" or "topo_dir"
            travessias   = 0
            timer_estado = 0
        end

    elseif estado == "dano" then
        if timer_estado >= TEMPO_DANO then
            -- NÃO zerar invencivel: ele decai sozinho no topo do update
            estado       = "subir_esq"
            timer_estado = 0
        end

    elseif estado == "morrendo" then
        local Inimigos = require("sistemas.inimigos")
        if timer_estado % 15 == 0 and timer_estado < 150 then
            Inimigos.criar_explosao(
                Chefe.x + math.random(-24, 24),
                Chefe.y + math.random(-24, 24)
            )
        end
        Chefe.tremor_x = math.random(-TREMOR_AMP, TREMOR_AMP)
        Chefe.tremor_y = math.random(-TREMOR_AMP, TREMOR_AMP)
        if timer_estado >= TEMPO_MORTE then
            estado         = "derrotado"
            timer_estado   = 0
            Chefe.tremor_x = 0
            Chefe.tremor_y = 0
        end

    elseif estado == "derrotado" then
        if timer_estado >= TEMPO_DERROTADO then
            estado       = "fugindo"
            timer_estado = 0
        end

    elseif estado == "fugindo" then
        Chefe.x = Chefe.x + VEL_FUGA_X
        Chefe.y = Chefe.y + VEL_FUGA_Y
        local cam_x, cam_y = Camera.get_xy()
        local sx, sy = Chefe.x - cam_x, Chefe.y - cam_y
        if sx < -MARGEM_FORA_TELA or sx > Camera.largura_tela + MARGEM_FORA_TELA
        or sy < -MARGEM_FORA_TELA or sy > Camera.altura_tela + MARGEM_FORA_TELA then
            State.chefe_derrotado = true
            State.chefe_ativo     = false
            Chefe.ativo           = false
            Chefe.cutscene        = false
            remover_paredes_temporarias()
        end
    end

    -- Flutuação SÓ cruzando o topo.
    -- Na entrada e no "aguardar" ele fica imóvel no ar.
    if estado == "topo_esq" or estado == "topo_dir" then
        local bob = (1 - math.cos(timer_estado * FLUTUA_VEL)) * 0.5
        Chefe.y = y_topo + bob * FLUTUA_AMP
    end

    -- --------------------------------------------------------------
    -- Colisões
    -- --------------------------------------------------------------
    local sem_colisao = (estado == "aparecer" or estado == "aguardar"
                         or estado == "dano" or estado == "morrendo"
                         or estado == "derrotado" or estado == "fugindo")

    if not player.morto and not sem_colisao and Chefe.invencivel <= 0 then
        local px0, py0, px1, py1 = PlayerSys.get_hitbox(player)
        if px0 < Chefe.x + Chefe.w / 2 and px1 > Chefe.x - Chefe.w / 2
        and py0 < Chefe.y + Chefe.h / 2 and py1 > Chefe.y - Chefe.h / 2 then
            local ctx = PlayerSys.contexto_ataque(player)
            -- Só fere se os pés do Sonic vinham de cima do centro dele.
            local acertou_por_cima = ctx.pes_prev <= (Chefe.y + 4)
            if (ctx.atacando and acertou_por_cima) or ctx.invencivel_ofensivo then
                Chefe.hp         = Chefe.hp - 1
                Chefe.invencivel = TEMPO_INVENCIVEL
                PlayerSys.aplicar_bounce(player, ctx.vy_impacto)
                if Chefe.hp <= 0 then
                    estado         = "morrendo"
                    timer_estado   = 0
                    Chefe.cutscene = true
                else
                    estado       = "dano"
                    timer_estado = 0
                end
            elseif not ctx.invencivel_defensivo then
                PlayerSys.aplicar_dano(player)
            end
        end
    end

    atualizar_direcao()
end

-- Consultado pelo game.lua para travar o controle do Sonic
function Chefe.em_cutscene()
    return Chefe.cutscene == true
end

function Chefe.draw(cam_x, cam_y)
    if not Chefe.ativo then return end

    local sprite_estado, frame_use
    if estado == "morrendo" then
        sprite_estado = "chefe_gh3_perdeu"
        frame_use     = (math.floor(timer_estado / 6) % 2) + 1
    elseif estado == "derrotado" or estado == "fugindo" then
        sprite_estado = "chefe_gh3_perdeu"
        frame_use     = (math.floor(timer_estado / 12) % 2) + 1
    elseif estado == "dano" then
        if math.floor(timer_estado / 4) % 2 == 0 then
            sprite_estado = "chefe_gh3_doeu"
            frame_use     = 1
        else
            sprite_estado = "chefe_gh3_andar"
            frame_use     = anim_frame
        end
    elseif estado == "atacar" then
        sprite_estado = "chefe_gh3_ataq"
        frame_use     = 1
    else
        sprite_estado = "chefe_gh3_andar"
        frame_use     = anim_frame
    end

    local sprite = Sprites.sprite(sprite_estado, frame_use)
    local flip = (direcao > 0)

    if sprite then
        local sw = sprite.width  or Chefe.w
        local sh = sprite.height or Chefe.h
        ui.spr(sprite,
            math.floor(Chefe.x - cam_x - sw / 2 + Chefe.tremor_x),
            math.floor(Chefe.y - cam_y - sh / 2 + Chefe.tremor_y),
            flip, false)
    else
        local piscar = Chefe.invencivel > 0 and math.floor(Chefe.invencivel / 4) % 2 == 0
        if not piscar then
            ui.rectfill(math.floor(Chefe.x - cam_x - Chefe.w / 2),
                        math.floor(Chefe.y - cam_y - Chefe.h / 2),
                        Chefe.w, Chefe.h, 8)
        end
    end
end

return Chefe
