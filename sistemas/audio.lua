local Audio = {}

local musica_atual = nil
local musica_fundo = nil

local DURACAO_SKYSANCT = 30 * 60
local DURACAO_MARBLEZN = 30 * 60

local timer_teste = 0
local musica_teste_index = 1
local atraso_inicio_tst = 0

local timer_actstart = 0

-- Controle de crossfade manual
local crossfade_ativo = false
local crossfade_timer = 0
local crossfade_duracao = 2.0 -- 2 segundos (tempo do fade out e do fade in)
local crossfade_nova_id = nil
local crossfade_novo_path = nil

local FADE_LONGO = 2.0
local FADE_CURTO = 1.5

function Audio.update(state)
    if not music then return end

    local cena = state.current_scene
    local invencivel = (state.buffs and state.buffs.invencivel and state.buffs.invencivel > 0)

    -- 1. Controle de duração do actstart
    if timer_actstart > 0 then
        timer_actstart = timer_actstart - 1
        if timer_actstart <= 0 then
            if musica_atual == "actstart" then
                music.stop(FADE_CURTO)
                musica_atual = "actstart_feito"
            end
        end
    end

    -- 2. Processa o crossfade manual
    if crossfade_ativo then
        crossfade_timer = crossfade_timer + 1
        local progresso = crossfade_timer / (crossfade_duracao * 60)

        if progresso <= 1.0 then
            -- Fase 1: Fade out da música atual até 0 gradualmente
            local volume_atual = math.max(0, 1.0 - progresso)
            music.volume(volume_atual, CH_ALL, 0)
        else
            -- Fase 2: Terminou o fade out. Inicia a nova e faz o fade in
            music.stop(0)
            music.volume(0, CH_ALL, 0)             -- Zera o volume
            music.loop(crossfade_novo_path, 0)     -- Inicia a nova
            music.volume(1.0, CH_ALL, crossfade_duracao) -- Fade in suave da nova

            musica_atual = crossfade_nova_id
            crossfade_ativo = false
            crossfade_timer = 0
            crossfade_nova_id = nil
            crossfade_novo_path = nil
        end
        return -- Retorna para não processar o resto e atrapalhar
    end

    -- 3. Invencibilidade
    if invencivel and cena == state.SCREEN_GAME then
        if musica_atual ~= "invenc" then
            music.loop("audio/bgm/invenc", FADE_CURTO)
            musica_atual = "invenc"
        end
        return
    end

    -- 4. Fim da invencibilidade
    if musica_atual == "invenc" and not invencivel then
        if musica_fundo == "greenhill" then
            music.loop("audio/bgm/greenhill", FADE_LONGO)
        elseif musica_fundo == "tst_1" then
            music.loop("audio/bgm/skysanct-unused", FADE_LONGO)
        elseif musica_fundo == "tst_2" then
            music.loop("audio/bgm/marblezn-unused", FADE_LONGO)
        end
        musica_atual = musica_fundo
    end

    -- 5. Músicas por Cena
    if cena == state.SCREEN_TITLE then
        if musica_atual ~= "titulo" then
            music.loop("audio/bgm/titulo", FADE_LONGO)
            musica_atual = "titulo"
            musica_fundo = "titulo"
        end

    elseif cena == state.SCREEN_STAGE_PREVIEW then
        if musica_atual ~= "actstart" and musica_atual ~= "actstart_feito" then
            music.loop("audio/fx/actstart", FADE_CURTO)
            musica_atual = "actstart"
            timer_actstart = 180
        end

    elseif cena == state.SCREEN_GAME then
        local stage = state.stages[state.stage_atual]
        local sigla = stage and stage.sigla or ""

        if sigla == "gh" then
            if musica_atual ~= "greenhill" then
                if musica_atual == "actstart" then
                    music.stop(0)
                end
                music.loop("audio/bgm/greenhill", FADE_CURTO)
                musica_atual = "greenhill"
                musica_fundo = "greenhill"
            end

        elseif sigla == "tst" then
            if musica_atual ~= "tst_1" and musica_atual ~= "tst_2" then
                if musica_atual == "actstart" then
                    music.stop(0)
                end

                music.loop("audio/bgm/skysanct-unused", FADE_LONGO)
                musica_atual = "tst_1"
                musica_fundo = "tst_1"

                musica_teste_index = 1
                timer_teste = 0
                atraso_inicio_tst = 60
            else
                if atraso_inicio_tst > 0 then
                    atraso_inicio_tst = atraso_inicio_tst - 1
                else
                    timer_teste = timer_teste + 1
                    if musica_teste_index == 1 and timer_teste >= DURACAO_SKYSANCT then
                        crossfade_ativo = true
                        crossfade_timer = 0
                        crossfade_nova_id = "tst_2"
                        crossfade_novo_path = "audio/bgm/marblezn-unused"
                        musica_teste_index = 2
                        timer_teste = 0
                    elseif musica_teste_index == 2 and timer_teste >= DURACAO_MARBLEZN then
                        crossfade_ativo = true
                        crossfade_timer = 0
                        crossfade_nova_id = "tst_1"
                        crossfade_novo_path = "audio/bgm/skysanct-unused"
                        musica_teste_index = 1
                        timer_teste = 0
                    end
                end
            end
        end

    -- 6. Tela de Vitória, Game Over e Seleção de Fase
    elseif cena == state.SCREEN_VICTORY or cena == state.SCREEN_GAME_OVER or cena == state.SCREEN_STAGE_SELECT then
        if musica_atual ~= "parado" then
            music.stop(FADE_LONGO)
            musica_atual = "parado"
            musica_fundo = nil
        end
    end
end

function Audio.parar()
    if music then
        music.stop(FADE_LONGO)
        musica_atual = nil
    end
end

return Audio
