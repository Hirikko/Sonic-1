import json, sys, math

def main():
    if len(sys.argv) < 3:
        print("Uso: python3 tools/gerar_terreno.py maps/gh1.json dados/terreno.lua")
        return

    with open(sys.argv[1], 'r', encoding='utf-8') as f:
        data = json.load(f)

    superficies, paredes, danos, joga, pendulos, outros, molas, aneis = [], [], [], [], [], [], [], []
    inimigos, plataformas_flutuantes, esmeraldas, areas_agua, sensores_queda, tetos = [], [], [], [], [], []
    pontos_ar = []
    chefe_obj = None
    cela_obj = None
    botaocela_obj = None
    initrava_obj = None
    travafim_obj = None
    plataformas_chefe = []

    spawn_x, spawn_y = 100, 240
    parallax_data = None

    for layer in data.get('layers', []):
        layer_name = layer.get('name')
        layer_type = layer.get('type')

        if layer_name == 'fundo':
            px = layer.get('parallaxx', 0.8)
            py = layer.get('parallaxy', 0.8)
            ox = layer.get('offsetx', 0)
            oy = layer.get('offsety', 0)
            if oy == 0: oy = -11
            parallax_data = {"x": px, "y": py, "offset_x": ox, "offset_y": oy}

        off_x = layer.get('offsetx', 0) or 0
        off_y = layer.get('offsety', 0) or 0

        if layer_type == 'objectgroup':
            if layer_name == 'chefe':
                for obj in layer.get('objects', []):
                    obj_class = obj.get('class') or obj.get('type') or ''
                    obj_name = obj.get('name', '')

                    if obj_name == 'initrava':
                        initrava_obj = {"x": round(obj['x'] + off_x, 2), "y": round(obj['y'] + off_y, 2)}
                    elif obj_name == 'travafim':
                        travafim_obj = {"x": round(obj['x'] + off_x, 2), "y": round(obj['y'] + off_y, 2)}
                    elif obj_name == 'eggman':
                        chefe_obj = {
                            "x": round(obj.get('x', 0) + off_x + obj.get('width', 0) / 2, 2),
                            "y": round(obj.get('y', 0) + off_y + obj.get('height', 0) / 2, 2),
                            "w": round(obj.get('width', 0), 2),
                            "h": round(obj.get('height', 0), 2)
                        }
                    elif obj_class == 'chefe' or obj.get('type') == 'chefe':
                        plataformas_chefe.append({
                            "x": round(obj.get('x', 0) + off_x, 2),
                            "y": round(obj.get('y', 0) + off_y, 2),
                            "w": round(obj.get('width', 0), 2),
                            "h": round(obj.get('height', 0), 2)
                        })
                continue

            if layer_name == 'inimigos':
                for obj in layer.get('objects', []):
                    props = {p['name']: p['value'] for p in obj.get('properties', [])}
                    direcao_val = props.get('dir', '')
                    inimigos.append({
                        "tipo": obj.get('name', ''),
                        "x": round(obj.get('x', 0) + off_x + obj.get('width', 0) / 2, 2),
                        "y": round(obj.get('y', 0) + off_y + obj.get('height', 0) / 2, 2),
                        "w": round(obj.get('width', 0), 2),
                        "h": round(obj.get('height', 0), 2),
                        "direcao": direcao_val
                    })
                continue

            if layer_name == 'sonic':
                for obj in layer.get('objects', []):
                    centro_tiled_y = obj.get('y', 0) + off_y + obj.get('height', 0) / 2
                    spawn_y = round(centro_tiled_y - 16, 2)
                    spawn_x = round(obj.get('x', 0) + off_x + obj.get('width', 0) / 2, 2)
                continue

            if layer_name == 'agua':
                for obj in layer.get('objects', []):
                    if obj.get('name') == 'ar':
                        pontos_ar.append({
                            "x": round(obj.get('x', 0) + off_x + obj.get('width', 0) / 2, 2),
                            "y": round(obj.get('y', 0) + off_y + obj.get('height', 0) / 2, 2)
                        })
                        continue

                    poly = obj.get('polygon', []) or obj.get('polyline', [])
                    if poly:
                        xs = [obj['x'] + p['x'] + off_x for p in poly]
                        ys = [obj['y'] + p['y'] + off_y for p in poly]
                        # bbox fica como pre-filtro; os pontos sao a forma real.
                        # A agua da BZ1 e um poligono concavo (cachoeiras + rio)
                        # cujo bbox cobria terra seca.
                        pts = []
                        for p in poly:
                            pts.append(round(obj['x'] + p['x'] + off_x, 2))
                            pts.append(round(obj['y'] + p['y'] + off_y, 2))
                        areas_agua.append({
                            "x": round(min(xs), 2), "y": round(min(ys), 2),
                            "w": round(max(xs) - min(xs), 2), "h": round(max(ys) - min(ys), 2),
                            "pontos": pts
                        })
                continue

            for obj in layer.get('objects', []):
                obj_type = obj.get('type') or obj.get('class') or obj.get('name') or ''
                poly = obj.get('polyline', [])
                polygon = obj.get('polygon', [])

                if layer_name == 'colisao_objetos':
                    if obj.get('name') == 'cela':
                        cela_obj = {"x": round(obj.get('x', 0) + off_x, 2), "y": round(obj.get('y', 0) + off_y, 2), "w": round(obj.get('width', 0), 2), "h": round(obj.get('height', 0), 2)}
                        continue
                    elif obj.get('name') == 'botaocela':
                        botaocela_obj = {"x": round(obj.get('x', 0) + off_x + obj.get('width', 0) / 2, 2), "y": round(obj.get('y', 0) + off_y + obj.get('height', 0) / 2, 2), "w": round(obj.get('width', 0), 2), "h": round(obj.get('height', 0), 2)}
                        continue

                if not poly and not polygon:
                    w, h = obj.get('width', 0), obj.get('height', 0)
                    if w > 0 and h > 0:
                        x, y = obj['x'] + off_x, obj['y'] + off_y
                        if layer_name in ('colisao_chao', 'colisao_teto'):
                            lista_alvo = superficies if layer_name == 'colisao_chao' else tetos
                            lista_alvo.append({"pontos": [round(x, 2), round(y, 2), round(x+w, 2), round(y, 2)]})
                            lista_alvo.append({"pontos": [round(x, 2), round(y+h, 2), round(x+w, 2), round(y+h, 2)]})
                            if h > 16:
                                paredes.append({"x": round(x, 2), "y1": round(y, 2), "y2": round(y+h, 2)})
                                paredes.append({"x": round(x+w, 2), "y1": round(y, 2), "y2": round(y+h, 2)})
                        elif layer_name == 'colisao_dano':
                            danos.append({"x": round(x, 2), "y": round(y, 2), "largura": round(w, 2), "altura": round(h, 2)})
                        elif layer_name == 'colisao_objetos':
                            if obj_type == 'colisao_joga':
                                joga.append({"x": round(x - 8, 2), "y": round(y - 8, 2), "largura": round(w + 16, 2), "altura": round(h + 16, 2)})
                            elif obj_type.startswith('mola') or obj.get('name', '').startswith('mola'):
                                tipo_mola = obj.get('name', '').lower()
                                if not tipo_mola.startswith('mola'): tipo_mola = obj_type
                                props_m = {p['name']: p['value'] for p in obj.get('properties', [])}
                                classe_m = obj_type if obj_type.startswith('mola') else 'mola'
                                mx, my, mw, mh = x, y, w, h
                                rot_m = obj.get('rotation', 0) or 0
                                # Tiled gira o retangulo em torno de (x,y), sentido horario.
                                # Aplicado so em mola_esp para nao alterar as molas ja
                                # funcionando de gh1/gh2/gh3.
                                if classe_m == 'mola_esp' and abs(rot_m) > 0.01:
                                    rad_m = math.radians(rot_m)
                                    cs_m, sn_m = math.cos(rad_m), math.sin(rad_m)
                                    cantos_m = []
                                    for dx_m, dy_m in ((0, 0), (w, 0), (w, h), (0, h)):
                                        cantos_m.append((x + dx_m * cs_m - dy_m * sn_m,
                                                         y + dx_m * sn_m + dy_m * cs_m))
                                    xs_m = [c[0] for c in cantos_m]
                                    ys_m = [c[1] for c in cantos_m]
                                    mx, my = min(xs_m), min(ys_m)
                                    mw, mh = max(xs_m) - mx, max(ys_m) - my
                                ent_m = {"tipo": tipo_mola, "classe": classe_m,
                                         "x": round(mx, 2), "y": round(my, 2),
                                         "largura": round(mw, 2), "altura": round(mh, 2),
                                         "forca": props_m.get('forca', 0),
                                         "raio": 0, "eixo_x": 0, "eixo_y1": 0, "eixo_y2": 0}
                                if tipo_mola == 'mola_espiral':
                                    raio_m = w / 2.0
                                    ent_m["raio"] = round(raio_m, 2)
                                    ent_m["eixo_x"] = round(x + w / 2.0, 2)
                                    ent_m["eixo_y1"] = round(y + raio_m, 2)
                                    ent_m["eixo_y2"] = round(y + h - raio_m, 2)
                                molas.append(ent_m)
                            elif obj_type == 'flutua':
                                plataformas_flutuantes.append({"x": round(x, 2), "y": round(y, 2), "largura": round(w, 2), "altura": round(h, 2), "x_inicial": round(x, 2), "amplitude": 64, "velocidade": 1.0, "direcao": 1})
                            elif obj_type in ('monitores', 'venceu'):
                                outros.append({"tipo": obj_type, "nome": obj.get('name', ''), "x": round(x, 2), "y": round(y, 2), "w": round(w, 2), "h": round(h, 2), "coletado": False, "ativo": True})
                            elif obj_type == 'obj_chave':
                                esmeraldas.append({"x": round(x + w/2, 2), "y": round(y + h/2, 2), "coletado": False})
                        elif layer_name == 'aneis':
                            aneis.append({"x": round(x + w/2, 2), "y": round(y + h/2, 2), "coletado": False})
                    continue

                pontos = poly if poly else polygon
                if polygon and len(polygon) > 0: pontos = polygon + [polygon[0]]

                if layer_name in ('colisao_chao', 'colisao_teto'):
                    lista_alvo = superficies if layer_name == 'colisao_chao' else tetos
                    prev_x, prev_y = obj['x'] + pontos[0]['x'] + off_x, obj['y'] + pontos[0]['y'] + off_y
                    for p in pontos[1:]:
                        curr_x, curr_y = obj['x'] + p['x'] + off_x, obj['y'] + p['y'] + off_y
                        dx, dy = abs(curr_x - prev_x), abs(curr_y - prev_y)
                        if dx < 1.5 and dy > 1.5:
                            paredes.append({"x": round(prev_x, 2), "y1": round(min(prev_y, curr_y), 2), "y2": round(max(prev_y, curr_y), 2)})
                        else:
                            lista_alvo.append({"pontos": [round(prev_x, 2), round(prev_y, 2), round(curr_x, 2), round(curr_y, 2)]})
                        prev_x, prev_y = curr_x, curr_y
                elif layer_name == 'colisao_dano':
                    xs = [obj['x'] + p['x'] + off_x for p in pontos]
                    ys = [obj['y'] + p['y'] + off_y for p in pontos]
                    danos.append({"x": round(min(xs), 2), "y": round(min(ys), 2), "largura": round(max(xs) - min(xs), 2), "altura": round(max(ys) - min(ys), 2)})
                elif layer_name == 'colisao_objetos':
                    if obj_type == 'venceu':
                        xs = [obj['x'] + p['x'] + off_x for p in pontos]
                        ys = [obj['y'] + p['y'] + off_y for p in pontos]
                        outros.append({"tipo": obj_type, "nome": obj.get('name', ''), "x": round(min(xs), 2), "y": round(min(ys), 2), "w": round(max(xs) - min(xs), 2), "h": round(max(ys) - min(ys), 2), "coletado": False, "ativo": True})
                    elif obj.get('name') == 'queda':
                        xs = [obj['x'] + p['x'] + off_x for p in pontos]
                        ys = [obj['y'] + p['y'] + off_y for p in pontos]
                        sensores_queda.append({"x": round(min(xs), 2), "y": round(min(ys), 2), "w": round(max(xs) - min(xs), 2), "h": round(max(ys) - min(ys), 2)})
                    elif obj_type == 'pendulo':
                        if len(pontos) >= 2:
                            p1, p2 = pontos[0], pontos[1]
                            x1 = obj['x'] + p1['x'] + off_x
                            y1 = obj['y'] + p1['y'] + off_y
                            x2 = obj['x'] + p2['x'] + off_x
                            y2 = obj['y'] + p2['y'] + off_y
                            comprimento = math.sqrt((x2 - x1)**2 + (y2 - y1)**2)
                            angulo_inicial = math.atan2(x2 - x1, y2 - y1)
                            pendulos.append({"x": round(x1, 2), "y": round(y1, 2), "comprimento": round(comprimento, 2), "angulo_inicial": round(angulo_inicial, 4)})
                    elif obj_type == 'colisao_joga' or obj.get('name') == 'colisao_joga':
                        xs = [obj['x'] + p['x'] + off_x for p in pontos]
                        ys = [obj['y'] + p['y'] + off_y for p in pontos]
                        min_x, max_x = min(xs), max(xs)
                        min_y, max_y = min(ys), max(ys)
                        joga.append({"x": round(min_x - 8, 2), "y": round(min_y - 8, 2), "largura": round((max_x - min_x) + 16, 2), "altura": round((max_y - min_y) + 16, 2)})

    linhas = []
    linhas.append("local Terreno = {")
    linhas.append(f"    spawn_x = {spawn_x}, spawn_y = {spawn_y},")

    if parallax_data:
        linhas.append("    parallax = {")
        for k, v in parallax_data.items():
            linhas.append(f"        {k} = {v},")
        linhas.append("    },")

    if chefe_obj: linhas.append(f"    chefe = {{ x = {chefe_obj['x']}, y = {chefe_obj['y']}, w = {chefe_obj['w']}, h = {chefe_obj['h']} }},")
    if cela_obj: linhas.append(f"    cela = {{ x = {cela_obj['x']}, y = {cela_obj['y']}, w = {cela_obj['w']}, h = {cela_obj['h']} }},")
    if botaocela_obj: linhas.append(f"    botaocela = {{ x = {botaocela_obj['x']}, y = {botaocela_obj['y']}, w = {botaocela_obj['w']}, h = {botaocela_obj['h']} }},")
    if initrava_obj: linhas.append(f"    initrava = {{ x = {initrava_obj['x']}, y = {initrava_obj['y']} }},")
    if travafim_obj: linhas.append(f"    travafim = {{ x = {travafim_obj['x']}, y = {travafim_obj['y']} }},")

    def escrever_tabela(nome, itens, formatar):
        linhas.append(f"    {nome} = {{")
        for item in itens:
            linhas.append("        " + formatar(item))
        linhas.append("    },")

    escrever_tabela("superficies", superficies, lambda s: "{{ pontos = {{ {0}, {1}, {2}, {3} }} }},".format(*s['pontos']))
    escrever_tabela("tetos", tetos, lambda s: "{{ pontos = {{ {0}, {1}, {2}, {3} }} }},".format(*s['pontos']))
    escrever_tabela("paredes", paredes, lambda p: "{{ x = {0}, y1 = {1}, y2 = {2} }},".format(p['x'], p['y1'], p['y2']))
    escrever_tabela("danos", danos, lambda d: "{{ x = {0}, y = {1}, largura = {2}, altura = {3} }},".format(d['x'], d['y'], d['largura'], d['altura']))
    escrever_tabela("joga", joga, lambda j: "{{ x = {0}, y = {1}, largura = {2}, altura = {3} }},".format(j['x'], j['y'], j['largura'], j['altura']))
    escrever_tabela("pendulos", pendulos, lambda p: "{{ x = {0}, y = {1}, comprimento = {2}, angulo_inicial = {3} }},".format(p['x'], p['y'], p['comprimento'], p['angulo_inicial']))
    escrever_tabela("molas", molas, lambda m: "{{ tipo = '{0}', classe = '{1}', x = {2}, y = {3}, largura = {4}, altura = {5}, forca = {6}, raio = {7}, eixo_x = {8}, eixo_y1 = {9}, eixo_y2 = {10} }},".format(m['tipo'], m.get('classe', 'mola'), m['x'], m['y'], m['largura'], m['altura'], m.get('forca', 0), m.get('raio', 0), m.get('eixo_x', 0), m.get('eixo_y1', 0), m.get('eixo_y2', 0)))
    escrever_tabela("aneis", aneis, lambda a: "{{ x = {0}, y = {1}, coletado = false }},".format(a['x'], a['y']))
    escrever_tabela("esmeraldas", esmeraldas, lambda e: "{{ x = {0}, y = {1}, coletado = false }},".format(e['x'], e['y']))
    escrever_tabela("areas_agua", areas_agua, lambda a: "{{ x = {0}, y = {1}, w = {2}, h = {3}, pontos = {{ {4} }} }},".format(a['x'], a['y'], a['w'], a['h'], ", ".join(str(v) for v in a.get('pontos', []))))
    escrever_tabela("pontos_ar", pontos_ar, lambda p: "{{ x = {0}, y = {1} }},".format(p['x'], p['y']))
    escrever_tabela("sensores_queda", sensores_queda, lambda s: "{{ x = {0}, y = {1}, w = {2}, h = {3} }},".format(s['x'], s['y'], s['w'], s['h']))
    escrever_tabela("outros", outros, lambda o: "{{ tipo = '{0}', nome = '{1}', x = {2}, y = {3}, w = {4}, h = {5}, coletado = false, ativo = true }},".format(o['tipo'], o['nome'], o['x'], o['y'], o['w'], o['h']))
    escrever_tabela("inimigos", inimigos, lambda i: "{{ tipo = '{0}', x = {1}, y = {2}, w = {3}, h = {4}, direcao = '{5}' }},".format(i['tipo'], i['x'], i['y'], i['w'], i['h'], i.get('direcao', '')))
    escrever_tabela("plataformas_flutuantes", plataformas_flutuantes, lambda p: "{{ x = {0}, y = {1}, largura = {2}, altura = {3}, x_inicial = {4}, amplitude = {5}, velocidade = {6}, direcao = {7} }},".format(p['x'], p['y'], p['largura'], p['altura'], p['x_inicial'], p['amplitude'], p['velocidade'], p['direcao']))
    escrever_tabela("plataformas_chefe", plataformas_chefe, lambda p: "{{ x = {0}, y = {1}, w = {2}, h = {3} }},".format(p['x'], p['y'], p['w'], p['h']))

    linhas.append("}")
    linhas.append("return Terreno")

    with open(sys.argv[2], 'w', encoding='utf-8') as f:
        f.write("\n".join(linhas))

    print("--- Relatório de Geração de Terreno ---")
    if chefe_obj: print("Chefe (Eggman) encontrado!")
    if cela_obj: print("Cela encontrada!")
    if botaocela_obj: print("Botão da Cela encontrado!")
    if initrava_obj: print("Sensor initrava encontrado!")
    if travafim_obj: print("Sensor travafim encontrado!")
    if plataformas_chefe: print(f"Plataformas do Chefe: {len(plataformas_chefe)}")
    print(f"Aneis: {len(aneis)}")
    print(f"Esmeraldas: {len(esmeraldas)}")
    print(f"Inimigos: {len(inimigos)}")
    print(f"Molas: {len(molas)}")
    print(f"Plataformas Flutuantes: {len(plataformas_flutuantes)}")
    print(f"Outros Objetos (Monitores/Placa): {len(outros)}")
    print(f"Áreas de Água: {len(areas_agua)}")
    print(f"Pontos de Ar: {len(pontos_ar)}")
    print(f"Sensores de Queda: {len(sensores_queda)}")
    print(f"Pêndulos: {len(pendulos)}")
    print(f"Danos (Espetos): {len(danos)}")
    print(f"Joga (Gatilhos): {len(joga)}")
    print(f"Tetos: {len(tetos)}")
    if parallax_data: print(f"Parallax: {parallax_data}")
    else: print("Parallax: não definido (usará padrão)")
    print("---------------------------------------")
    print("Terreno gerado com sucesso!")

if __name__ == '__main__':
    main()
