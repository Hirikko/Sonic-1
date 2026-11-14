local Timer = {}

local TEMPO_INICIAL = 599 -- 9 minutos e 59 segundos
local FPS = 60

-- Inicializa direto na carga do arquivo
Timer.segundos = TEMPO_INICIAL
Timer.contador_frames = 0
Timer.esgotado = false

function Timer.init()
    Timer.segundos = TEMPO_INICIAL
    Timer.contador_frames = 0
    Timer.esgotado = false
end

function Timer.update()
    if Timer.esgotado then return end

    Timer.contador_frames = Timer.contador_frames + 1

    if Timer.contador_frames >= FPS then
        Timer.contador_frames = 0
        Timer.segundos = Timer.segundos - 1

        if Timer.segundos <= 0 then
            Timer.segundos = 0
            Timer.esgotado = true
        end
    end
end

function Timer.draw()
    local minutos = math.floor(Timer.segundos / 60)
    local segs = Timer.segundos % 60
    local texto = string.format("TIME  %d:%02d", minutos, segs)
    local cor = Timer.segundos < 60 and 12 or 7
    ui.print(texto, 10, 50, cor)
end

return Timer
