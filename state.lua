local Sonic = require("dados.sonic")
local Transicao = require("sistemas.transicao")
local Mapa = require("mapa")  -- NOVO: movido do avancar_tela pra cá

local State = {}

State.SCREEN_TITLE = 1
State.SCREEN_STAGE_PREVIEW = 2
State.SCREEN_GAME = 3
State.SCREEN_VICTORY = 4
State.SCREEN_GAME_OVER = 5
State.SCREEN_STAGE_SELECT = 6

State.stages = {
    { id = "greenhill", nome = "GREEN HILL", atos = 2, sigla = "gh", historia = true },
    { id = "greenhill", nome = "TESTE",      atos = 1, sigla = "tst", historia = false }, -- historia = false
}
State.stage_atual = 1
State.ato_atual = 1
State.proxima_cena = nil
State.acao_pos_transicao = nil
State.espera_soltar = false
State.loading_task = nil
State.caminho_mapa_pendente = nil
State.caminho_terreno_pendente = nil

local function clonar_player()
    local instancia = {}
    for chave, valor in pairs(Sonic) do instancia[chave] = valor end
    instancia.frame_anim = instancia.frame_anim or 1
    instancia.timer_anim = instancia.timer_anim or 0
    instancia.tempo_parado = instancia.tempo_parado or 0
    instancia.animacao_forcada = nil
    instancia.duracao_forcada = nil
    instancia.direcao_anterior = instancia.direcao or 1
    return instancia
end

function State.resetar_estado_fase()
    local Terreno = require("sistemas.terreno")
    local Camera = require("sistemas.camera")
    local dados_t = Terreno.get_dados()
    Camera.reset()
    State.player = clonar_player()
    local spawn_x, spawn_y = Terreno.get_spawn()
    State.player.x = spawn_x
    State.player.spawn_x = spawn_x
    State.player.y = spawn_y
    State.player.spawn_y = spawn_y

    local Timer = require("sistemas.timer")
    Timer.init()

    State.inventory.aneis = 0
    State.buffs.invencivel = 0
    State.buffs.velocidade_extra = 0
    State.buffs.escudo = false
    State.placa.ativa = false
    State.resultado = nil

    State.oxigenio = {
        tempo_maximo = 20 * 60, -- 20 segundos
        tempo_restante = 0,
        na_agua = false,
        aviso_tocado = false,
        aviso_rapido_tocado = false,
        morrendo = false,
        timer_morte = 0,
    }

    local Inimigos = require("sistemas.inimigos")
    Inimigos.init(dados_t)
    local Aneis = require("sistemas.aneis")
    Aneis.init(dados_t)
    local Objetos = require("sistemas.objetos")
    Objetos.init(dados_t)
end

function State.preparar_carregamento()
    local stage = State.stages[State.stage_atual]
    local nome_arquivo_mapa = stage.sigla .. State.ato_atual
    local nome_arquivo_terreno = nome_arquivo_mapa .. "_terreno"

    State.caminho_mapa_pendente = "fases." .. stage.id .. "." .. nome_arquivo_mapa
    State.caminho_terreno_pendente = "fases." .. stage.id .. "." .. nome_arquivo_terreno
    State.loading_task = 1
end

function State.update_loading()
    if not State.loading_task then return end

    if State.loading_task == 1 then
        require(State.caminho_mapa_pendente)
        State.loading_task = 2
    elseif State.loading_task == 2 then
        require(State.caminho_terreno_pendente)
        State.loading_task = 3
    elseif State.loading_task == 3 then
        -- NOVO: Carrega o terreno primeiro
        local Terreno = require("sistemas.terreno")
        Terreno.carregar(require(State.caminho_terreno_pendente))
        State.loading_task = 4
    elseif State.loading_task == 4 then
        -- NOVO: Depois prepara o mapa (que vai ler o parallax)
        Mapa.preparar(State.caminho_mapa_pendente)
        State.loading_task = 5
    elseif State.loading_task == 5 then
        State.resetar_estado_fase()
        State.loading_task = nil
    end
end

