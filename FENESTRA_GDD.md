# Fenestra — Game Design Document
> Referência de desenvolvimento para uso com Claude Code

---

## Visão geral

**Nome:** Fenestra
**Engine:** Godot 4.5+
**Plataforma:** Mobile (Android e iOS)
**Gênero:** Arcade / Precision timing
**Inspiração:** Orbia (iPad/mobile)
**Conceito em uma frase:** Mova-se entre círculos giratórios acertando o momento certo para passar pelos arcos livres e desviar dos obstáculos.

---

## Mecânica central

O jogador ocupa o **centro** de um círculo e, ao tocar/clicar, move-se instantaneamente para o **centro do próximo círculo** da sequência (estilo Orbia). Os círculos giram continuamente. O desafio está em tocar no momento em que o ângulo de chegada coincide com um segmento livre e o círculo está ativo.

> **Ângulo de chegada:** direção fixa da linha que conecta os dois círculos. O jogador não controla o ângulo — só o timing.

### 1. Arcos bloqueados
A borda de cada círculo tem segmentos **livres** e segmentos **bloqueados**.
- O jogador só pode atravessar um segmento **livre**.
- Atravessar um segmento bloqueado = morte.
- Os segmentos são visualmente distintos (cor da borda: verde = livre, cinza escuro = bloqueado).
- Os arcos giram junto com o `RotationRoot` do círculo.

### 2. Ativação pulsante
Cada círculo alterna entre estado **ativo** e **inativo** em ciclos.
- O jogador só pode pousar num círculo **ativo**.
- Pousar num círculo inativo = morte.
- O estado é comunicado pela opacidade do círculo inteiro (100% = ativo, ~30% = inativo).
- Um indicador de progresso ao redor da borda mostra quanto tempo falta para o próximo estado mudar.

### 3. Orbiters
Pequenas esferas que orbitam ao redor de certos círculos em padrões variados.
- Se o jogador chegar a um círculo que possui orbiters, eles fazem **fade out** e somem.
- **Contato com orbiter durante o movimento = morte** (verificado frame a frame em `_check_orbiter_collision()`).
- Tamanhos, velocidades e ângulos de início variáveis por orbiter.
- Podem orbitar em sentidos e raios diferentes no mesmo círculo.
- Gerados proceduralmente em `_ready()` com `orbiter_count` e `orbiter_base_radius_mult`.

### 5. Círculo espelho

Variante do círculo de arco onde **a cada pouso as regras invertem**.
- Ao pousar: `flip_mirror()` é chamado → direção de rotação inverte, verde e cinza trocam
- **Estado inicial:** rotação normal, verde = livre, cinza = bloqueado
- **Após 1º pouso:** rotação inversa, o que era cinza agora é verde e vice-versa
- **Após 2º pouso:** volta ao estado inicial — e assim ciclicamente
- **Lógica de detecção (XOR):** `bloqueado = (in_arc != _mirror_flipped)`
  - Estado normal (`_mirror_flipped=false`): bloqueado se está dentro de um arco
  - Estado invertido (`_mirror_flipped=true`): bloqueado se está **fora** de um arco
- **Saída:** `can_exit()` usa a mesma lógica — só pode sair pela zona livre do estado atual
- **Visual:** `ArcVisual.mirror_flipped` inverte as cores (anel cinza + arcos bloqueados em verde)
- Controlado pelo flag `mirror_mode: bool` em `Circle.gd`
- `_mirror_flipped: bool` é o estado interno (começa `false`, toggled a cada pouso)

### 4. Orbiter perseguidor
Variante do círculo com orbiters onde, ao pousar, os orbiters se tornam ameaças ativas.
- Ao pousar: orbiters ficam **vermelhos** e passam para modo `CHASING` — movem-se em direção ao player a 110px/s
- Enquanto no círculo: player deve sair antes que algum chaser alcance o centro (urgência de timing)
- **Contato com chaser enquanto ON_CIRCLE = morte** (verificado em `_check_chaser_collision()`)
- Ao sair do círculo (toque): chasers passam para modo `FLEEING` — voam para longe do centro a 240px/s e fazem fade out
- Se o player morrer no círculo: chasers são liberados automaticamente (`release_chasers()`) antes do respawn
- Controlado pelo flag `orbiter_chaser: bool` em `Circle.gd`; `Game.gd` decide entre `activate_chasers()` ou `clear_orbiters()` ao pousar

