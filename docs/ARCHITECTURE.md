# Architecture de Fram'Bush Quest

Action-RPG 2D pixel art avec une ambiance MMO (hub, quêtes, loot, classes), en solo d'abord, coop possible plus tard.
Moteur : **Godot 4** (2D), langage **GDScript**.

Ce document décrit *où* va chaque chose et *comment* les morceaux se parlent. Le code est à écrire.

---

## 1. Réglages du projet à faire dès le début

Dans `Project > Project Settings` :

- **Rendering > Textures > Default Texture Filter** : `Nearest` (sinon le pixel art est flou).
- **Display > Window** : une petite résolution de base (ex. 320×180 ou 480×270), `Stretch Mode = viewport`, `Aspect = keep`. Le jeu est rendu en petit puis agrandi proprement.
- **Rendering > 2D > Snap 2D Transforms to Pixel** : activé, pour éviter les tremblements de sprites.
- **Input Map** : déclarer les actions (`move_left`, `move_right`, `move_up`, `move_down`, `attack`, `dash`, `skill_1`, `skill_2`, `interact`, `pause`). Ne jamais tester une touche directement dans le code, toujours une action.
- **Physics > Layers 2D** : nommer les couches de collision (voir section 5).

---

## 2. Arborescence

```
assets/            Fichiers bruts que tu crées (aucun script ici)
  sprites/         player, enemies, bosses, npcs
  tilesets/        tuiles pour les maps
  ui/  fonts/  vfx/
  audio/music  audio/sfx

scenes/            Scènes Godot (.tscn), une scène = un objet réutilisable
  main/            Scène de démarrage, écran titre
  player/          Player.tscn
  enemies/         Un .tscn par ennemi (hérite d'une scène Enemy de base)
  bosses/          Un .tscn par boss
  npcs/            PNJ, marchands, donneurs de quêtes
  levels/hub/      La ville centrale
  levels/zones/    Les zones de jeu (forêt, donjon...)
  ui/              HUD, inventaire, menus, boîtes de dialogue
  vfx/             Effets (impact, slash, particules)

scripts/           Scripts .gd rangés par rôle
  autoload/        Singletons globaux (section 3)
  components/      Petits blocs réutilisables (section 4)
  state_machine/   Machine à états générique (section 6)
  player/states/   États du joueur
  enemies/states/  États des ennemis
  bosses/          Logique des boss et de leurs phases
  combat/          Hitbox, hurtbox, calcul des dégâts
  inventory/       Objets, équipement
  quests/          Suivi des quêtes
  ui/              Scripts des écrans

data/              Données de jeu en Resources (.tres), pas en dur dans le code
  items/  enemies/  bosses/  quests/  dialogues/

docs/              Ce document, ton game design, tes notes
```

Règle simple : **une scène et son script portent le même nom** (`Player.tscn` / `player.gd`), et un script ne connaît que ses enfants, jamais ses parents ni ses voisins.

---

## 3. Autoloads (singletons)

À déclarer dans `Project Settings > Autoload`. Garde-les peu nombreux :

| Nom | Rôle |
|---|---|
| `Events` | Bus de signaux global (`player_died`, `boss_defeated`, `item_picked`, `quest_updated`...). Les systèmes s'écoutent sans se connaître. |
| `GameState` | Données de la partie en cours : niveau, stats, inventaire, quêtes, flags d'histoire. |
| `SaveManager` | Lit et écrit `GameState` sur disque (`user://save.json` ou une Resource). |
| `SceneLoader` | Change de zone avec un fondu, place le joueur au bon point d'entrée. |
| `AudioManager` | Musique (avec fondu entre zones) et sons. |

---

## 4. Composants réutilisables

Plutôt qu'un énorme script par personnage, découpe en nœuds enfants. Le joueur, les ennemis et les boss utilisent les mêmes :

- **HealthComponent** : PV, PV max, signaux `damaged`, `died`.
- **Hitbox** (Area2D) : la zone qui *fait* mal. Porte les dégâts, le knockback et l'équipe.
- **Hurtbox** (Area2D) : la zone qui *reçoit*. Quand une Hitbox la touche, elle prévient le HealthComponent. Gère les frames d'invincibilité.
- **VelocityComponent** : vitesse, accélération, friction, knockback.
- **StatsComponent** : attaque, défense, vitesse, reliée aux Resources de `data/`.

Exemple de scène joueur :

```
Player (CharacterBody2D)
├── AnimatedSprite2D / Sprite2D
├── AnimationPlayer        ← anime le sprite ET active les hitbox
├── CollisionShape2D
├── HealthComponent
├── VelocityComponent
├── Hurtbox
├── AttackPivot (Node2D)   ← tourne vers la direction visée
│   └── Hitbox
├── StateMachine
│   ├── Idle  ├── Run  ├── Dash  ├── Attack1  ├── Attack2  ├── Attack3  ├── Hurt  └── Dead
└── Camera2D
```

