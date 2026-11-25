local Sonic = require("dados.sonic")
local Transicao = require("sistemas.transicao")
local Mapa = require("mapa")

local State = {}

State.SCREEN_TITLE = 1
State.SCREEN_STAGE_PREVIEW = 2
State.SCREEN_GAME = 3
State.SCREEN_VICTORY = 4
State.SCREEN_GAME_OVER = 5
State.SCREEN_STAGE_SELECT = 6
State.SCREEN_MENUS = 7
State.volume_master = 1.0
-- COOP: 1 = single player (comportamento atual), 2 ou 3 = coop.
State.coop_num_players = 1
State.modo = "historia"   -- historia | coop | rei_aneis | velocista | agilidade | sobrevivente | perseguicao
State.coop_herois = { "sonic", "tails", "knux", "amy", "knux", "rouge" }
State.players = nil
-- Pause global (L1+R1): congela o jogo e abre as opcoes por cima.
State.pausado_opcoes = false
State.pausa_bloqueio = false

State.stages = {
    { id = "greenhill", nome = "PESQUISA",   atos = 1, sigla = "tst", historia = false },
        -- SP: subir atos para 8 quando sp2..sp8 estiverem gerados
    { id = "specialzone", nome = "SALA ESPECIAL", atos = 2, sigla = "sp", historia = false, especial = true },
    { id = "greenhill", nome = "GREEN HILL", atos = 3, sigla = "gh",  historia = true },
        -- atos = 1 enquanto só bz1 existir; subir para 3 quando bz2/bz3 chegarem.
    { id = "bridgezone", nome = "BRIDGE", atos = 2, sigla = "bz", historia = true },
    --[[ PROXIMAS ZONAS — descomentar quando os .lua + _terreno.lua existirem.
    O caminho vem de id + sigla + ato: fases.junglezone.jz1, etc.
    { id = "junglezone",    nome = "JUNGLE",      atos = 3, sigla = "jz",  historia = true },
    { id = "labyrinthzone", nome = "LABYRINTH",   atos = 3, sigla = "lz",  historia = true },
    { id = "scrapbrain",    nome = "SCRAP BRAIN", atos = 3, sigla = "sb",  historia = true },
    { id = "skybasezone",   nome = "SKY BASE",    atos = 3, sigla = "sbz", historia = true },
    ]]--
}
State.SP_TEMPO = 60 * 60
State.SP_ATOS_DISPONIVEIS = 2   -- subir para 6 quando sp2..sp6 existirem
State.sp_indice = 1             -- qual sala especial será a próxima
State.especial = nil
State.sp_retorno = { stage = 1, ato = 0 }
function State.stage_e_especial()
local s = State.stages[State.stage_atual]
return (s and s.especial) == true
end
-- Atos que terminam em chefe. Chave = sigla da zona, valor = ato.
-- Ao criar BZ/JZ/LZ/SBZ, basta acrescentar a sigla aqui.
local ATOS_CHEFE = { gh = 3, bz = 3, jz = 3, lz = 3, sb = 3, sbz = 3 }
function State.fase_e_chefe()
local s = State.stages[State.stage_atual]
if not s then return false end
return ATOS_CHEFE[s.sigla] == State.ato_atual
end

State.fases_flat = {}
State.indice_selecao = 1

function State.init_fases_flat()
    State.fases_flat = {}
    for i, stage in ipairs(State.stages) do
        if not stage.historia then
            for ato = 1, stage.atos do
                table.insert(State.fases_flat, { index_original = i, ato = ato })
            end
        end
    end
    for i, stage in ipairs(State.stages) do
        if stage.historia then
            for ato = 1, stage.atos do
                table.insert(State.fases_flat, { index_original = i, ato = ato })
            end
        end
    end
end

State.stage_atual = 1
State.ato_atual = 1
State.proxima_cena = nil
State.acao_pos_transicao = nil
State.espera_soltar = false
State.loading_task = nil
State.caminho_mapa_pendente = nil
State.caminho_terreno_pendente = nil
State.vitoria_anim = nil
State.tempo_preview = 0
State.selecao_confirmada = false
State.timer_game_over = nil

-- dados/<heroi>.lua; se ainda nao existir, cai no Sonic.
local function carregar_dados_heroi(heroi)
    if heroi and heroi ~= "sonic" then
        local ok, d = pcall(require, "dados." .. heroi)
        if ok and type(d) == "table" then return d end
    end
    return Sonic