### Combinação
Nas fases avançadas, as três condições se aplicam simultaneamente.
A janela combinada nunca deve ser menor que ~400ms (regra de design inegociável).

### Feedback de morte diferenciado
- Morrer em arco bloqueado → player fica vermelho, som de impacto seco
- Morrer em círculo inativo → player fica vermelho, fade rápido
O jogador precisa entender instantaneamente qual condição falhou.

---

## Controles

- **Toque simples** → move o player do centro do círculo atual para o centro do próximo
- O movimento é sempre para o próximo círculo da sequência (sem controle direcional)
- O timing define se o ângulo de chegada cai em arco livre ou bloqueado
- Sem botões, sem joystick — toque único é toda a interface durante o jogo

---

## Estrutura de níveis

Cada nível tem **3 a 5 pulos** (círculos intermediários) entre o início e o checkpoint.

```
[Círculo de partida]  →  [Círculo 1]  →  ...  →  [Círculo N]  →  [Checkpoint]
     sem perigo          perigos variados                           sem perigo
```

- **Círculo de partida:** sem arcos bloqueados, sem pulso, sem orbiters. Ponto de saída puro.
- **Círculos intermediários:** combinação de arcos, pulso e orbiters conforme o nível.
- **Checkpoint:** sem perigo. Ponto de save. Ao chegar aqui, o próximo nível começa.
- Ao morrer: reinicia do círculo de partida do nível atual (sem vidas, estilo arcade).

### Progressão de dificuldade por nível

Cada nível introduz **exatamente uma variável nova**. Nunca subir dois eixos de dificuldade ao mesmo tempo.

| Nível | Arcos bloqueados | Pulso | Orbiters | Velocidade | Novidade |
|-------|-----------------|-------|----------|------------|----------|
| 1 | Pequeno (≈120° bloqueado) | Não | Não | Baixa | Arcos — leitura de timing básico |
| 2 | Médio (≈180°) | Não | Não | Baixa | Janela mais apertada |
| 3 | Nenhum | Sim, lento | Não | Baixa | Pulso isolado |
| 4 | Pequeno | Sim, lento | Não | Média | Primeira combinação, generosa |
| 5 | Nenhum | Não | Sim | Baixa | Orbiters como distração visual |
| 6 | Médio | Sim, médio | Sim | Média | Combinação completa |
| 7 | Dinâmicos | Irregular | Múltiplos | Alta | Leitura em tempo real |

### Regras de balanceamento
- Quando o arco livre é pequeno → o pulso deve ter janela longa
- Quando o pulso é rápido → o arco deve ser grande
- Os dois nunca apertam juntos antes do nível 6+
- Velocidade de rotação: eixo separado, sobe devagar e independentemente

---

## Estrutura do projeto Godot

```
fenestra/
├── project.godot
├── scenes/
│   ├── game/
│   │   └── Game.tscn                  # cena principal do demo (inclui Camera2D)
│   ├── circles/
│   │   ├── CircleBase.tscn            # template base (não usar diretamente em níveis)
│   │   ├── CircleCheckpoint.tscn      # sem perigo, bg_number, respawn
│   │   ├── CircleArc.tscn             # perigo: arcos bloqueados
│   │   ├── CirclePulse.tscn           # perigo: pulso ativo/inativo
│   │   ├── CircleOrbiter.tscn         # perigo: esferas orbitantes
│   │   ├── CircleChaser.tscn          # perigo: orbiters perseguidores
│   │   └── CircleMirror.tscn          # perigo: inversão de arcos a cada pouso
│   ├── entities/
│   │   ├── Player.tscn                # personagem/bolinha (sem Camera2D)
│   │   └── Orbiter.tscn               # esfera orbitante
│   └── ui/
│       ├── UI.tscn                    # HUD provisório (vidas, powerups, pause)
│       └── MainMenu.tscn              # pendente
├── scripts/
│   ├── game/
│   │   └── Game.gd                    # lógica principal, input, checkpoint, câmera
│   ├── circles/
│   │   ├── Circle.gd                  # rotação, arcos, pulso, orbiters
│   │   └── ArcVisual.gd               # desenho de arcos via _draw()
│   ├── entities/
│   │   ├── Player.gd                  # movimento, colisão, morte
│   │   └── Orbiter.gd                 # órbita, fade_and_free
│   ├── ui/
│   │   └── UIOverlay.gd               # desenho do HUD + lógica de pause
│   └── PhaseConfig.gd                 # configuração de fase como Resource — pendente
├── assets/
│   ├── audio/
│   └── sprites/
└── FENESTRA_GDD.md
```

