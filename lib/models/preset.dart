class Preset {
  final int? id;
  final String name;
  final String actionsJson; // JSON string to store what this preset does

  Preset({
    this.id,
    required this.name,
    required this.actionsJson,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'actions_json': actionsJson,
    };
  }

  factory Preset.fromMap(Map<String, dynamic> map) {
    return Preset(
      id: map['id'],
      name: map['name'],
      actionsJson: map['actions_json'],
    );
  }
}
