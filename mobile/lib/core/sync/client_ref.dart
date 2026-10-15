const _prefix = 'clientRef:';
const _optionalPrefix = 'clientRefOpt:';

/// Marks a payload field as "resolve this to the entity's serverId before
/// sending", for when a not-yet-synced entity's clientId has to stand in for
/// a real backend id — e.g. a recipe ingredient's `foodId` when the food was
/// created in the same offline session as the recipe.
///
/// A reference that can never be resolved (the row was deleted before it ever
/// synced) fails the operation for good: right for something the entity cannot
/// exist without, such as a meal entry's food. See [optionalClientRef] for
/// the other kind.
String clientRef(String clientId) => '$_prefix$clientId';

/// Like [clientRef], for a field the payload can do without — a meal entry's
/// `recipeId` (docs/88). The operation still waits while the referenced
/// entity's own create is queued and then sends its serverId, but when the
/// referenced row is simply gone it sends `null` instead of failing, so
/// deleting a never-synced recipe cannot take the meals that used it down
/// with it.
String optionalClientRef(String clientId) => '$_optionalPrefix$clientId';

/// Whether [value] is a [clientRef] or an [optionalClientRef] marker.
bool isClientRef(Object? value) =>
    value is String && (value.startsWith(_prefix) || value.startsWith(_optionalPrefix));

/// Whether [value] is an [optionalClientRef] marker.
bool isOptionalClientRef(Object? value) => value is String && value.startsWith(_optionalPrefix);

/// The clientId inside a marker built by [clientRef] or [optionalClientRef].
String clientRefId(String value) =>
    value.substring(value.startsWith(_optionalPrefix) ? _optionalPrefix.length : _prefix.length);