### Cenas especializadas de círculo

Cada cena é uma instância de `CircleBase.tscn` com defaults pré-configurados.
Ao adicionar um novo círculo a um nível, escolha a cena pelo tipo de perigo e sobrescreva apenas o necessário.

| Cena | Perigo | Defaults notáveis |
|------|--------|-------------------|
| `CircleCheckpoint.tscn` | Nenhum | `rotation_speed=0`, `bg_number=1` |
| `CircleArc.tscn` | Arco bloqueado | `rotation_speed=60`, `blocked_arcs=[30°,150°]` |
| `CirclePulse.tscn` | Pulso | `pulse_enabled=true`, `1.3s / 0.8s` |
| `CircleOrbiter.tscn` | Orbiters | `orbiter_count=6`, `radius_mult=1.5` |
| `CircleChaser.tscn` | Orbiters perseguidores | `orbiter_count=3`, `orbiter_chaser=true`, `radius_mult=1.4` |
| `CircleMirror.tscn` | Arcos espelho (inversão a cada pouso) | `rotation_speed=55`, `blocked_arcs=[30°,150°]`, `mirror_mode=true` |

---

## Nós e cenas principais

### Circle.tscn
- **Node2D** (raiz) — `Circle.gd`
  - **Node2D** `RotationRoot` — gira continuamente
    - **Node2D** `ArcVisual` — `ArcVisual.gd`, desenha os arcos via `_draw()`
  - **AnimationPlayer** — disponível para animações futuras
  - **Area2D** + **CollisionShape2D** — detecção de pouso

**Circle.gd — exports:**
```gdscript
@export var rotation_speed: float          # graus por segundo
@export var circle_radius: float           # raio em pixels
@export var blocked_arcs: Array[Vector2]   # pares [inicio_grau, fim_grau] no espaço local
@export var is_active: bool
@export var pulse_enabled: bool
@export var pulse_active_duration: float
@export var pulse_inactive_duration: float
@export var orbiter_count: int
@export var orbiter_base_radius_mult: float
@export var orbiter_chaser: bool           # true = orbiters perseguem ao pousar
@export var mirror_mode: bool              # true = arcos invertem a cada pouso
@export var bg_number: int                 # número exibido no centro (0 = nenhum)
```

**Circle.gd — API pública:**
- `is_landing_valid(world_angle_deg: float) -> bool` — verifica arcos e pulso, emite `landing_failed`
- `clear_orbiters()` — fade out em todos os filhos orbiters (círculos normais)
- `activate_chasers(target: Node2D)` — ativa modo perseguidor em todos os orbiters
- `release_chasers()` — libera chasers (voam para longe e somem)
- `flip_mirror()` — inverte `_mirror_flipped`, nega `rotation_speed`, chama `_sync_arc_visual()`
- `last_fail_reason: String` — `"blocked"` ou `"inactive"`, lido pelo Player após retorno false

### Player.gd — responsabilidades
- Ao iniciar: posiciona-se no centro do círculo de partida
- Ao toque: move-se para o centro do próximo círculo via tween (0.14s, ease in-out quad)
- Ao chegar: calcula o ângulo de aproximação e chama `circle.is_landing_valid()`
- Em caso de morte: fica vermelho, emite `player_died(reason)`
- Estados: `ON_CIRCLE` | `MOVING` | `DEAD`
- Sinais: `landed_on(circle)`, `player_died(reason)`
- **Não possui Camera2D** — câmera é controlada por `Game.gd`

### Orbiter.gd — responsabilidades
- Orbita ao redor do centro do nó pai em modo `ORBITING` (padrão)
- Em modo `CHASING`: move-se em direção ao player a 110px/s, cor vira vermelho
- Em modo `FLEEING`: voa para longe do centro do círculo a 240px/s com fade out
- `fade_and_free()`: se CHASING, chama `stop_chasing()`; caso contrário fade padrão de 0.35s

**Orbiter.gd — exports:**
```gdscript
@export var orbit_radius: float
@export var orbit_speed: float   # graus/s, positivo = horário
@export var sphere_radius: float
@export var sphere_color: Color
@export var start_angle: float   # graus
```

**Orbiter.gd — API pública:**
- `start_chasing(target: Node2D)` — ativa modo CHASING, cor vira vermelho
- `stop_chasing()` — calcula direção de fuga, ativa modo FLEEING com fade out
- `fade_and_free()` — remoção suave (delega para stop_chasing se estiver perseguindo)

