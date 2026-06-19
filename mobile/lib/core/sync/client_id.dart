import 'package:uuid/uuid.dart';

const _uuid = Uuid();

/// A new local identifier for an entity created offline-first. Stable for
/// the entity's lifetime — relations reference this, never the (possibly
/// not-yet-assigned) server id.
String newClientId() => _uuid.v4();
