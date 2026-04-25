import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../constants/app_constants.dart';

final dioProvider = Provider<Dio>((ref) {
  final dio = Dio(
    BaseOptions(
      baseUrl: baseApiUrl,
      connectTimeout: requestTimeout,
      receiveTimeout: requestTimeout,
      sendTimeout: requestTimeout,
      headers: const {
        'Accept': 'application/json',
        'User-Agent': 'HubCityTransit-Flutter/1.0',
      },
    ),
  );

  dio.interceptors.add(
    InterceptorsWrapper(
      onError: (error, handler) async {
        final shouldRetry =
            error.type == DioExceptionType.connectionTimeout ||
            error.type == DioExceptionType.sendTimeout ||
            error.type == DioExceptionType.receiveTimeout ||
            error.type == DioExceptionType.connectionError ||
            (error.response?.statusCode ?? 0) >= 500;

        final retried = error.requestOptions.extra['retried'] == true;
        if (shouldRetry && !retried) {
          error.requestOptions.extra['retried'] = true;
          try {
            final response = await dio.fetch(error.requestOptions);
            return handler.resolve(response);
          } on DioException catch (_) {
            // Fall through to original error.
          }
        }

        handler.next(error);
      },
    ),
  );

  return dio;
});