### Game.gd — responsabilidades
- Mantém `circle_sequence: Array[NodePath]` (configurado no editor)
- `_draw()`: desenha linhas de conexão entre círculos consecutivos
- Input: toque/clique → libera chasers do círculo atual → `player.move_to(next_circle)`
- `_on_player_landed`: atualiza `current_index`; se `mirror_mode` → `flip_mirror()`; se `orbiter_chaser` → `activate_chasers()`; senão `clear_orbiters()`; salva checkpoint se `bg_number > 0`
- `_on_player_died`: libera chasers se necessário, aguarda 1s, respawn no último checkpoint
- **Controla a Camera2D** via `_update_camera(delta)` a cada frame (ver seção Câmera)

### UIOverlay.gd — responsabilidades
- Desenhado via `_draw()` num `Control` dentro de `CanvasLayer` (sempre visível, process_mode=ALWAYS)
- Barra superior: fundo semi-transparente, 62px de altura
- Esquerda: ícones de vida (1 preenchido, 2 apenas contorno)
- Centro: 3 ícones de powerup (escudo, moeda, ímã) — visuais provisórios
- Direita: ícone de pause `||`; `PauseBtn` (Button flat invisível) captura o toque e chama `get_tree().paused`

---

## Visual e feedback

### Comunicação de estado

| Estado | Canal visual | Descrição |
|--------|-------------|-----------|
| Arco livre | Cor da borda | Verde vibrante |
| Arco bloqueado | Cor da borda | Cinza escuro |
| Círculo ativo | Opacidade | 100% |
| Círculo inativo | Opacidade | ~30% translúcido |
| Player morto | Cor da bola | Vermelho |

### Linhas de conexão
Linhas cinzas semi-transparentes conectam os círculos na ordem da sequência.
Desenhadas via `_draw()` no nó raiz do Game.

### Câmera

`Camera2D` é filho de `Game` (não do Player) e controlado inteiramente por `Game.gd`:

| Eixo | Lógica |
|------|--------|
| **Y** | `camera_y = player.y − viewport_h / (6 × zoom)` → player aparece no 1/3 inferior da tela |
| **X** | `(círculo_atual.x + próximo_círculo.x) / 2` → midpoint estável, não treme durante o tween |
| **Zoom** | `viewport_h × 5/12 ÷ distância_vertical`, clampado `[0.5, 1.4]` → zoom out quando círculos afastados, zoom in quando próximos |

Ambos Y e zoom são interpolados com `lerp` a cada frame (pos smooth=6.0, zoom smooth=3.5). Câmera inicializada sem lerp em `_ready()` para evitar salto de abertura.

Durante o movimento do player (`State.MOVING`), o "próximo círculo" para cálculo da câmera já é o `destination_circle`, antecipando a transição suavemente.

### Layout horizontal dos círculos

Com zoom adaptativo (zoom ≈ 0.78 a 450px de espaçamento), a largura visível é ~500px. Para que todos os centros fiquem sempre visíveis:

- **Range permitido de X: `[80, 310]`** — com o zoom adaptativo (zoom ≈ 0.78 a 450px de espaçamento), a largura visível é ~500px; spread máximo de ~220px entre dois círculos consecutivos deixa cada um a ~110px do midpoint, dentro da margem de 250px
- O midpoint horizontal da câmera é calculado automaticamente como `(círculo_atual.x + próximo_círculo.x) / 2`
- O padrão zig-zag (esquerda ↔ direita) deve respeitar esse range
- Nunca posicionar círculos fora desse range, mesmo em novos níveis ou geração procedural

### Indicador de pulso
Anel de progresso fino ao redor do círculo (estilo timer circular) — **pendente de implementação**.
Completará uma volta e mudará de cor quando o estado vai mudar.

### Morte
- Bola fica vermelha por 1s antes do respawn
- Feedback visual/sonoro diferenciado por tipo de morte — **pendente**

---

## Pontuação

- +1 ponto por pouso bem-sucedido
- Multiplicador de combo por pousos consecutivos
- Score exibido no topo durante o jogo
- High score salvo localmente (`FileAccess`)
- Sem vidas — cada erro reinicia o nível atual

---

## Demo — 5 níveis (implementado em Game.tscn)

21 círculos ao todo. Cada nível introduz exatamente um tipo de perigo novo. Os checkpoints (bg_number visível) são ponto de respawn e separação visual de fase.

