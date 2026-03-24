class Modifier {
  final int? id;
  final String name;
  final String? colorHex; // Optional accent color for this modifier

  const Modifier({this.id, required this.name, this.colorHex});

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'color_hex': colorHex,
      };

  factory Modifier.fromMap(Map<String, dynamic> map) => Modifier(
        id: map['id'] as int?,
        name: map['name'] as String,
        colorHex: map['color_hex'] as String?,
      );

  Modifier copyWith({int? id, String? name, String? colorHex}) => Modifier(
        id: id ?? this.id,
        name: name ?? this.name,
        colorHex: colorHex ?? this.colorHex,
      );
}
