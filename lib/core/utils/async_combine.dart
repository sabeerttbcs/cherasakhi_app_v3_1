import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Merges several AsyncValues: first error wins, loading until all have data.
AsyncValue<R> combineAsync<R>(List<AsyncValue<Object?>> values, R Function() build) {
  for (final v in values) {
    if (v.hasError) {
      return AsyncError<R>(v.error!, v.stackTrace ?? StackTrace.current);
    }
  }
  if (values.every((v) => v.hasValue)) return AsyncData<R>(build());
  return AsyncLoading<R>();
}