Espaçamento vertical uniforme de **450px** entre todos os círculos. Com zoom ≈ 0.78 isso posiciona o próximo círculo em ~1/4 do topo da tela.

### Nível 1 — Arcos

| Círculo | Posição | Raio | Vel. (°/s) | Perigo |
|---------|---------|------|------------|--------|
| CircleStart | (195, 900) | 72 | 0 | Nenhum — partida (bg_number=1) |
| ArcA | (95, 450) | 50 | +72 | Arco bloqueado [25°, 155°] |
| ArcB | (295, 0) | 82 | −42 | 2 arcos: [10°,75°] e [195°,260°] |
| ArcC | (130, −450) | 58 | +96 | Arco bloqueado [15°, 195°] |
| CP1 | (255, −900) | 70 | 0 | Checkpoint (bg_number=2) |

### Nível 2 — Pulso

| Círculo | Posição | Raio | Vel. (°/s) | Ativo / Inativo |
|---------|---------|------|------------|-----------------|
| PulseA | (82, −1350) | 65 | −58 | 1.8s / 0.7s |
| PulseB | (290, −1800) | 52 | +78 | 0.6s / 1.4s |
| PulseC | (150, −2250) | 76 | −38 | 2.0s / 0.45s |
| CP2 | (225, −2700) | 70 | 0 | Checkpoint (bg_number=3) |

### Nível 3 — Orbiters

| Círculo | Posição | Raio | Vel. (°/s) | Orbiters |
|---------|---------|------|------------|----------|
| OrbA | (88, −3150) | 62 | +65 | 9, raio mult=1.55 |
| OrbB | (300, −3600) | 74 | −52 | 18, raio mult=1.85 |
| OrbC | (108, −4050) | 54 | +90 | 28, raio mult=2.1 |
| CircleEnd | (195, −4500) | 78 | 0 | Checkpoint (bg_number=4) |

### Nível 4 — Orbiters perseguidores

| Círculo | Posição | Raio | Vel. (°/s) | Chasers |
|---------|---------|------|------------|---------|
| ChaserA | (108, −4950) | 62 | +48 | 2 — introdução suave |
| ChaserB | (282, −5400) | 70 | −62 | 3 — pressão crescente |
| ChaserC | (115, −5850) | 58 | +78 | 4 — tensão máxima |
| CP4 | (195, −6300) | 72 | 0 | Final (bg_number=5) |

### Nível 5 — Espelho

| Círculo | Posição | Raio | Vel. (°/s) | Mirror |
|---------|---------|------|------------|--------|
| MirrorA | (105, −6750) | 60 | +55 | 1 arco: [40°, 160°] |
| MirrorB | (280, −7200) | 68 | −65 | 2 arcos: [20°,120°] e [220°,300°] |
| MirrorC | (112, −7650) | 62 | +80 | 1 arco: [25°, 185°] |
| CP5 | (195, −8100) | 72 | 0 | Checkpoint (bg_number=6) |

> A cada pouso num CircleMirror a rotação inverte e as cores trocam. Na primeira visita o timing é lido normalmente; na segunda tudo que era bloqueado agora é livre e vice-versa. MirrorB tem dois arcos bloqueados para criar uma janela tripla (duas verdes + uma cinza) que se torna uma janela dupla (dois cinzas + uma verde) após o flip.

> Os raios de órbita e velocidades dos orbiters são gerados proceduralmente em `_ready()` com `randf_range()`. O número exibido no centro dos checkpoints usa `ThemeDB.fallback_font` com `circle_radius * 1.15` como tamanho, opacidade 13%.

---

## Configurações técnicas Godot

- **Orientação:** Portrait (vertical), fixo
- **Resolução base:** 390×844 (iPhone 14 como referência)
- **Stretch mode:** `canvas_items` com aspect `expand`
- **Input:** `InputEventScreenTouch` (produção) + `InputEventMouseButton` (teste desktop)
- **Física:** sem `PhysicsServer` — todo movimento é matemático
- **Rendering:** mobile / gl_compatibility
- **Background:** `Color(0.07, 0.07, 0.11)` — azul escuro quase preto

---

## O que NÃO implementar ainda

- ❌ Temas visuais / skins
- ❌ Sistema de níveis infinitos gerados proceduralmente
- ❌ Multiplayer ou ranking online
- ❌ Monetização
- ❌ Efeitos de partícula elaborados

