abstract class Failure {
  final String message;
  final Object? originalError;

  const Failure(this.message, [this.originalError]);

  @override
  String toString() => '$runtimeType: $message';
}

class DatabaseFailure extends Failure {
  const DatabaseFailure(super.message, [super.originalError]);
}

class CameraFailure extends Failure {
  const CameraFailure(super.message, [super.originalError]);
}

class EditorFailure extends Failure {
  const EditorFailure(super.message, [super.originalError]);
}

class AuthFailure extends Failure {
  const AuthFailure(super.message, [super.originalError]);
}

class DriveFailure extends Failure {
  const DriveFailure(super.message, [super.originalError]);
}

class SyncFailure extends Failure {
  const SyncFailure(super.message, [super.originalError]);
}

class StorageFailure extends Failure {
  const StorageFailure(super.message, [super.originalError]);
}
