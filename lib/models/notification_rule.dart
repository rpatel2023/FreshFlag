class NotificationRule {
  const NotificationRule({
    required this.id,
    required this.daysBefore,
    required this.titleTemplate,
    required this.bodyTemplate,
    required this.sendTime,
    required this.enabled,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final int daysBefore;
  final String titleTemplate;
  final String bodyTemplate;

  /// Household-local wall-clock time in strict HH:mm form.
  final String sendTime;
  final bool enabled;
  final DateTime createdAt;
  final DateTime updatedAt;

  Map<String, dynamic> toMap() => {
        'daysBefore': daysBefore,
        'titleTemplate': titleTemplate,
        'bodyTemplate': bodyTemplate,
        'sendTime': sendTime,
        'enabled': enabled,
        'createdAt': createdAt.toUtc().toIso8601String(),
        'updatedAt': updatedAt.toUtc().toIso8601String(),
      };

  factory NotificationRule.fromMap(String id, Map<String, dynamic> map) {
    return NotificationRule(
      id: id,
      daysBefore: (map['daysBefore'] as num).toInt(),
      titleTemplate: map['titleTemplate'] as String,
      bodyTemplate: map['bodyTemplate'] as String,
      sendTime: normalizeSendTime(map['sendTime'] as String),
      enabled: map['enabled'] as bool? ?? true,
      createdAt: DateTime.parse(map['createdAt'] as String).toUtc(),
      updatedAt: DateTime.parse(map['updatedAt'] as String).toUtc(),
    );
  }

  NotificationRule copyWith({
    int? daysBefore,
    String? titleTemplate,
    String? bodyTemplate,
    String? sendTime,
    bool? enabled,
    DateTime? updatedAt,
  }) {
    return NotificationRule(
      id: id,
      daysBefore: daysBefore ?? this.daysBefore,
      titleTemplate: titleTemplate ?? this.titleTemplate,
      bodyTemplate: bodyTemplate ?? this.bodyTemplate,
      sendTime: normalizeSendTime(sendTime ?? this.sendTime),
      enabled: enabled ?? this.enabled,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  static String normalizeSendTime(String value) {
    final match = RegExp(r'^(\d{1,2}):(\d{2})$').firstMatch(value.trim());
    if (match == null) throw const FormatException('Send time must be HH:mm');
    final hour = int.parse(match.group(1)!);
    final minute = int.parse(match.group(2)!);
    if (hour > 23 || minute > 59) {
      throw const FormatException('Send time must be a valid 24-hour time');
    }
    return '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
  }

  static String renderTemplate(
    String template, {
    required String item,
    required int days,
    required String expiryDate,
    required int quantity,
    required String location,
  }) {
    final rendered = template
        .replaceAll('{item}', item)
        .replaceAll('{days}', days.toString())
        .replaceAll('{expiry_date}', expiryDate)
        .replaceAll('{quantity}', quantity.toString())
        .replaceAll('{location}', location);
    return days == 1 ? rendered.replaceAll(RegExp(r'\b1 days\b'), '1 day') : rendered;
  }
}