---

## Backlog de mecânicas — ideias para revisar

> Estas ideias ainda não foram implementadas. Revisar antes de escolher a próxima.

### Novos tipos de círculo

| Ideia | Descrição | Complexidade |
|-------|-----------|--------------|
| ~~**Círculo espelho**~~ | ✅ **Implementado** — ver Nível 5 e mecânica 5 neste doc. | — |
| **Círculo sequencial** | Vários arcos que se revelam um por vez em ciclo. Só um segmento fica verde por vez e muda a cada X segundos. Combina leitura de timing com antecipação. | Média |
| **Círculo fantasma** | Some e reaparece em ciclos — o círculo inteiro desaparece, inclusive a linha de conexão. O player decide se pula agora ou espera. | Baixa |
| **Círculo elástico** | Ao pousar, o próximo salto tem velocidade 2–3× maior. Muda completamente o timing do próximo círculo. | Baixa |
| **Círculo de ancoragem** | Player fica preso nele por 1–2s antes de poder pular. Gera tensão máxima quando combinado com orbiters ou chasers. | Baixa |

### Novos obstáculos

| Ideia | Descrição | Complexidade |
|-------|-----------|--------------|
| **Barreira linear** | Segmento de linha que corta o caminho entre dois círculos e se move lateralmente. Player espera a janela aberta. | Alta |
| **Campo de gravidade** | Zona ao redor de um círculo que curva levemente a trajetória durante o voo. Não mata, mas desloca o ângulo de chegada. | Alta |
| **Espinho retrátil** | Spikes que saem e entram na borda do círculo em ritmo, alternando com os arcos verdes. Janela verde pisca em vez de ser fixa. | Média |

### Estratégias de progressão

| Ideia | Descrição |
|-------|-----------|
| **Círculo bônus fora da rota** | Círculo opcional ao lado da sequência. Desviar pega moeda/powerup mas chega no próximo com ângulo mais difícil. |
| **Reversão** | Após o checkpoint, os círculos já visitados "acordam" novamente com perigos diferentes. Mesmo caminho, obstáculos novos. |
| **Dupla rota** | Dois caminhos possíveis convergem no mesmo checkpoint: um difícil com recompensa, um fácil sem. |
| **Velocidade crescente** | Após certo checkpoint, todos os círculos do nível aceleram gradualmente sem aviso. O timing que funcionava começa a falhar. |

### Meta-dinâmicas

| Ideia | Descrição |
|-------|-----------|
| **Combo visual** | Pousos consecutivos no centro do arco verde deixam player e linhas mais brilhantes. Só cosmético, mas dá satisfação e sinaliza domínio. |
| **Círculo âncora de dificuldade** | Ao ser alcançado, torna todos os círculos do nível ligeiramente mais rápidos permanentemente naquela run. |

---

## Próximos passos

1. ✅ `Circle.tscn` com rotação e arcos via `_draw()`
2. ✅ `is_landing_valid()` com detecção de ângulo
3. ✅ `Player.tscn` — movimento centro-a-centro estilo Orbia
4. ✅ `Game.tscn` — demo de 3 níveis (arcos → pulso → orbiters)
5. ✅ Pulso implementado em `Circle.gd`
6. ✅ `Orbiter.tscn` com fade ao pousar e morte por contato
7. ✅ Checkpoint visual com `bg_number` (1–4) desenhado no centro
8. ✅ Morte ao sair por arco bloqueado ou círculo inativo
9. ✅ Respawn no último checkpoint atingido
10. ✅ Cenas especializadas por tipo de círculo (`CircleArc`, `CirclePulse`, `CircleOrbiter`, `CircleCheckpoint`)
11. ✅ `UI.tscn` provisório (vidas, powerups, pause) via `CanvasLayer`
12. ✅ Câmera dinâmica — player no 1/3 inferior, zoom adaptativo, X centralizado entre círculos
13. ✅ Orbiter perseguidor (`CircleChaser.tscn`) — nível 4 implementado
14. ✅ Círculo espelho (`CircleMirror.tscn`) — nível 5 implementado
15. Indicador visual de progresso do pulso (anel de timer ao redor da borda)
16. Feedback visual/sonoro de morte diferenciado (blocked = vermelho seco, inactive = fade)
17. `PhaseConfig.gd` como `Resource` para configurar níveis via editor
18. HUD definitivo com score e combo (substituir UI provisória)
19. Testar em dispositivo real desde cedo