end

local function clonar_player(heroi, pad)
    local base = carregar_dados_heroi(heroi)
    local instancia = {}
    for chave, valor in pairs(base) do instancia[chave] = valor end
    instancia.heroi = heroi or "sonic"
    instancia.pad = pad or 0
    instancia.frame_anim = instancia.frame_anim or 1
    instancia.timer_anim = instancia.timer_anim or 0
    instancia.tempo_parado = instancia.tempo_parado or 0
    instancia.animacao_forcada = nil
    instancia.duracao_forcada = nil
    instancia.direcao_anterior = instancia.direcao or 1
    instancia.coop_esperando = false
    instancia.coop_timer = 0
    -- oxigenio INDIVIDUAL (regra do coop)
    instancia.oxigenio = {
        tempo_maximo = 20 * 60, tempo_restante = 0,
        na_agua = false, morrendo = false, timer_morte = 0,
    }
    -- buffs INDIVIDUAIS: escudo/invenc/velocidade sao de quem pegou
    instancia.buffs = { invencivel = 0, velocidade_extra = 0, escudo = false }
    return instancia
end

function State.resetar_estado_fase()
    local Terreno = require("sistemas.terreno")
    local Camera = require("sistemas.camera")
    local dados_t = Terreno.get_dados()
    Camera.reset()
    local spawn_x, spawn_y = Terreno.get_spawn()

    local altura_chao = Terreno.altura(spawn_x, spawn_y + 32)
    if altura_chao and spawn_y + 32 > altura_chao then
        spawn_y = altura_chao - 32
    end

    local n = State.coop_num_players or 1
    State.players = {}
    for i = 1, n do
        local heroi = (State.coop_herois and State.coop_herois[i]) or "sonic"
        local p = clonar_player(heroi, i - 1)
        -- 24px de separacao para nao nascerem sobrepostos
        local px = spawn_x + (i - 1) * 24
        p.x, p.spawn_x = px, px
        p.y, p.spawn_y = spawn_y, spawn_y
        local altura = Terreno.altura(px, spawn_y + 32)
        if not altura or altura > spawn_y + 32 + 16 then
            p.y = spawn_y - 32
            p.spawn_y = p.y
        end
        State.players[i] = p
    end
    -- alias: objetos/chefe/ui/menus ainda leem State.player
    State.player = State.players[1]
    State.oxigenio = State.player.oxigenio

    -- COOP: escudo/invenc/velocidade sao COMPARTILHADOS. Todos apontam
    -- para a MESMA tabela, entao quem pega vale para o grupo. No modo
    -- player-vs-player (futuro) cada um recebe a sua propria tabela.
    -- Oxigenio continua individual.
    local buffs_grupo = { invencivel = 0, velocidade_extra = 0, escudo = false }
    for _, p in ipairs(State.players) do p.buffs = buffs_grupo end
    State.buffs = buffs_grupo

    local Coop = require("sistemas.coop")
    Coop.init(State.players)

    local Timer = require("sistemas.timer")
    Timer.init()

    State.inventory.aneis = 0
    State.buffs.invencivel = 0
    State.buffs.velocidade_extra = 0
    State.buffs.escudo = false
    State.esmeralda_no_ato = false
    State.placa.ativa = false
    State.placa.resultado = "placa_normal"
    State.placa.heroi = nil
    State.resultado = nil
    State.vitoria_anim = nil
    State.chefe_derrotado = false
    State.chefe_liberou_animais = false
    State.chefe_ativo = false
    State.cela_cutscene = false
    State.cela_foco_x = nil
    State.cela_foco_y = nil
    -- State.oxigenio continua sendo o alias de player.oxigenio, criado
    -- acima. Recriar a tabela aqui deixava a bolha de ar escrevendo
    -- numa tabela orfa que ninguem le.

    local Inimigos = require("sistemas.inimigos")
    Inimigos.init(dados_t)
    local Aneis = require("sistemas.aneis")
    Aneis.init(dados_t)
    local Objetos = require("sistemas.objetos")
    Objetos.init(dados_t)

 local Chefe = require("sistemas.chefe")
 Chefe.init(dados_t)
 if State.stage_e_especial() then
     -- guarda o que o jogador já tinha: no timeout tudo que foi
     -- coletado dentro da sala especial é devolvido ao valor anterior
     State.especial = {
         tempo        = State.SP_TEMPO,
         aneis        = State.inventory.aneis or 0,
         vidas        = State.vidas or 0,
         cont         = State.continuacoes or 0,
         pontos       = State.pontuacao or 0,
         pontos_marco = State.vidas_por_pontos or 0,
         concluiu     = false,
         falhou       = false,
     }
 else
     State.especial = nil
     local st = State.stages[State.stage_atual]
     if st and st.historia then
         State.sp_retorno = { stage = State.stage_atual, ato = State.ato_atual }
     end
 end
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
        local Terreno = require("sistemas.terreno")
        Terreno.carregar(require(State.caminho_terreno_pendente))
        State.loading_task = 4
    elseif State.loading_task == 4 then
        Mapa.preparar(State.caminho_mapa_pendente)
        State.loading_task = 5
    elseif State.loading_task == 5 then
        -- O reset zera aneis/buffs e vitoria_anim. Se rodar durante o
        -- fade-out, o update_vitoria_anim RECRIA o vitoria_anim com os
        -- bonus cheios e os tres numeros voltam ao valor original na
        -- frente do jogador. Espera a tela apagar: quando o progresso
        -- chega a 1, o Transicao.update vira a direcao para -1.
        -- As tarefas 1..4 seguem rodando durante o fade, entao o tempo
        -- de tela preta NAO aumenta.
        if Transicao.ativa and Transicao.direcao > 0 and Transicao.progresso < 1 then
            return
        end
        State.resetar_estado_fase()
        State.loading_task = nil
    end
