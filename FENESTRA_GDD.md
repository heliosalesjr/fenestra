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
│   │   └── Game.tscn                  # cena principal do demo
│   ├── circles/
│   │   ├── CircleBase.tscn            # template base (não usar diretamente em níveis)
│   │   ├── CircleCheckpoint.tscn      # sem perigo, bg_number, respawn
│   │   ├── CircleArc.tscn             # perigo: arcos bloqueados
│   │   ├── CirclePulse.tscn           # perigo: pulso ativo/inativo
│   │   └── CircleOrbiter.tscn         # perigo: esferas orbitantes
│   ├── entities/
│   │   ├── Player.tscn                # personagem/bolinha + Camera2D
│   │   └── Orbiter.tscn               # esfera orbitante
│   └── ui/                            # pendente
│       ├── UI.tscn                    # HUD — pendente
│       └── MainMenu.tscn              # pendente
├── scripts/
│   ├── game/
│   │   └── Game.gd                    # lógica principal, input, checkpoint
│   ├── circles/
│   │   ├── Circle.gd                  # rotação, arcos, pulso, orbiters
│   │   └── ArcVisual.gd               # desenho de arcos via _draw()
│   ├── entities/
│   │   ├── Player.gd                  # movimento, colisão, morte
│   │   └── Orbiter.gd                 # órbita, fade_and_free
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
```

**Circle.gd — API pública:**
- `is_landing_valid(world_angle_deg: float) -> bool` — verifica arcos e pulso, emite `landing_failed`
- `clear_orbiters()` — chama `fade_and_free()` em todos os filhos orbiters
- `last_fail_reason: String` — `"blocked"` ou `"inactive"`, lido pelo Player após retorno false

### Player.gd — responsabilidades
- Ao iniciar: posiciona-se no centro do círculo de partida
- Ao toque: move-se para o centro do próximo círculo via tween (0.14s, ease in-out quad)
- Ao chegar: calcula o ângulo de aproximação e chama `circle.is_landing_valid()`
- Em caso de morte: fica vermelho, emite `player_died(reason)`
- Estados: `ON_CIRCLE` | `MOVING` | `DEAD`
- Sinais: `landed_on(circle)`, `player_died(reason)`

### Orbiter.gd — responsabilidades
- Orbita ao redor do centro do nó pai (que é um Circle)
- `_process`: atualiza `position = Vector2.RIGHT.rotated(angle) * orbit_radius`
- `_draw`: desenha a esfera
- `fade_and_free()`: tween de opacidade 1→0 e depois `queue_free()`

**Orbiter.gd — exports:**
```gdscript
@export var orbit_radius: float
@export var orbit_speed: float   # graus/s, positivo = horário
@export var sphere_radius: float
@export var sphere_color: Color
@export var start_angle: float   # graus
```

### Game.gd — responsabilidades
- Mantém `circle_sequence: Array[NodePath]` (configurado no editor)
- `_draw()`: desenha linhas de conexão entre círculos consecutivos
- Input: toque/clique → `player.move_to(next_circle)`
- `_on_player_landed`: atualiza índice, chama `circle.clear_orbiters()`
- `_on_player_died`: aguarda 1s e chama `player.respawn(circles[0])`

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

### Layout horizontal dos círculos

A câmera segue o player em X e Y com position smoothing. Para que todos os centros dos círculos estejam sempre visíveis:

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

## Demo — 3 níveis (implementado em Game.tscn)

13 círculos ao todo. Cada nível introduz exatamente um tipo de perigo novo. Os checkpoints (bg_number visível) são ponto de respawn e separação visual de fase.

### Nível 1 — Arcos

| Círculo | Posição | Raio | Vel. (°/s) | Perigo |
|---------|---------|------|------------|--------|
| CircleStart | (195, 900) | 72 | 0 | Nenhum — partida (bg_number=1) |
| ArcA | (70, 600) | 50 | +72 | Arco bloqueado [25°, 155°] |
| ArcB | (320, 290) | 82 | −42 | 2 arcos: [10°,75°] e [195°,260°] |
| ArcC | (95, −20) | 58 | +96 | Arco bloqueado [15°, 195°] |
| CP1 | (240, −310) | 70 | 0 | Checkpoint (bg_number=2) |

### Nível 2 — Pulso

| Círculo | Posição | Raio | Vel. (°/s) | Ativo / Inativo |
|---------|---------|------|------------|-----------------|
| PulseA | (70, −610) | 65 | −58 | 1.8s / 0.7s |
| PulseB | (315, −920) | 52 | +78 | 0.6s / 1.4s |
| PulseC | (85, −1220) | 76 | −38 | 2.0s / 0.45s |
| CP2 | (250, −1510) | 70 | 0 | Checkpoint (bg_number=3) |

### Nível 3 — Orbiters

| Círculo | Posição | Raio | Vel. (°/s) | Orbiters |
|---------|---------|------|------------|----------|
| OrbA | (70, −1810) | 62 | +65 | 9, raio mult=1.55 |
| OrbB | (318, −2120) | 74 | −52 | 18, raio mult=1.85 |
| OrbC | (88, −2420) | 54 | +90 | 28, raio mult=2.1 |
| CircleEnd | (205, −2710) | 78 | 0 | Final (bg_number=4) |

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

## Próximos passos

1. ✅ `Circle.tscn` com rotação e arcos via `_draw()`
2. ✅ `is_landing_valid()` com detecção de ângulo
3. ✅ `Player.tscn` — movimento centro-a-centro estilo Orbia
4. ✅ `Game.tscn` — nível 1 com as três mecânicas
5. ✅ Pulso implementado em `Circle.gd`
6. ✅ `Orbiter.tscn` com fade ao pousar e morte por contato
7. ✅ Demo de 3 níveis (arcos → pulso → orbiters) em `Game.tscn`
8. ✅ Checkpoint visual com `bg_number` (1–4) desenhado no centro
9. ✅ Morte ao sair por arco bloqueado ou círculo inativo
10. Indicador visual de progresso do pulso (anel de timer ao redor da borda)
11. Feedback visual/sonoro de morte diferenciado (blocked = vermelho seco, inactive = fade)
12. Respawn no checkpoint mais recente (atualmente sempre reinicia do círculo 0)
13. `PhaseConfig.gd` como `Resource` para configurar níveis via editor
14. HUD com score e combo
15. Testar em dispositivo real desde cedo
