local Transicao = {
    ativa = false,
    progresso = 0,
    velocidade = 0.04,
    direcao = 0
}

local function limitar(valor)
    return math.max(0, math.min(valor, 1))
end

function Transicao.iniciar()
    Transicao.ativa = true
    Transicao.progresso = 0
    Transicao.direcao = 1
end

function Transicao.update()
    if not Transicao.ativa then
        return false
    end

    Transicao.progresso = Transicao.progresso + Transicao.velocidade * Transicao.direcao
    Transicao.progresso = limitar(Transicao.progresso)

    if Transicao.progresso >= 1 then
        Transicao.direcao = -1
    elseif Transicao.progresso <= 0 then
        Transicao.ativa = false
        Transicao.direcao = 0
    end

    return Transicao.ativa
end

function Transicao.aplicar(Palette)
    assert(Palette, "Transicao.aplicar requer Palette")
    local fator = 1 - Transicao.progresso
    for i = 1, #Palette do
        local cor = Palette[i]
        local vermelho = (cor >> 10) & 31
        local verde    = (cor >> 5)  & 31
        local azul     =  cor        & 31

        vermelho = math.floor(vermelho * fator)
        verde    = math.floor(verde    * fator)
        azul     = math.floor(azul     * fator)

        ui.palset(i - 1, (vermelho << 10) | (verde << 5) | azul)
    end
end

return Transicao
