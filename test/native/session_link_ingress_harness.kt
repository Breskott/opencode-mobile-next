package io.github.eslamasabry.opencode_mobile

fun main() {
    check(SessionLinkIngress.accepts("a".repeat(1024)))
    check(!SessionLinkIngress.accepts("a".repeat(1025)))
    check(!SessionLinkIngress.accepts(""))
    for (invalid in listOf(" ", "\n", "\r", "\t", "\u0000", "\u007f", "é", "\u202e", "😀")) {
        check(!SessionLinkIngress.accepts("opencode-mobile://session/v2?x=$invalid"))
    }
    check(SessionLinkIngress.accepts("opencode-mobile://session/v2?server=https%3A%2F%2Fdevice.tailnet.ts.net"))
    println("PASS bounded ASCII native ingress")
}
