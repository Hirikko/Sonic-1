local Sonic = {
    heroi = "amy",
    x = 100,
    y = 240,
    spawn_x = 100,
    spawn_y = 240,

    velocidade_x = 0,
    velocidade_y = 0,
    no_chao = true,
    direcao = 1,
    direcao_anterior = 1,
    sprite = "parado",
    frame_anim = 1,
    timer_anim = 0,
    tempo_parado = 0,
    animacao_forcada = nil,
    duracao_forcada = nil,
    olhando_cima = false,
    olhando_baixo = false,
    rodando = false,
    pulou_mola = false,
    tomou_dano = false,
    morto = false,
    em_dano = false,
    em_queda = false,
    vulneravel_mola_cima = false
}

return Sonic
