local Timer = {}

local TEMPO_MAXIMO = 599 -- 9:59 (limite de tempo, morre se chegar)
local FPS = 60

-- Inicia em 0:00 e vai subindo até 9:59
Timer.segundos = 0
Timer.contador_frames = 0
Timer.esgotado = false

function Timer.init()
    Timer.segundos = 0
    Timer.contador_frames = 0
    Timer.esgotado = false
end

function Timer.update()
    if Timer.esgotado then return end

    Timer.contador_frames = Timer.contador_frames + 1

    if Timer.contador_frames >= FPS then
        Timer.contador_frames = 0
        Timer.segundos = Timer.segundos + 1

        if Timer.segundos >= TEMPO_MAXIMO then
            Timer.segundos = TEMPO_MAXIMO
            Timer.esgotado = true
        end
    end
end

function Timer.draw()
    local minutos = math.floor(Timer.segundos / 60)
    local segs = Timer.segundos % 60
    local texto = string.format("TIME  %d:%02d", minutos, segs)
    -- Vermelho quando faltar 60 segundos pra acabar
    local cor = Timer.segundos >= (TEMPO_MAXIMO - 60) and 12 or 7
    ui.print(texto, 10, 50, cor)
end

return Timer
