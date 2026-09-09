/// The user's billing tier as resolved by the server (`64` §3.2).
enum EntitlementTier { free, pro }

/// Why the user currently has [EntitlementTier.pro] — `NONE` when free.
enum EntitlementSource {
  none,
  stripe,
  appStore,
  playStore,
  trainerSponsored,
  trainerTrial,
  comp;

  /// The exact string the backend sends/expects — not a case transform of
  /// [name] (`appStore` → `APP_STORE`, not `APPSTORE`).
  String get wireName => switch (this) {
        EntitlementSource.none => 'NONE',
        EntitlementSource.stripe => 'STRIPE',
        EntitlementSource.appStore => 'APP_STORE',
        EntitlementSource.playStore => 'PLAY_STORE',
        EntitlementSource.trainerSponsored => 'TRAINER_SPONSORED',
        EntitlementSource.trainerTrial => 'TRAINER_TRIAL',
        EntitlementSource.comp => 'COMP',
      };

  static EntitlementSource fromWire(String wire) => switch (wire) {
        'STRIPE' => EntitlementSource.stripe,
        'APP_STORE' => EntitlementSource.appStore,
        'PLAY_STORE' => EntitlementSource.playStore,
        'TRAINER_SPONSORED' => EntitlementSource.trainerSponsored,
        'TRAINER_TRIAL' => EntitlementSource.trainerTrial,
        'COMP' => EntitlementSource.comp,
        _ => EntitlementSource.none,
      };
}

/// Present only when the response carries `trainer` — `ROLE_TRAINER` users
/// only (`64` §3.2). `plan`/`status` are kept as the raw server strings
/// (`STARTER`/`PRO`/`STUDIO`, `TRIALING`/`ACTIVE`/`PAST_DUE`/...) rather than
/// mirrored enums — nothing on the mobile side branches on them yet beyond
/// display (Settings tile, `67` §4.4).
class TrainerBillingEntitlement {
  const TrainerBillingEntitlement({
    required this.plan,
    required this.status,
    required this.maxClients,
    required this.activeClients,
    required this.trialEndsAt,
  });

  final String plan;
  final String status;
  final int maxClients;
  final int activeClients;
  final DateTime? trialEndsAt;

  factory TrainerBillingEntitlement.fromJson(Map<String, dynamic> json) {
    return TrainerBillingEntitlement(
      plan: json['plan'] as String,
      status: json['status'] as String,
      maxClients: json['maxClients'] as int,
      activeClients: json['activeClients'] as int,
      trialEndsAt:
          json['trialEndsAt'] == null ? null : DateTime.parse(json['trialEndsAt'] as String),
    );
  }
}

/// A sentinel timestamp for the fields below when [Entitlement.resolved] is
/// false — deliberately far in the past so that anything which forgets to
/// check [Entitlement.resolved] first and compares against it anyway (e.g.
/// `now.isBefore(graceUntil)`) fails safe (treated as expired), not open.
final _unresolvedSentinel = DateTime.fromMillisecondsSinceEpoch(0);

/// Mirrors `EntitlementResponse` (`64` §3.2) plus the two states that never
/// come from the server directly: no cache has ever resolved yet
/// ([Entitlement.unresolvedOpen]), and a cached snapshot whose offline grace
/// (D-M10) has lapsed with no successful refresh ([Entitlement.decayedToFree]).
///
/// Every gate reads a *field* (`adsEnabled`, `historyDays`,
/// `aiCreditsRemaining`) — never `tier`/`source` (D-P5). `tier`/`source`
/// exist for UI copy only.
class Entitlement {
  const Entitlement({
    required this.tier,
    required this.source,
    required this.adsEnabled,
    required this.historyDays,
    required this.aiCreditsRemaining,
    required this.trainer,
    required this.expiresAt,
    required this.checkedAt,
    required this.graceUntil,
    required this.degraded,
    required this.resolved,
  });

  final EntitlementTier tier;
  final EntitlementSource source;
  final bool adsEnabled;

