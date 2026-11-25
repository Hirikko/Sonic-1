local Terreno = {
    spawn_x = 208.0, spawn_y = 224.5,
    parallax = {
        x = 0.7,
        y = 0.8,
        offset_x = 0,
        offset_y = -11,
    },
    chefe = { x = 1137.5, y = 208.5, w = 35, h = 33 },
    cela = { x = 1321, y = 223, w = 16, h = 16 },
    botaocela = { x = 1329.0, y = 167.0, w = 16, h = 16 },
    superficies = {
    },
    tetos = {
    },
    paredes = {
    },
    danos = {
    },
    joga = {
    },
    pendulos = {
    },
    molas = {
    },
    aneis = {
    },
    esmeraldas = {
    },
    areas_agua = {
    },
    pontos_ar = {
    },
    sensores_queda = {
    },
    ponte_falsa = {
    },
    outros = {
        { tipo = 'monitores', nome = 'monitor_vida', x = 40.44, y = 245.7, w = 16, h = 16, coletado = false, ativo = true },
        { tipo = 'monitores', nome = 'monitor_cont', x = 40.05, y = 214.09, w = 16, h = 16, coletado = false, ativo = true },
        { tipo = 'monitores', nome = 'monitor_escudo', x = 40.44, y = 117.7, w = 16, h = 16, coletado = false, ativo = true },
        { tipo = 'monitores', nome = 'monitor_anel', x = 40.44, y = 149.7, w = 16, h = 16, coletado = false, ativo = true },
        { tipo = 'monitores', nome = 'monitor_salva', x = 40.44, y = 181.7, w = 16, h = 16, coletado = false, ativo = true },
    },
    inimigos = {
    },
    plataformas_flutuantes = {
    },
    pontes = {
    },
    balancas = {
    },
    plataformas_chefe = {
    },
}
return Terreno