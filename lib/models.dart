import 'dart:convert';

class Medication {
  final String id;
  final String name;
  final String dose;
  final TimeOfDaySerializable time; // HH:mm
  final String? imagePath; // Chemin de l'image

  Medication({
    required this.id,
    required this.name,
    required this.dose,
    required this.time,
    this.imagePath,
  });

  Medication copyWith({
    String? id,
    String? name,
    String? dose,
    TimeOfDaySerializable? time,
    String? imagePath,
  }) {
    return Medication(
      id: id ?? this.id,
      name: name ?? this.name,
      dose: dose ?? this.dose,
      time: time ?? this.time,
      imagePath: imagePath ?? this.imagePath,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'dose': dose,
        'time': time.toJson(),
        'imagePath': imagePath,
      };

  static Medication fromJson(Map<String, dynamic> json) => Medication(
        id: json['id'] as String,
        name: json['name'] as String,
        dose: json['dose'] as String,
        time: TimeOfDaySerializable.fromJson(json['time'] as Map<String, dynamic>),
        imagePath: json['imagePath'] as String?,
      );

  @override
  String toString() => jsonEncode(toJson());
}

class ReminderLogEntry {
  final String id;
  final String medicationId;
  final DateTime scheduledAt;
  final DateTime firedAt;
  final bool acknowledged;

  ReminderLogEntry({
    required this.id,
    required this.medicationId,
    required this.scheduledAt,
    required this.firedAt,
    required this.acknowledged,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'medicationId': medicationId,
        'scheduledAt': scheduledAt.toIso8601String(),
        'firedAt': firedAt.toIso8601String(),
        'acknowledged': acknowledged,
      };

  static ReminderLogEntry fromJson(Map<String, dynamic> json) => ReminderLogEntry(
        id: json['id'] as String,
        medicationId: json['medicationId'] as String,
        scheduledAt: DateTime.parse(json['scheduledAt'] as String),
        firedAt: DateTime.parse(json['firedAt'] as String),
        acknowledged: json['acknowledged'] as bool,
      );
}

class TimeOfDaySerializable {
  final int hour;
  final int minute;
  const TimeOfDaySerializable({required this.hour, required this.minute});

  Map<String, dynamic> toJson() => {'hour': hour, 'minute': minute};
  static TimeOfDaySerializable fromJson(Map<String, dynamic> json) =>
      TimeOfDaySerializable(hour: json['hour'] as int, minute: json['minute'] as int);

  @override
  String toString() => '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
}



