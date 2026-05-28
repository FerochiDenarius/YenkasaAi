import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/operations_api_service.dart';
import '../models/operations_snapshot.dart';

final operationsDashboardProvider =
    FutureProvider.autoDispose<OperationsSnapshot>((ref) async {
      return ref.watch(operationsApiServiceProvider).fetchDashboard();
    });
