/**
 * Everything the chat needs from the rest of the application, expressed as
 * interfaces the chat itself owns (docs/chat/44-chat-service-extraction-plan.md §5).
 *
 * <p>The direction matters: <b>the chat defines these, the other modules
 * implement them</b>. Nothing under {@code com.lifey.chat} imports
 * {@code com.lifey.user}, {@code com.lifey.trainer}, {@code com.lifey.settings},
 * {@code com.lifey.push}, {@code com.lifey.mail} or {@code com.lifey.auth} — it
 * only ever sees the records in this package. The adapters live in the module
 * being called from ({@code com.lifey.user.ChatUserDirectoryAdapter} and
 * friends), so the dependency shows up in the package tree the right way round.
 *
 * <p>That inversion is what makes extracting the chat into its own service a
 * mechanical job rather than archaeology: the interfaces travel with the chat
 * and get a JDBC or HTTP implementation on the other side, while everything
 * above them stays untouched. It is also simply better code if the extraction
 * never happens — the chat can no longer reach into another module's entities.
 */
package com.lifey.chat.spi;
