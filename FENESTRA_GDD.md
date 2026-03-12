# Fenestra — Game Design Document
> Referência de desenvolvimento para uso com Claude Code

---

## Visão geral

**Nome:** Fenestra  
**Engine:** Godot 4.5+  
**Plataforma:** Mobile (Android e iOS)  
**Gênero:** Arcade / Precision timing  
**Inspiração:** Dizzypad (iPad)  
**Conceito em uma frase:** Pule entre círculos giratórios acertando o momento e o ponto de entrada certos ao mesmo tempo.

---

## Mecânica central

O jogo é baseado em Dizzypad: o jogador salta de círculo em círculo. Os círculos giram continuamente. A diferença são duas camadas adicionais de desafio:

### 1. Arcos bloqueados
A borda de cada círculo tem segmentos **livres** e segmentos **bloqueados**.  
- O jogador só pode pousar num segmento **livre**.  
- Pousar num segmento bloqueado = morte.  
- Os segmentos são visualmente distintos (cor da borda: verde = livre, cinza escuro = bloqueado).  
- Em fases avançadas, os arcos se reposicionam a cada volta completa do círculo.

### 2. Ativação pulsante
Cada círculo alterna entre estado **ativo** e **inativo** em ciclos.  
- O jogador só pode pousar num círculo **ativo**.  
- Pousar num círculo inativo = morte.  
- O estado é comunicado pela opacidade/brilho do círculo inteiro (cheio = ativo, translúcido = inativo).  
- Um indicador de progresso ao redor da borda mostra quanto tempo falta para o próximo estado mudar.

### Combinação
Nas fases avançadas, as duas condições se aplicam simultaneamente:  
o jogador precisa encontrar o momento em que o arco certo está alinhado **e** o círculo está ativo.  
A janela combinada nunca deve ser menor que ~400ms (regra de design inegociável).

### Feedback de morte diferenciado
- Morrer em arco bloqueado → efeito visual/sonoro A (impacto na borda, cor vermelha)  
- Morrer em círculo inativo → efeito visual/sonoro B (círculo some, fade rápido)  
O jogador precisa entender instantaneamente qual condição falhou.

---

## Controles

- **Toque simples** → salta do círculo atual para o próximo  
- O salto é sempre em direção ao próximo círculo da sequência (sem controle direcional livre)  
- O timing e o ponto de entrada dependem de quando o jogador toca  
- Sem botões, sem joystick — toque único é toda a interface durante o jogo

---

## Estrutura de progressão de fases

Cada fase introduz **exatamente uma variável nova**. Nunca subir dois eixos de dificuldade ao mesmo tempo.

| Fase | Arcos bloqueados | Pulso | Velocidade | Novidade |
|------|-----------------|-------|------------|----------|
| 1 | Nenhum | Sem pulso | Baixa | Tutorial: só timing de salto |
| 2 | Pequeno (≈60° bloqueado) | Sem pulso | Baixa | Introduz leitura espacial |
| 3 | Crescente (60°→120°→180°) | Sem pulso | Média | Janela livre vai reduzindo |
| 4 | Nenhum | Pulso regular lento | Baixa | Introduz timing duplo isolado |
| 5 | Pequeno (≈60°) | Pulso regular lento | Média | Primeira combinação, generosa |
| 6 | Dois arcos não-contíguos | Pulso médio | Média | Escolha de qual janela esperar |
| 7 | Arcos dinâmicos | Pulso irregular | Alta | Leitura em tempo real, sem memorização |

### Regras de balanceamento
- Quando o arco livre é pequeno → o pulso deve ter janela longa  
- Quando o pulso é rápido → o arco deve ser grande (janela espacial confortável)  
- Os dois nunca apertam juntos antes da fase 6+  
- Velocidade de rotação: eixo separado, sobe devagar e independentemente

---

## Estrutura do projeto Godot

```
fenestra/
├── project.godot
├── scenes/
│   ├── Game.tscn              # cena principal
│   ├── Circle.tscn            # círculo giratório (cena reutilizável)
│   ├── Player.tscn            # personagem/bolinha
│   ├── UI.tscn                # HUD (score, indicador de pulso)
│   └── MainMenu.tscn
├── scripts/
│   ├── Game.gd                # lógica principal, geração de fases
│   ├── Circle.gd              # rotação, arcos, pulso, colisão de borda
│   ├── Player.gd              # salto, detecção de pouso, morte
│   └── PhaseConfig.gd         # dados de configuração por fase
├── assets/
│   ├── audio/
│   └── sprites/
└── FENESTRA_GDD.md            # este arquivo
```

