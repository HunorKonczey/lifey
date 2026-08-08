#!/usr/bin/env bash
#
# Schema ownership guard — docs/chat/44-chat-service-extraction-plan.md §4.2.
#
# The chat's tables and the monolith's tables live in the SAME database but are
# owned by different deployables. That split is enforced two ways:
#
#   1. Postgres grants (devops/chat-database-split.md) — the runtime guarantee.
#   2. This script — the build-time one, which catches the mistake in review
#      instead of at 3am when a migration has already run.
#
# It is deliberately blunt: after the split the monolith has no business naming
# a chat table at all, and the chat service has no business writing to a
# monolith table. Reading one (a foreign key, a select) is fine and expected.
#
# Run it from the repo root:  ./devops/check-schema-ownership.sh
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

backend_migrations="backend/src/main/resources/db/migration"
chat_migrations="chat/src/main/resources/db/migration"

# Tables owned by the chat service.
chat_tables='chat_conversations|chat_messages|chat_participants|chat_message_attachments'
# Tables owned by the monolith that the chat is allowed to READ (§4.4).
monolith_tables='users|user_settings|trainer_clients'

# There is no allowlist, and that is worth saying out loud. The chat schema was
# written on a feature branch and never reached a deployed database (main was at
# V63), so when the chat became its own service the migrations moved with it —
# no applied history to preserve, and therefore no exception to carve out. The
# rule below is absolute.
#
# V65 needs no exception either: it adds chat_* COLUMNS to user_settings, which
# stays the monolith's table, and column names never match a table-name pattern.

failed=0

# Comments explaining the chat schema are legitimate; only real SQL counts.
strip_comments() {
    sed -e 's/--.*$//' "$1"
}

# --- the monolith must not touch chat tables -------------------------------
if [[ -d "$backend_migrations" ]]; then
    for file in "$backend_migrations"/*.sql; do
        [[ -e "$file" ]] || continue

        if hits="$(strip_comments "$file" | grep -nEi "\b($chat_tables)\b" || true)" && [[ -n "$hits" ]]; then
            echo "ERROR: $file names a chat-owned table."
            echo "$hits" | sed 's/^/    /'
            echo "    The chat service is the only writer of chat_* tables (§4.2)."
            echo "    Put this migration under $chat_migrations instead."
            echo
            failed=1
        fi
    done
fi

# --- the chat must not write to monolith tables ----------------------------
if [[ -d "$chat_migrations" ]]; then
    # Writes only. A `references users (id)` in a foreign key is exactly what
    # Phase A is supposed to look like (§4.1), so plain mentions are allowed.
    writes="(alter[[:space:]]+table[[:space:]]+(only[[:space:]]+)?(public\.)?($monolith_tables)\b"
    writes+="|drop[[:space:]]+table[[:space:]]+(if[[:space:]]+exists[[:space:]]+)?(public\.)?($monolith_tables)\b"
    writes+="|insert[[:space:]]+into[[:space:]]+(public\.)?($monolith_tables)\b"
    writes+="|update[[:space:]]+(public\.)?($monolith_tables)[[:space:]]+set"
    writes+="|delete[[:space:]]+from[[:space:]]+(public\.)?($monolith_tables)\b)"

    for file in "$chat_migrations"/*.sql; do
        [[ -e "$file" ]] || continue

        if hits="$(strip_comments "$file" | grep -nEi "$writes" || true)" && [[ -n "$hits" ]]; then
            echo "ERROR: $file writes to a monolith-owned table."
            echo "$hits" | sed 's/^/    /'
            echo "    The chat has read-only access to $monolith_tables (§4.3);"
            echo "    the database will refuse this at runtime anyway."
            echo
            failed=1
        fi
    done
fi

if [[ $failed -ne 0 ]]; then
    echo "Schema ownership check FAILED — see docs/chat/44-chat-service-extraction-plan.md §4.2"
    exit 1
fi

echo "Schema ownership OK."
