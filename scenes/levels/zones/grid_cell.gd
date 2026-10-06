# Ce script s'attache à un StaticBody3D : un objet solide qui ne bouge pas.
# Ça permet au joueur de marcher dessus.
extends StaticBody3D

# @onready : ces variables sont remplies juste avant _ready(),
# quand tous les nœuds enfants existent.
# $MeshInstance3D veut dire « mon enfant qui s'appelle MeshInstance3D ».
# Le nom doit être EXACTEMENT celui de l'arbre de la scène.
@onready var mesh_instance_3d: MeshInstance3D = $MeshInstance3D
@onready var collision_shape_3d: CollisionShape3D = $CollisionShape3D

# @export : la variable apparaît dans l'Inspecteur, tu peux la changer
# sans toucher au code. Vector2(1, 1) = la case fait 1 m sur 1 m.
@export var cell_size: Vector2 = Vector2(25, 25)

# Une variable pour savoir si la case est occupée (par un perso, un objet…).
# false = vide au départ.
var full: bool = false


# _ready() est appelée UNE fois, quand la cellule apparaît dans le jeu.
func _ready() -> void:
	# Problème : toutes les cellules utilisent par défaut LE MÊME mesh
	# et LE MÊME matériau. Si on change la couleur d'une case, toutes changent.
	# duplicate() crée une copie rien qu'à cette cellule.
	mesh_instance_3d.mesh = mesh_instance_3d.mesh.duplicate()
	mesh_instance_3d.mesh.material = mesh_instance_3d.mesh.material.duplicate()

	# Pareil pour la forme de collision, sinon changer la taille d'une case
	# changerait la taille de toutes les autres.
	collision_shape_3d.shape = collision_shape_3d.shape.duplicate()

	# Le PlaneMesh est un plan plat : sa taille est un Vector2 (largeur, profondeur).
	mesh_instance_3d.mesh.size = cell_size

	# La collision est une boîte : sa taille est un Vector3 (largeur, hauteur, profondeur).
	# On lui donne la même largeur/profondeur que le plan, et 0.01 m de hauteur,
	# donc une boîte très fine, collée au plan.
	collision_shape_3d.shape.size = Vector3(cell_size.x, 0.01, cell_size.y)

	# On demande au parent sa couleur par défaut et on l'applique à la case.
	# get_parent() = le nœud juste au-dessus dans l'arbre.
	# Si le parent n'a pas de variable defaultColor, le jeu plante ici.
		# « in » vérifie si le parent possède bien une variable defaultColor.
	if "defaultColor" in get_parent():
		change_color(get_parent().defaultColor)
	else:
		# Sinon on utilise une couleur par défaut : un vert.
		change_color(Color(0.3, 0.7, 0.3))


# Change la couleur de la case.
# new_color: Color veut dire que la fonction attend une couleur.
func change_color(new_color: Color) -> void:
	# albedo_color = la couleur de base du matériau (voir « c'est quoi l'albedo »).
	mesh_instance_3d.mesh.material.albedo_color = new_color


# Renvoie le rectangle occupé par la case, vu du dessus.
# -> Rect2 veut dire que la fonction renvoie un rectangle 2D.
func get_rect() -> Rect2:
	# Vu du dessus, le sol c'est X et Z (Y c'est la hauteur, on l'ignore).
	# global_position = la position de la case dans le monde.
	# Rect2(coin, taille) : un rectangle qui part de ce coin, de la taille d'une case.
	return Rect2(Vector2(global_position.x, global_position.z), cell_size)
