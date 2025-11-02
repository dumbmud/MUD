class_name BodyNode
extends Resource
## BodyGraph node.

@export var id: StringName                         # unique within a graph

@export var tissue := {                            # HP buckets; not used this ticket
	"skin_hp": 100, "soft_hp": 100, "structure_hp": 100
}

@export var integument := {                        # minimal resist scaffold
	"cut": 1.0, "pierce": 1.0, "blunt": 1.0, "thermal": 1.0
}

@export var channels_present := {                  # which media traverse this node
	"signal": true, "fluid": true, "gas": true
}

@export var sockets: Array = []  #[BodySocket] = []        # logical organs/traits
@export var ports:   Array = []  #[BodyPort]   = []        # attachment points
@export var tags:    Array = []  #[StringName] = []        # optional author hints

@export var props: Dictionary = {} # arbitrary per-node properties; future-proof

@export var graft_clocks: Dictionary = {} # {attach_knit:0.0, neural_adapt:0.0} optional
