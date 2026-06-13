class WebhookEvent {
  final String id;
  final String eventType;
  final String sourceTable;
  final String? recordId;
  final Map<String, dynamic> payload;
  final String status;
  final String? destinationUrl;
  final int retryCount;
  final int maxRetries;
  final String? lastError;
  final DateTime? nextRetryAt;
  final DateTime createdAt;
  final DateTime? deliveredAt;

  const WebhookEvent({
    required this.id,
    required this.eventType,
    required this.sourceTable,
    this.recordId,
    required this.payload,
    required this.status,
    this.destinationUrl,
    this.retryCount = 0,
    this.maxRetries = 3,
    this.lastError,
    this.nextRetryAt,
    required this.createdAt,
    this.deliveredAt,
  });

  factory WebhookEvent.fromJson(Map<String, dynamic> json) {
    return WebhookEvent(
      id: json['id'] as String,
      eventType: json['event_type'] as String,
      sourceTable: json['source_table'] as String,
      recordId: json['record_id'] as String?,
      payload: (json['payload'] as Map<String, dynamic>?) ?? {},
      status: json['status'] as String? ?? 'pending',
      destinationUrl: json['destination_url'] as String?,
      retryCount: (json['retry_count'] as num?)?.toInt() ?? 0,
      maxRetries: (json['max_retries'] as num?)?.toInt() ?? 3,
      lastError: json['last_error'] as String?,
      nextRetryAt: json['next_retry_at'] != null
          ? DateTime.parse(json['next_retry_at'] as String)
          : null,
      createdAt: DateTime.parse(json['created_at'] as String),
      deliveredAt: json['delivered_at'] != null
          ? DateTime.parse(json['delivered_at'] as String)
          : null,
    );
  }
}

class WebhookConfig {
  final String id;
  final String eventType;
  final String destinationUrl;
  final bool isActive;
  final String? secretKey;

  const WebhookConfig({
    required this.id,
    required this.eventType,
    required this.destinationUrl,
    this.isActive = true,
    this.secretKey,
  });

  factory WebhookConfig.fromJson(Map<String, dynamic> json) {
    return WebhookConfig(
      id: json['id'] as String,
      eventType: json['event_type'] as String,
      destinationUrl: json['destination_url'] as String,
      isActive: json['is_active'] as bool? ?? true,
      secretKey: json['secret_key'] as String?,
    );
  }
}
