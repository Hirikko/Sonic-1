Gerar terreno:

python3 lupinho-sdk/src/tools/gerar_terreno.py lupinho-sdk/src/fases/greenhill/gh1.json lupinho-sdk/src/fases/greenhill/gh1_terreno.lua
python3 lupinho-sdk/src/tools/gerar_terreno.py lupinho-sdk/src/fases/greenhill/gh2.json lupinho-sdk/src/fases/greenhill/gh2_terreno.lua
python3 lupinho-sdk/src/tools/gerar_terreno.py lupinho-sdk/src/fases/greenhill/gh3.json lupinho-sdk/src/fases/greenhill/gh3_terreno.lua
python3 lupinho-sdk/src/tools/gerar_terreno.py lupinho-sdk/src/fases/bridgezone/bz1.json lupinho-sdk/src/fases/bridgezone/bz1_terreno.lua
python3 lupinho-sdk/src/tools/gerar_terreno.py lupinho-sdk/src/fases/junglezone/jz1.json lupinho-sdk/src/fases/junglezone/jz1_terreno.lua
python3 lupinho-sdk/src/tools/gerar_terreno.py lupinho-sdk/src/fases/labyrinthzone/lz1.json lupinho-sdk/src/fases/labyrinthzone/lz1_terreno.lua
python3 lupinho-sdk/src/tools/gerar_terreno.py lupinho-sdk/src/fases/scrapbrain/sc1.json lupinho-sdk/src/fases/scrapbrain/sc1_terreno.lua
python3 lupinho-sdk/src/tools/gerar_terreno.py lupinho-sdk/src/fases/skybasezone/sbz1.json lupinho-sdk/src/fases/skybasezone/sbz1_terreno.lua
python3 lupinho-sdk/src/tools/gerar_terreno.py lupinho-sdk/src/fases/specialzone/sp1.json lupinho-sdk/src/fases/specialzone/sp1_terreno.lua
python3 lupinho-sdk/src/tools/gerar_terreno.py lupinho-sdk/src/fases/greenhill/tst1.json lupinho-sdk/src/fases/greenhill/tst1_terreno.lua

tst:
python3 lupinho-sdk/src/tools/gerar_terreno.py lupinho-sdk/src/fases/greenhill/tst1.json lupinho-sdk/src/fases/greenhill/tst1_terreno.lua

Recuperar .Json
Como usar:

Rode: python3 recuperar_mapa.py

Ele vai gerar um arquivo greenhill_recuperado.json.
Abra no Tiled e verá as linhas de colisão e as caixas de dano/joga de volta (sem os tiles visuais, mas você pode redesenhar).

