const _prefix = 'clientRef:';

/// Marks a payload field as "resolve this to the entity's serverId before
/// sending", for when a not-yet-synced entity's clientId has to stand in for
/// a real backend id — e.g. a recipe ingredient's `foodId` when the food was
/// created in the same offline session as the recipe.
String clientRef(String clientId) => '$_prefix$clientId';

bool isClientRef(Object? value) => value is String && value.startsWith(_prefix);

String clientRefId(String value) => value.substring(_prefix.length);