  /// `null` means unlimited.
  final int? historyDays;

  /// `null` means unlimited.
  final int? aiCreditsRemaining;

  final TrainerBillingEntitlement? trainer;
  final DateTime? expiresAt;

  /// Server timestamps this snapshot was resolved / its offline grace (D-M10)
  /// runs out. Meaningless (sentinel) when [resolved] is false.
  final DateTime checkedAt;
  final DateTime graceUntil;

  /// True when the *server* had to fail open resolving this response
  /// (`64` §3.2) — a support/telemetry signal, unrelated to the client-side
  /// synthetic states below.
  final bool degraded;

  /// False only for [Entitlement.unresolvedOpen] — no cache has ever been
  /// written on this device. Every other state, including
  /// [Entitlement.decayedToFree], is `true`: it reflects a real past server
  /// answer, just possibly a stale one. Ad surfaces gate on this (`69` §5.2,
  /// `63` §8.6's "no ad until told otherwise").
  final bool resolved;

  factory Entitlement.fromJson(Map<String, dynamic> json) {
    return Entitlement(
      tier: (json['tier'] as String).toLowerCase() == 'pro'
          ? EntitlementTier.pro
          : EntitlementTier.free,
      source: EntitlementSource.fromWire(json['source'] as String),
      adsEnabled: json['adsEnabled'] as bool,
      historyDays: json['historyDays'] as int?,
      aiCreditsRemaining: json['aiCreditsRemaining'] as int?,
      trainer: json['trainer'] == null
          ? null
          : TrainerBillingEntitlement.fromJson(json['trainer'] as Map<String, dynamic>),
      expiresAt: json['expiresAt'] == null ? null : DateTime.parse(json['expiresAt'] as String),
      checkedAt: DateTime.parse(json['checkedAt'] as String),
      graceUntil: DateTime.parse(json['graceUntil'] as String),
      degraded: json['degraded'] as bool? ?? false,
      resolved: true,
    );
  }

  /// D-P4 branch 1: no cache has ever resolved (fresh install offline, or a
  /// device freshly wiped by logout) — behaves like Pro so a paying user
  /// reinstalling on a plane is never shown ads (`67` §9.1), but [resolved]
  /// is false so a surface like the ad slot keeps waiting rather than
  /// flashing "no ads" and then an ad once the real answer arrives.
  factory Entitlement.unresolvedOpen() => Entitlement(
        tier: EntitlementTier.pro,
        source: EntitlementSource.none,
        adsEnabled: false,
        historyDays: null,
        aiCreditsRemaining: null,
        trainer: null,
        expiresAt: null,
        checkedAt: _unresolvedSentinel,
        graceUntil: _unresolvedSentinel,
        degraded: false,
        resolved: false,
      );

  /// D-P4 branch 4: a cached snapshot whose `graceUntil` (D-M10) has passed
  /// with no successful refresh since. `historyDays`/`aiCreditsRemaining`
  /// can't be read from the server here — that is the entire problem — so
  /// these two numbers are a deliberate, narrowly-scoped exception to D-P5's
  /// "the client never derives policy": they only apply to an already-decayed,
  /// already-offline snapshot, and are kept in sync with `BillingProperties`'
  /// current free-tier defaults (`64` §3.3) by convention, not by config.
  factory Entitlement.decayedToFree({
    required DateTime checkedAt,
    required DateTime graceUntil,
  }) =>
      Entitlement(
        tier: EntitlementTier.free,
        source: EntitlementSource.none,
        adsEnabled: true,
        historyDays: _decayedHistoryDays,
        aiCreditsRemaining: _decayedAiCreditsRemaining,
        trainer: null,
        expiresAt: null,
        checkedAt: checkedAt,
        graceUntil: graceUntil,
        degraded: false,
        resolved: true,
      );

  static const _decayedHistoryDays = 30;
  static const _decayedAiCreditsRemaining = 0;
}
