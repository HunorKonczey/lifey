package com.lifey.chat.dto;

/**
 * What the other side of a thread is <em>to the caller</em>, not what roles
 * they hold globally. A trainer who also has their own trainer sees both kinds
 * in one list, and this is the label that keeps the two apart (§6.1).
 */
public enum ChatPeerRole {
    TRAINER,
    CLIENT
}