---

## Nós e cenas principais

### Circle.tscn
- **Node2D** (raiz)
  - **Node2D** `RotationRoot` — filho que gira continuamente
    - **Arc visual** — desenhado via `_draw()` ou shader
  - **AnimationPlayer** — controla o pulso (ativo/inativo)
  - **Area2D** + **CollisionShape2D** — detecção de pouso

**Circle.gd — responsabilidades:**
- Girar `RotationRoot` a cada frame (`rotation_degrees += speed * delta`)
- Definir quais segmentos são livres/bloqueados (array de ângulos)
- Alternar estado ativo/inativo conforme config da fase
- Expor método `is_landing_valid(angle: float) -> bool`
- Emitir sinal `landing_failed(reason: String)` com `"blocked"` ou `"inactive"`

### Player.gd — responsabilidades:
- Ficar "preso" ao círculo atual, rotacionando junto
- Ao toque: calcular ângulo atual no círculo de destino e saltar
- Ao pousar: chamar `circle.is_landing_valid(angle)` e reagir
- Emitir sinal `player_died(reason: String)`

### PhaseConfig.gd
Recurso (`Resource`) com os parâmetros de cada fase:
```gdscript
@export var rotation_speed: float        # graus por segundo
@export var blocked_arcs: Array[Vector2] # pares [inicio_grau, fim_grau]
@export var pulse_enabled: bool
@export var pulse_active_duration: float # segundos ativo
@export var pulse_inactive_duration: float
@export var pulse_irregular: bool        # se true, duração varia aleatoriamente dentro de um range
```

---

## Visual e feedback

### Comunicação de estado (dois canais visuais separados)
| Estado | Canal visual | Descrição |
|--------|-------------|-----------|
| Arco livre | Cor da borda | Verde vibrante |
| Arco bloqueado | Cor da borda | Cinza escuro / quase invisível |
| Círculo ativo | Opacidade do círculo | 100% opaco |
| Círculo inativo | Opacidade do círculo | ~30% translúcido |

### Indicador de pulso
Anel de progresso fino ao redor do círculo (estilo timer circular).  
Completa uma volta e muda de cor quando o estado vai mudar.  
Jogador pode prever o próximo estado sem depender de memorização.

### Morte
- Arco bloqueado: flash vermelho na borda, partículas saindo do ponto de impacto, som de impacto seco
- Círculo inativo: círculo desaparece brevemente, jogador cai, som de "vácuo" ou fade

---

## Pontuação

- +1 ponto por pouso bem-sucedido  
- Multiplicador de combo por pousos consecutivos sem errar  
- Score exibido no topo durante o jogo  
- High score salvo localmente (`FileAccess` do Godot)  
- Sem vidas — cada erro reinicia a fase (estilo arcade)

---

## Configurações técnicas Godot

- **Orientação:** Portrait (vertical), fixo
- **Resolução base:** 390×844 (iPhone 14 como referência)
- **Stretch mode:** `canvas_items` com aspect `expand`
- **Input:** apenas `InputEventScreenTouch` (ignorar mouse em produção)
- **Física:** não usar `PhysicsServer` — movimento é matemático/manual para precisão
- **Rendering:** compatível com GLES3 (Godot 4 mobile default)

---

## O que NÃO implementar ainda

Para manter o escopo controlado na primeira versão:
- ❌ Temas visuais / skins
- ❌ Sistema de fases infinitas geradas proceduralmente
- ❌ Multiplayer ou ranking online
- ❌ Monetização
- ❌ Efeitos de partícula elaborados

Foco total em: mecânica funcionando, progressão das 7 fases, feedback claro, sensação de jogo justa.

---

## Próximos passos sugeridos

1. Criar `Circle.tscn` com rotação básica e desenho de arcos via `_draw()`
2. Implementar `is_landing_valid()` com detecção de ângulo
3. Criar `Player.tscn` com lógica de salto e pouso
4. Ligar os dois com a cena `Game.tscn`
5. Adicionar pulso via `AnimationPlayer` no `Circle`
6. Implementar `PhaseConfig` como `Resource` e carregar fases em sequência
7. Adicionar feedback visual e sonoro de morte
8. Testar em dispositivo real (não só no emulador) desde cedo
