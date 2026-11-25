local Terreno = {
    spawn_x = 179.0, spawn_y = 723.5,
    parallax = {
        x = 0.7,
        y = 0.8,
        offset_x = 1,
        offset_y = 1,
    },
    chefe = { x = 2273.5, y = 272.5, w = 35, h = 33 },
    cela = { x = 2528, y = 400, w = 16, h = 16 },
    botaocela = { x = 2536.0, y = 344.0, w = 16, h = 16 },
    initrava = { x = 2016, y = 400 },
    travafim = { x = 2480, y = 400 },
    superficies = {
        { pontos = { 0, 752, 512, 752 } },
        { pontos = { 512, 848, 576, 848 } },
        { pontos = { 576, 720, 704, 720 } },
        { pontos = { 704, 944, 992, 944 } },
        { pontos = { 992, 976, 1344, 976 } },
        { pontos = { 768, 656, 1024, 656 } },
        { pontos = { 1024, 656, 1042.95, 649.6 } },
        { pontos = { 1042.95, 649.6, 1055.39, 647.62 } },
        { pontos = { 1055.39, 647.62, 1060.62, 644.94 } },
        { pontos = { 1060.62, 644.94, 1280.41, 535.4 } },
        { pontos = { 1280.41, 535.4, 1290.87, 531.87 } },
        { pontos = { 1290.87, 531.87, 1299.35, 529.32 } },
        { pontos = { 1299.35, 529.32, 1315.88, 526.49 } },
        { pontos = { 1315.88, 526.49, 1319.7, 525.08 } },
        { pontos = { 1319.7, 525.08, 1331.29, 521.12 } },
        { pontos = { 1331.29, 521.12, 1337.93, 519.85 } },
        { pontos = { 1337.93, 519.85, 1351.36, 519.71 } },
        { pontos = { 1351.36, 519.71, 1361.39, 522.68 } },
        { pontos = { 1361.39, 522.68, 1376.38, 527.34 } },
        { pontos = { 1376.38, 527.34, 1383.58, 527.91 } },
        { pontos = { 1383.58, 527.91, 1600, 528 } },
        { pontos = { 1600, 528, 1612.4, 523.2 } },
        { pontos = { 1612.4, 523.2, 1621.37, 520.77 } },
        { pontos = { 1621.37, 520.77, 1631.28, 519.65 } },
        { pontos = { 1631.28, 519.65, 1632.77, 519.08 } },
        { pontos = { 1632.77, 519.08, 1856.14, 407.3 } },
        { pontos = { 1856.14, 407.3, 1869.42, 403.01 } },
        { pontos = { 1869.42, 403.01, 1881.57, 400.01 } },
        { pontos = { 1881.57, 400.01, 3040, 400 } },
    },
    tetos = {
    },
    paredes = {
        { x = 0, y1 = 592, y2 = 752 },
        { x = 512, y1 = 752, y2 = 848 },
        { x = 576, y1 = 720, y2 = 848 },
        { x = 704, y1 = 720, y2 = 944 },
        { x = 992, y1 = 944, y2 = 1024 },
        { x = 1344, y1 = 976, y2 = 1024 },
        { x = 3040, y1 = 192, y2 = 400 },
    },
    danos = {
        { x = 513.97, y = 821.15, largura = 61.91, altura = 26.87 },
        { x = 995.75, y = 951.75, largura = 348.31, altura = 24.47 },
    },
    joga = {
    },
    pendulos = {
    },
    molas = {
        { tipo = 'mola_cima', classe = 'mola', x = 719.5, y = 934.0, largura = 16.0, altura = 10.0, forca = 14, raio = 0, eixo_x = 0, eixo_y1 = 0, eixo_y2 = 0 },
    },
    aneis = {
        { x = 835.0, y = 924.5, coletado = false },
        { x = 835.0, y = 903.5, coletado = false },
        { x = 853.0, y = 903.5, coletado = false },
        { x = 853.0, y = 924.5, coletado = false },
        { x = 869.0, y = 903.5, coletado = false },
        { x = 869.0, y = 924.5, coletado = false },
        { x = 885.0, y = 903.5, coletado = false },
        { x = 885.0, y = 924.5, coletado = false },
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
        { tipo = 'monitores', nome = 'monitor_vida', x = 935, y = 924, w = 16, h = 16, coletado = false, ativo = true },
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