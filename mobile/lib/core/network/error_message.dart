import 'package:dio/dio.dart';

/// Maps an exception (usually a [DioException]) to a short, user-facing message.
String friendlyError(Object error) {
  if (error is DioException) {
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return 'The server took too long to respond.';
      case DioExceptionType.connectionError:
        return "Can't reach the server. Is the backend running?";
      case DioExceptionType.badResponse:
        final code = error.response?.statusCode;
        switch (code) {
          case 400:
            return 'Some of the details were invalid.';
          case 404:
            return 'That item no longer exists.';
          case 409:
            return 'That item is still in use elsewhere.';
          case 500:
            return 'The server hit an error. Please try again.';
          default:
            return code != null ? 'Request failed ($code).' : 'Request failed.';
        }
      case DioExceptionType.cancel:
        return 'The request was cancelled.';
      case DioExceptionType.badCertificate:
      case DioExceptionType.unknown:
        return "Can't reach the server. Is the backend running?";
    }
  }
  return 'Something went wrong.';
}