---

## 5. Combat façon Eliott

Ce qui rend les attaques agréables, c'est le *timing* et le *ressenti*. Les briques :

- **Frames d'attaque précises** : dans l'`AnimationPlayer`, une piste qui active la Hitbox seulement sur les frames actives (anticipation → actif → récupération). Ne jamais activer la hitbox par timer dans le code.
- **Combo** : chaque état d'attaque a une petite fenêtre où un nouvel appui sur `attack` enchaîne sur l'attaque suivante. Hors fenêtre, retour à Idle.
- **Input buffer** : mémoriser un appui pendant ~0,1 à 0,15 s pour qu'une attaque ou un dash pressé un poil trop tôt soit pris en compte.
- **Dash avec i-frames** : la Hurtbox est désactivée pendant une partie du dash. Essentiel pour des boss durs mais justes.
- **Game feel** : hit-stop (le jeu se fige 2 à 4 frames à l'impact), screen shake léger, flash blanc sur l'ennemi touché, knockback, particules.
- **Couches de collision** (exemple) : 1 monde, 2 joueur, 3 ennemis, 4 hitbox joueur, 5 hitbox ennemis, 6 hurtbox joueur, 7 hurtbox ennemis, 8 interactions. Les hitbox joueur ne regardent que les hurtbox ennemis, et inversement.

---

## 6. Machine à états

Un nœud `StateMachine` avec un enfant par état. Chaque état a les mêmes fonctions : `enter()`, `exit()`, `handle_input(event)`, `update(delta)`, `physics_update(delta)`, et demande un changement d'état par un signal ou une méthode de la machine.

Avantages : chaque mouvement est isolé dans son fichier, facile à régler, et les ennemis utilisent la même machine que le joueur.

---

## 7. Boss

Chaque boss = machine à états + **phases**.

- Un `BossPhase` par seuil de PV (ex. 100-60 %, 60-25 %, 25-0 %). Chaque phase liste les attaques disponibles, leur poids et la vitesse.
- Chaque attaque de boss est un état : **télégraphe** (animation ou zone au sol visible) → **actif** → **récupération** (la fenêtre où le joueur punit).
- Changement de phase = petite animation, invincibilité courte, nouveaux patterns.
- La difficulté vient de la lisibilité : un boss dur mais toujours télégraphié est frustrant dans le bon sens.
- Stats et paramètres des boss dans `data/bosses/` pour équilibrer sans toucher au code.

---

## 8. Données (Resources)

Crée des scripts `class_name` qui héritent de `Resource`, puis des fichiers `.tres` dans `data/` :

- `ItemData` : nom, icône, type, stats, prix.
- `EnemyData` : PV, dégâts, vitesse, XP, table de loot.
- `QuestData` : titre, description, objectifs, récompenses.
- `DialogueData` : lignes, personnage, choix.

Tu ajoutes un objet ou une quête en créant un fichier dans l'éditeur, sans écrire de code.

---

## 9. Monde et durée de jeu (objectif 2 h+)

Ordre de grandeur pour viser 2 à 3 h :

- 1 hub (ville, marchand, forgeron, tableau de quêtes).
- 4 à 5 zones, chacune avec ses ennemis, une mini-quête et un boss en fin de zone.
- 1 boss final en plusieurs phases.
- Progression : XP et niveaux, équipement, 2 à 4 compétences débloquées au fil des boss.

Chaque zone = une scène dans `scenes/levels/zones/` avec des `Marker2D` pour les points d'entrée et des `Area2D` de sortie qui appellent `SceneLoader`.

---

## 10. Penser au multijoueur plus tard

Même en solo, ces habitudes rendent une coop possible ensuite :

- Séparer **l'input** (qui lit le clavier/manette) de **la logique du personnage** (qui reçoit des intentions : bouger, attaquer). Un joueur distant n'est alors qu'une autre source d'intentions.
- Faire passer les dégâts et la mort par `HealthComponent` et des signaux, jamais en modifiant les PV directement depuis l'extérieur.
- Ne pas mettre d'état de partie dans les scènes visuelles : il vit dans `GameState`.

Godot fournit `MultiplayerSpawner` et `MultiplayerSynchronizer` pour une coop à 2-4 joueurs. Un vrai MMO (serveur dédié, beaucoup de joueurs) est un projet à part entière, à garder pour plus tard.

---

## 11. Ordre de construction conseillé

1. Joueur qui bouge, dash, et une attaque, dans une salle de test vide.
2. Combo 3 coups + game feel (hit-stop, shake, flash).
3. Un ennemi de base avec composants partagés.
4. Un premier boss simple à 2 phases. Si ce combat est fun, le reste suivra.
5. HUD (PV, XP), mort et respawn.
6. Changement de zone, hub, sauvegarde.
7. Inventaire, équipement, quêtes, dialogues.
8. Contenu : zones, ennemis, boss, équilibrage.
