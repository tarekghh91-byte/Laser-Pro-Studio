import 'package:supabase_flutter/supabase_flutter.dart';

class CloudRecord {
  const CloudRecord({required this.id, required this.payload, required this.version});
  final String id;
  final Map<String, dynamic> payload;
  final int version;
}

/// Per-user documents with optimistic concurrency (no silent last-write-wins).
/// This is phase-one sync for orders and materials, not the final accounting model.
class CloudSync {
  CloudSync(this.ownerId);
  final String ownerId;
  SupabaseClient get _db => Supabase.instance.client;

  Future<List<CloudRecord>> list(String collection) async {
    final data = await _db
      .from('lp_sync_records')
      .select('record_id,payload,version')
      .eq('owner_id', ownerId)
      .eq('collection', collection);
    return (data as List).map((raw) {
      final item = Map<String, dynamic>.from(raw as Map);
      return CloudRecord(
        id: item['record_id'] as String,
        payload: Map<String, dynamic>.from(item['payload'] as Map),
        version: (item['version'] as num).toInt(),
      );
    }).toList();
  }

  /// Atomically reserves a globally unique LP serial from PostgreSQL.
  /// The database sequence is shared by every signed-in device.
  Future<String> nextOrderNumber() async {
    final result = await _db.rpc('lp_next_order_number');
    if (result is! String || !RegExp(r'^LP[0-9]{4,}
      'p_collection': collection,
      'p_record_id': id,
      'p_payload': payload,
      'p_expected_version': expectedVersion,
    });
    return (result as num).toInt();
  }
}
).hasMatch(result)) {
      throw StateError('تعذّر الحصول على رقم طلب تسلسلي صالح');
    }
    return result;
  }

  Future<int> put(String collection, String id, Map<String, dynamic> payload, int expectedVersion) async {
    final result = await _db.rpc('lp_put_sync_record', params: {
      'p_collection': collection,
      'p_record_id': id,
      'p_payload': payload,
      'p_expected_version': expectedVersion,
    });
    return (result as num).toInt();
  }
}
