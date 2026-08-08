package com.lifey.chat.spi;

/**
 * The only thing the chat knows about a person: enough to put them in a thread
 * header and a notification title.
 *
 * @param displayName already resolved by the provider — name if there is one,
 *                    email otherwise. Deliberately not first/last name: a user
 *                    who signed up without filling in their profile still needs
 *                    something to show, and that fallback belongs to whoever
 *                    owns the user record, not to the chat.
 */
public record ChatUser(Long id, String displayName, String email) {
}
