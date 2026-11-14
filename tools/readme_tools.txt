Gerar terreno:

gh:
python3 tools/gerar_terreno.py fases/greenhill/gh1.json fases/greenhill/gh1_terreno.lua
python3 tools/gerar_terreno.py fases/greenhill/gh2.json fases/greenhill/gh2_terreno.lua

tst:
python3 tools/gerar_terreno.py fases/greenhill/tst1.json fases/greenhill/tst1_terreno.lua


Recuperar .Json
Como usar:

Rode: python3 recuperar_mapa.py

Ele vai gerar um arquivo greenhill_recuperado.json.
Abra no Tiled e verá as linhas de colisão e as caixas de dano/joga de volta (sem os tiles visuais, mas você pode redesenhar).