end

function State.init()
    State.inventory = { aneis = 0 }
    local Coop = require("sistemas.coop")
    State.vidas = Coop.vidas_iniciais(State.coop_num_players)
    State.esmeraldas_coletadas = 0
    State.esmeralda_no_ato = false
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
    State.vitoria_anim = nil
    State.tempo_preview = 0
    State.indice_selecao = 1
    State.selecao_confirmada = false
    State.timer_game_over = nil
    State.chefe_derrotado = false
    State.chefe_liberou_animais = false
    State.chefe_ativo = false
    State.cela_cutscene = false
    State.cela_foco_x = nil
    State.cela_foco_y = nil
    State.init_fases_flat()

    local primeiro = State.fases_flat[1]
    if primeiro then
        State.stage_atual = primeiro.index_original
        State.ato_atual   = primeiro.ato
    end

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

-- ============================================================
-- SALA ESPECIAL — conclusão, timeout e saída
-- ============================================================
function State._sp_ir_proxima()
    local r = State.sp_retorno or { stage = 1, ato = 0 }
    local stage, ato = r.stage, r.ato + 1
    while stage <= #State.stages do
        local st = State.stages[stage]
        if st.historia and ato <= st.atos then break end
        stage = stage + 1
        ato = 1
    end
    State.especial = nil
    if stage > #State.stages then
        ir_para(State.SCREEN_TITLE, function()
            State.init()
            State.zerou = true
        end)
    else
        State.stage_atual = stage
        State.ato_atual   = ato
        State.preparar_carregamento()
        State.espera_soltar = true
        ir_para(State.SCREEN_STAGE_PREVIEW)
    end
end

-- Entrada na sala especial a partir da placa com "!"
function State._ir_para_fase_especial()
    local idx = nil
    for i, s in ipairs(State.stages) do
        if s.especial then idx = i; break end
    end
    if not idx then return false end
    -- guarda de onde veio: a saída da sala volta para o ato seguinte
    State.sp_retorno  = { stage = State.stage_atual, ato = State.ato_atual }
    State.stage_atual = idx
    State.ato_atual   = math.min(State.sp_indice or 1, State.SP_ATOS_DISPONIVEIS or 1)
    State.preparar_carregamento()
    State.espera_soltar = true
    ir_para(State.SCREEN_STAGE_PREVIEW)
    return true
end

-- Passou pela placa: mantém bônus e itens, vai para a tela de vitória.
function State.sp_concluir()
    if not State.especial then return end
    if State.especial.concluiu or State.especial.falhou then return end
    State.especial.concluiu = true
    State.resultado = "especial_ok"
end