function State.init()
    State.inventory = { aneis = 0 }
    State.vidas = 3
    State.esmeraldas_coletadas = 0
    State.button_pressed = false
    State.pulo_liberado = false
    State.current_scene = State.SCREEN_TITLE
    State.proxima_cena = nil
    State.acao_pos_transicao = nil
    State.espera_soltar = false

    State.pontuacao = 0
    State.vidas_por_pontos = 0
    State.buffs = { invencivel = 0, velocidade_extra = 0, escudo = false }
    State.continuacoes = 0
    State.resultado = nil
    State.oxigenio = nil
    State.tempo_vitoria = 0
    State.placa = { ativa = false, x = 0, y = 0, timer = 0, resultado = "placa_normal" }
    State.checkpoint_ativo = false
    State.checkpoint_x = nil
    State.checkpoint_y = nil
    State.stage_atual = 1
    State.ato_atual = 1

    State.player = clonar_player()
    State.player.x = 100
    State.player.y = 100
    State.player.velocidade_x = 0
    State.loading_task = nil
end

local function ir_para(cena, acao)
    State.proxima_cena = cena
    State.acao_pos_transicao = acao
    Transicao.iniciar()
end

local function atualizar_botao(input)
    local pressionado = input.is_action("confirm", 0)
    if not pressionado then
        State.button_pressed = false
        if State.current_scene == State.SCREEN_GAME then State.pulo_liberado = true end
    end
end

local function avancar_tela(input)
    if Mapa.carregando or State.loading_task then return end

    if State.espera_soltar then
        if not input.is_action("confirm", 0) then
            State.espera_soltar = false
        end
        return
    end

    if State.current_scene == State.SCREEN_STAGE_SELECT then
        if input.is_action_pressed("up", 0) then
            State.stage_atual = math.max(1, State.stage_atual - 1)
        elseif input.is_action_pressed("down", 0) then
            State.stage_atual = math.min(#State.stages, State.stage_atual + 1)
        end
    end

    local pressionado = input.is_action_pressed("confirm", 0)
    if not pressionado or State.button_pressed then return end

    State.button_pressed = true
    State.pulo_liberado = false

    if State.current_scene == State.SCREEN_TITLE then
        ir_para(State.SCREEN_STAGE_SELECT)

    elseif State.current_scene == State.SCREEN_STAGE_PREVIEW then
        if State.zerou then
            ir_para(State.SCREEN_STAGE_SELECT)
        else
            State.resetar_estado_fase()
            State.espera_soltar = true
            ir_para(State.SCREEN_GAME)
        end

    elseif State.current_scene == State.SCREEN_GAME_OVER then
        ir_para(State.SCREEN_TITLE, function() State.init() end)

    elseif State.current_scene == State.SCREEN_VICTORY then
        local stage = State.stages[State.stage_atual]
        State.ato_atual = State.ato_atual + 1

        if State.ato_atual > stage.atos then
            State.ato_atual = 1
            State.stage_atual = State.stage_atual + 1

            -- Pula fases que não são da história principal (como TESTE)
            while State.stage_atual <= #State.stages and not State.stages[State.stage_atual].historia do
                State.stage_atual = State.stage_atual + 1
            end
        end

        if State.stage_atual > #State.stages then
            ir_para(State.SCREEN_TITLE, function()
                State.init()
                State.zerou = true
                State.stage_atual = 1
                State.ato_atual = 1
            end)
        else
            State.preparar_carregamento()
            ir_para(State.SCREEN_STAGE_PREVIEW)
        end

    elseif State.current_scene == State.SCREEN_STAGE_SELECT then
        State.zerou = false
        State.preparar_carregamento()
        State.espera_soltar = true
        ir_para(State.SCREEN_STAGE_PREVIEW)
    end
end

function State.update(input)
    assert(input, "State.update requer input")

    State.update_loading()
    atualizar_botao(input)

    local vidas_por_pontos_atuais = math.floor(State.pontuacao / 50000)
    if vidas_por_pontos_atuais > State.vidas_por_pontos then
        State.vidas = State.vidas + (vidas_por_pontos_atuais - State.vidas_por_pontos)
        State.vidas_por_pontos = vidas_por_pontos_atuais
    end

    if State.buffs.invencivel > 0 then State.buffs.invencivel = State.buffs.invencivel - 1 end
    if State.buffs.velocidade_extra > 0 then State.buffs.velocidade_extra = State.buffs.velocidade_extra - 1 end

    if not Transicao.ativa then
        avancar_tela(input)
    else
        Transicao.update()
        if State.proxima_cena and Transicao.progresso >= 1 then
            local proxima = State.proxima_cena
            State.proxima_cena = nil
            if State.acao_pos_transicao then
                State.acao_pos_transicao()
                State.acao_pos_transicao = nil
            end
            State.current_scene = proxima
            if State.current_scene == State.SCREEN_GAME then State.pulo_liberado = true end
        end
    end
end

function State.pode_pular() return State.pulo_liberado end

State.init()
return State
