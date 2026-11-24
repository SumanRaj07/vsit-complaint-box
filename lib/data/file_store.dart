// Persist a picked evidence file into the app's own documents directory so
// it survives the system picker's cache being cleared.
// On web this is a no-op (web picks have no file path).
export 'file_store_stub.dart'
    if (dart.library.io) 'file_store_io.dart';
