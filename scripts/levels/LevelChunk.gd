class_name LevelChunk
extends Node2D

## Bloco relocável de um nível: 3 círculos de perigo + 1 checkpoint (+ barreiras
## opcionais), todos em coordenadas LOCAIS relativas à origem do chunk (0,0 =
## ponto de entrada, onde o checkpoint do nível anterior termina).
## RunBuilder (em Game.gd) posiciona o chunk inteiro via `position.y` e encadeia
## o próximo logo acima, usando `height` — não precisa saber nada sobre o
## conteúdo interno do nível pra isso.

## Altura vertical (positiva) que este nível ocupa, do ponto de entrada até o
## seu próprio checkpoint. Todos os níveis atuais usam o espaçamento padrão de
## 450px × 4 (3 perigos + checkpoint) = 1800.
@export var height: float = 1800.0

## Os 3 círculos de perigo do nível, na ordem em que devem ser jogados.
@export var trick_circles: Array[NodePath] = []
## O círculo de checkpoint que fecha o nível. Recebe bg_number em runtime
## (RunBuilder atribui conforme a posição do chunk na run montada).
@export var checkpoint_path: NodePath
## Barreiras (Barrier.tscn) deste nível, se houver.
@export var barrier_paths: Array[NodePath] = []


## Retorna os círculos do nível na ordem de jogo: perigos + checkpoint por último.
func get_level_circles() -> Array[Circle]:
	var out: Array[Circle] = []
	for p in trick_circles:
		out.append(get_node(p) as Circle)
	out.append(get_node(checkpoint_path) as Circle)
	return out


func get_barriers() -> Array[Barrier]:
	var out: Array[Barrier] = []
	for p in barrier_paths:
		out.append(get_node(p) as Barrier)
	return out