-- Tempo esgotado: perde tudo que coletou e segue para a próxima fase.
function State.sp_falhar()
if not State.especial then return end
if State.especial.concluiu or State.especial.falhou then return end
State.especial.falhou = true
-- devolve tudo que foi pego DENTRO da sala especial
State.inventory.aneis = State.especial.aneis
State.vidas           = State.especial.vidas
State.continuacoes    = State.especial.cont
State.pontuacao       = State.especial.pontos
State.vidas_por_pontos = State.especial.pontos_marco or State.vidas_por_pontos
State.bonus_aneis     = 0
State.bonus_tempo     = 0
State.resultado       = "especial_falhou"
State.sp_indice = math.min((State.sp_indice or 1) + 1, State.SP_ATOS_DISPONIVEIS or 1)
-- passa pela tela de vitória com fade, como um ato normal
ir_para(State.SCREEN_VICTORY)
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
    -- os menus tem navegacao propria (sistemas/menus.lua)
    if State.current_scene == State.SCREEN_MENUS then return end

    if State.espera_soltar then
        if not input.is_action("confirm", 0) then
            State.espera_soltar = false
        end
        return
    end

    if State.current_scene == State.SCREEN_STAGE_SELECT then
        if not State.selecao_confirmada then
            if input.is_action_pressed("left", 0) then
                State.indice_selecao = math.max(1, State.indice_selecao - 1)
                State.button_pressed = false
            elseif input.is_action_pressed("right", 0) then
                State.indice_selecao = math.min(#State.fases_flat, State.indice_selecao + 1)
                State.button_pressed = false
            end
            local escolha = State.fases_flat[State.indice_selecao]
            if escolha then
                State.stage_atual = escolha.index_original
                State.ato_atual = escolha.ato
            end
        end
    end

    if State.current_scene == State.SCREEN_STAGE_PREVIEW then
    local tempo_espera = 180
    if State.fase_e_chefe() then
        tempo_espera = 260   -- cobre a entrada do Eggman (220f) + 40f de pausa
    end

        if State.tempo_preview >= tempo_espera then
            State.selecao_confirmada = false
            State.resetar_estado_fase()
            State.espera_soltar = true
            ir_para(State.SCREEN_GAME)
        end
        return
    end

    local pressionado = input.is_action_pressed("confirm", 0)

    if State.current_scene == State.SCREEN_VICTORY then
        if State.vitoria_anim and State.vitoria_anim.fase < 2 then return end
    end

    if not pressionado or State.button_pressed then return end

    State.button_pressed = true
    State.pulo_liberado = false

    if State.current_scene == State.SCREEN_TITLE then
        State.selecao_confirmada = false
        local Menus = require("sistemas.menus")
        Menus.reset()
        ir_para(State.SCREEN_MENUS)

    elseif State.current_scene == State.SCREEN_GAME_OVER then
        if State.continuacoes > 0 then
            State.continuacoes = State.continuacoes - 1
            State.vidas = 3
            State.timer_game_over = nil
            State.resetar_estado_fase()
            ir_para(State.SCREEN_GAME)
        else
            State.timer_game_over = nil
            ir_para(State.SCREEN_TITLE, function() State.init() end)
        end

    elseif State.current_scene == State.SCREEN_VICTORY then
        if State.vitoria_anim then
            local anim = State.vitoria_anim
            local restante = anim.pontos_aneis + anim.pontos_tempo
            if restante > 0 then
                State.pontuacao = State.pontuacao + restante
                anim.pontos_aneis = 0
                anim.pontos_tempo = 0
                anim.pontos = anim.pontos + restante
            end
        end

        -- COOP: revive os mortos de graca. Se o pool zerou mas alguem
        -- terminou vivo, o grupo volta com 1 vida.
        local Coop = require("sistemas.coop")
        Coop.ao_concluir_ato(State)

        -- sala especial (passou OU tempo esgotado): volta para a próxima fase
        if State.resultado == "especial_ok" or State.resultado == "especial_falhou" then
            State._sp_ir_proxima()
            return
        end
        -- placa com "!" -> entra na sala especial em vez de avançar o ato
        if State.placa.resultado == "placa_especial" and State._ir_para_fase_especial() then
            return
        end

        local stage = State.stages[State.stage_atual]
        State.ato_atual = State.ato_atual + 1

        if State.ato_atual > stage.atos then
            State.ato_atual = 1
            State.stage_atual = State.stage_atual + 1
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
        State.selecao_confirmada = true
        State.zerou = false
        State.espera_soltar = true
        State.preparar_carregamento()
        State.current_scene = State.SCREEN_STAGE_PREVIEW
        State.tempo_preview = 0
    end
end

local function update_vitoria_anim(input)
    if not State.vitoria_anim then
        State.vitoria_anim = {
            timer = 0,
            fase = 0,
            pontos_aneis = State.bonus_aneis or 0,
            pontos_tempo = State.bonus_tempo or 0,
            pontos = 0
        }
    end

    local anim = State.vitoria_anim
    anim.timer = anim.timer + 1

    if anim.fase == 0 then
        if anim.timer >= 150 then
            anim.fase = 1
            anim.timer = 0
        end
    elseif anim.fase == 1 then
        if anim.timer % 2 == 0 then
            local add = 0
            if anim.pontos_aneis > 0 then
                local ded = math.min(100, anim.pontos_aneis)
                anim.pontos_aneis = anim.pontos_aneis - ded
                add = add + ded
            end
            if anim.pontos_tempo > 0 then
                local ded = math.min(100, anim.pontos_tempo)
                anim.pontos_tempo = anim.pontos_tempo - ded
                add = add + ded
            end
            anim.pontos = anim.pontos + add

            if anim.pontos_aneis == 0 and anim.pontos_tempo == 0 then
                anim.fase = 2
                anim.timer = 0
            end
        end

        if input.is_action_pressed("confirm", 0) then
            anim.pontos = anim.pontos + anim.pontos_aneis + anim.pontos_tempo
            anim.pontos_aneis = 0
            anim.pontos_tempo = 0
            anim.fase = 2
            anim.timer = 0
            State.espera_soltar = true
        end
    end
end

function State.update(input)
    assert(input, "State.update requer input")

    -- L1+R1 (BTN.F + BTN.G): pausa global. O bloqueio impede que o
    -- combo fique alternando enquanto os dois estao segurados.
    local BTN = require("btn")
    -- Qualquer controle pode chamar o pause (P1, P2 ou P3).
    local combo = false
    for pad = 0, 2 do
        if ui.btn(BTN.F, pad) ~= false and ui.btn(BTN.G, pad) ~= false then
            combo = true
            break
        end
    end
    if combo and not State.pausa_bloqueio then
        State.pausa_bloqueio = true
        if State.current_scene == State.SCREEN_GAME then
            State.pausado_opcoes = not State.pausado_opcoes
            local Menus = require("sistemas.menus")
            if State.pausado_opcoes then Menus.abrir_overlay() end
        end
    elseif not combo then
        State.pausa_bloqueio = false
    end

    State.update_loading()
    atualizar_botao(input)

    -- Pausado: so os menus rodam. Nada de timer, buff, vitoria ou
    -- troca de cena — o jogo fica congelado de verdade.
    if State.pausado_opcoes then
        local Menus = require("sistemas.menus")
        Menus.update(input)
        return
    end

    if State.current_scene == State.SCREEN_GAME_OVER then
        if not State.timer_game_over then
            State.timer_game_over = 9 * 60
        end
        if State.continuacoes > 0 then
            State.timer_game_over = math.max(0, State.timer_game_over - 1)
            if State.timer_game_over <= 0 then
                State.continuacoes = 0
                State.timer_game_over = nil
                ir_para(State.SCREEN_TITLE, function() State.init() end)
            end
        end
    end

    if State.current_scene == State.SCREEN_VICTORY then
        update_vitoria_anim(input)
    elseif State.current_scene == State.SCREEN_STAGE_PREVIEW then
        State.tempo_preview = State.tempo_preview + 1
    elseif State.current_scene == State.SCREEN_MENUS then
        local Menus = require("sistemas.menus")
        Menus.update(input)
    end

    local vidas_por_pontos_atuais = math.floor(State.pontuacao / 50000)
    if vidas_por_pontos_atuais > State.vidas_por_pontos then
        State.vidas = State.vidas + (vidas_por_pontos_atuais - State.vidas_por_pontos)
        State.vidas_por_pontos = vidas_por_pontos_atuais
    end

    for _, p in ipairs(State.players or { State.player }) do
        local b = p.buffs
        if b then
            if b.invencivel > 0 then b.invencivel = b.invencivel - 1 end
            if b.velocidade_extra > 0 then b.velocidade_extra = b.velocidade_extra - 1 end
        end
    end

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
            if State.current_scene == State.SCREEN_STAGE_PREVIEW then State.tempo_preview = 0 end
        end
    end
end

function State.pode_pular() return State.pulo_liberado end
State.init()
return State
