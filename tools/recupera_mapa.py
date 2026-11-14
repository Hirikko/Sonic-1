import re
import json
import sys

def extrair_tabela_lua(conteudo, nome_tabela):
    # Encontra a chave e extrai o bloco da tabela
    padrao = rf'_M\["{nome_tabela}"\] = \{{(.*?)\n\}}'
    match = re.search(padrao, conteudo, re.DOTALL)
    if not match:
        return None
    
    bloco = match.group(1)
    # Extrai os valores chave=valor (ex: [123] = 45)
    itens = re.findall(r'\[(\d+)\]\s*=\s*(\d+)', bloco)
    return {int(k): int(v) for k, v in itens}

def main():
    if len(sys.argv) < 3:
        print("Uso: python3 tools/recuperar_mapa.py <arquivo.lua> <saida.json>")
        return

    with open(sys.argv[1], 'r', encoding='utf-8') as f:
        conteudo = f.read()

    # Extrai metadados básicos
    w_match = re.search(r'width\s*=\s*(\d+)', conteudo)
    h_match = re.search(r'height\s*=\s*(\d+)', conteudo)
    ts_match = re.search(r'tile_size\s*=\s*(\d+)', conteudo)
    
    width = int(w_match.group(1)) if w_match else 420
    height = int(h_match.group(1)) if h_match else 32
    tile_size = int(ts_match.group(1)) if ts_match else 16

    # Cria a estrutura base do JSON do Tiled
    mapa_json = {
        "compressionlevel": -1,
        "height": height,
        "infinite": False,
        "layers": [],
        "nextlayerid": 10,
        "nextobjectid": 100,
        "orientation": "orthogonal",
        "renderorder": "right-down",
        "tiledversion": "1.12.2",
        "tileheight": tile_size,
        "tilewidth": tile_size,
        "type": "map",
        "version": "1.10",
        "width": width,
        "tilesets": [
            {
                "columns": 12,
                "firstgid": 1,
                "image": "../tilemap/licgrenhll.png",
                "imageheight": 224,
                "imagewidth": 208,
                "margin": 16,
                "name": "licgrenhll",
                "spacing": 0,
                "tilecount": 156,
                "tileheight": 16,
                "tilewidth": 16
            },
            {
                "columns": 12,
                "firstgid": 157,
                "image": "../tilemap/licgrenhll2.png",
                "imageheight": 224,
                "imagewidth": 208,
                "margin": 16,
                "name": "licgrenhll2",
                "spacing": 0,
                "tilecount": 156,
                "tileheight": 16,
                "tilewidth": 16
            }
        ]
    }

    # Recupera camadas de Tiles
    for nome in ["mapa", "nuvens", "montanhas"]:
        dados = extrair_tabela_lua(conteudo, nome)
        if dados:
            # O Tiled espera um array unidimensional plano para Tile Layers
            array_completo = [0] * (width * height)
            for idx, val in dados.items():
                if idx < len(array_completo):
                    array_completo[idx] = val
            
            mapa_json["layers"].append({
                "data": array_completo,
                "height": height,
                "id": len(mapa_json["layers"]) + 1,
                "name": nome,
                "opacity": 1,
                "type": "tilelayer",
                "visible": True,
                "width": width,
                "x": 0,
                "y": 0
            })

    # Como as colisões são objetos complexos, o script tenta recriá-las (você pode precisar ajustar manualmente se forem muitas)
    # Para o nosso caso, o JSON de colisão já foi recuperado manualmente no passo anterior.
    
    with open(sys.argv[2], 'w', encoding='utf-8') as f:
        json.dump(mapa_json, f, indent=2, ensure_ascii=False)

    print(f"Mapa recuperado com sucesso em {sys.argv[2]}")

if __name__ == "__main__":
    main()