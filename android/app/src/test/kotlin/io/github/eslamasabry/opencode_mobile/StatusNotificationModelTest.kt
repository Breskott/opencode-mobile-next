package io.github.eslamasabry.opencode_mobile

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class StatusNotificationModelTest {
    private fun content(title: String = "Running the tests") =
        StatusContent(StatusKind.WORKING, title)

    // ---- the shared notification ID: who owns the row ----

    @Test fun oneServiceStoppingWhileTheOtherRunsDoesNotRemoveTheRow() {
        val owners = StatusOwners()
        assertTrue(owners.start("live"))
        assertFalse(owners.start("server"))
        assertFalse(owners.stop("live"))
        assertTrue(owners.any())
        assertTrue(owners.has("server"))
    }

    @Test fun theLastServiceStoppingRemovesTheRow() {
        val owners = StatusOwners()
        owners.start("live")
        owners.start("server")
        assertFalse(owners.stop("server"))
        assertTrue(owners.stop("live"))
        assertFalse(owners.any())
    }

    @Test fun stoppingAServiceThatNeverStartedRemovesNothing() {
        val owners = StatusOwners()
        owners.start("live")
        assertFalse(owners.stop("server"))
        assertTrue(owners.has("live"))
    }

    @Test fun startingTheSameServiceTwiceIsStillOneOwner() {
        val owners = StatusOwners()
        assertTrue(owners.start("live"))
        assertFalse(owners.start("live"))
        assertTrue(owners.stop("live"))
    }

    // ---- throttle: one update per two seconds, only when it changed ----

    @Test fun firstContentPostsAtOnce() {
        val throttle = StatusThrottle(2_000)
        assertEquals(StatusThrottle.Step.Post(content()), throttle.offer(content(), 1_000))
    }

    @Test fun identicalContentIsSkipped() {
        val throttle = StatusThrottle(2_000)
        throttle.offer(content(), 1_000)
        assertEquals(StatusThrottle.Step.Skip, throttle.offer(content(), 9_000))
    }

    @Test fun aChangeInsideTheGapWaitsForTheRestOfTheGap() {
        val throttle = StatusThrottle(2_000)
        throttle.offer(content("a"), 1_000)
        assertEquals(StatusThrottle.Step.Wait(1_400), throttle.offer(content("b"), 1_600))
        assertNull(throttle.due(2_000))
        assertEquals(content("b"), throttle.due(3_000))
    }

    @Test fun aBurstInsideTheGapProducesOneTrailingPostWithTheNewest() {
        val throttle = StatusThrottle(2_000)
        throttle.offer(content("a"), 0)
        assertTrue(throttle.offer(content("b"), 100) is StatusThrottle.Step.Wait)
        assertEquals(StatusThrottle.Step.Skip, throttle.offer(content("c"), 200))
        assertEquals(StatusThrottle.Step.Skip, throttle.offer(content("d"), 300))
        assertEquals(content("d"), throttle.due(2_000))
        assertNull(throttle.due(2_001))
    }

    @Test fun updatesTwoSecondsApartBothPost() {
        val throttle = StatusThrottle(2_000)
        assertTrue(throttle.offer(content("a"), 0) is StatusThrottle.Step.Post)
        assertTrue(throttle.offer(content("b"), 2_000) is StatusThrottle.Step.Post)
    }

    @Test fun returningToWhatIsShownCancelsTheTrailingPost() {
        val throttle = StatusThrottle(2_000)
        throttle.offer(content("a"), 0)
        throttle.offer(content("b"), 500)
        assertEquals(StatusThrottle.Step.Skip, throttle.offer(content("a"), 700))
        assertNull(throttle.due(5_000))
    }

    @Test fun aServiceStartingForcesAPostAndRestartsTheGap() {
        val throttle = StatusThrottle(2_000)
        throttle.offer(content("a"), 0)
        throttle.offer(content("b"), 100)
        throttle.force(content("c"), 200)
        assertNull(throttle.due(5_000))
        assertEquals(StatusThrottle.Step.Skip, throttle.offer(content("c"), 300))
        assertTrue(throttle.offer(content("d"), 400) is StatusThrottle.Step.Wait)
    }

    @Test fun resetForgetsWhatWasShown() {
        val throttle = StatusThrottle(2_000)
        throttle.offer(content("a"), 0)
        throttle.reset()
        assertTrue(throttle.offer(content("a"), 10) is StatusThrottle.Step.Post)
    }

    // ---- what Dart may send ----

    @Test fun aWellFormedStatusIsRead() {
        val parsed = StatusContent.fromMap(mapOf(
            "kind" to "working",
            "title" to "Running the tests",
            "text" to "UI review · 5 of 6 tasks",
            "lines" to listOf("a", "b"),
            "subText" to "IPTV_King · 4 min",
            "progress" to 83,
            "actions" to listOf("open", "stop_reply"),
            "sessionId" to "s1",
            "publicTitle" to "OpenCode · 1 working",
        ))!!
        assertEquals(StatusKind.WORKING, parsed.kind)
        assertEquals(83, parsed.progress)
        assertEquals(listOf(StatusAction.OPEN, StatusAction.STOP_REPLY), parsed.actions)
        assertEquals("OpenCode · 1 working", parsed.publicTitle)
        assertEquals("s1", parsed.sessionId)
    }

    @Test fun anUnknownKindOrAMissingTitleIsRefused() {
        assertNull(StatusContent.fromMap(mapOf("kind" to "mystery", "title" to "x")))
        assertNull(StatusContent.fromMap(mapOf("kind" to "idle")))
        assertNull(StatusContent.fromMap(mapOf("kind" to "idle", "title" to "  ")))
        assertNull(StatusContent.fromMap(null))
    }

    @Test fun unknownActionsAreDroppedAndOpenIsTheDefault() {
        val parsed = StatusContent.fromMap(mapOf(
            "kind" to "idle", "title" to "Ready", "actions" to listOf("format_disk", "exec"),
        ))!!
        assertEquals(listOf(StatusAction.OPEN), parsed.actions)
    }

    @Test fun progressIsClampedAndLinesAreCapped() {
        val parsed = StatusContent.fromMap(mapOf(
            "kind" to "working", "title" to "t", "progress" to 400,
            "lines" to listOf("1", "2", "3", "4", "5", "6"),
        ))!!
        assertEquals(100, parsed.progress)
        assertEquals(StatusContent.MAX_LINES, parsed.lines.size)
    }

    @Test fun noProgressMeansNoBar() {
        assertNull(StatusContent.fromMap(mapOf("kind" to "idle", "title" to "t"))!!.progress)
    }

    @Test fun overlongTextIsCut() {
        val parsed = StatusContent.fromMap(mapOf(
            "kind" to "idle", "title" to "x".repeat(1_000),
        ))!!
        assertEquals(StatusContent.MAX_TEXT, parsed.title.length)
    }

    @Test fun everyKindAndActionNameRoundTrips() {
        for (kind in StatusKind.values()) assertEquals(kind, StatusKind.fromWire(kind.wire))
        for (action in StatusAction.values()) assertEquals(action, StatusAction.fromWire(action.wire))
    }
}

class AlertButtonsTest {
    @Test fun aPermissionOffersAllowOnceAndRejectOnly() {
        val plan = AlertButtons.plan("permission", quickReply = false, options = emptyList())
        assertEquals(listOf("allow", "deny"), plan.map { it.decision })
        assertTrue(plan.none { it.decision.contains("always") })
    }

    @Test fun allowOnceNeedsTheUnlockedPhoneButRejectDoesNot() {
        val plan = AlertButtons.plan("permission", false, emptyList())
        assertTrue(plan.first { it.decision == "allow" }.authRequired)
        assertFalse(plan.first { it.decision == "deny" }.authRequired)
    }

    @Test fun optionsNeverAddAlwaysAllowToAPermission() {
        val plan = AlertButtons.plan("permission", true, listOf("Always", "Never"))
        assertEquals(listOf("allow", "deny"), plan.map { it.decision })
    }

    @Test fun threeShortOptionsBecomeButtons() {
        val plan = AlertButtons.plan("question", false, listOf("Yes", "No", "Later"))
        assertEquals(listOf("option0", "option1", "option2"), plan.map { it.decision })
        assertEquals(listOf("Yes", "No", "Later"), plan.map { it.optionText })
    }

    @Test fun replyKeepsOneSlotSoAtMostTwoOptionsJoinIt() {
        val plan = AlertButtons.plan("question", true, listOf("Yes", "No", "Later"))
        assertEquals(listOf("reply", "option0", "option1"), plan.map { it.decision })
    }

    @Test fun moreThanThreeOptionsGiveNoButtons() {
        assertTrue(AlertButtons.plan("question", false, listOf("a", "b", "c", "d")).isEmpty())
        assertEquals(
            listOf("reply"),
            AlertButtons.plan("question", true, listOf("a", "b", "c", "d")).map { it.decision },
        )
    }

    @Test fun aLongOptionMakesTheWholeSetFallBackToOpen() {
        assertTrue(AlertButtons.shortOptions(listOf("Yes", "x".repeat(25))).isEmpty())
        assertEquals(listOf("x".repeat(24)), AlertButtons.shortOptions(listOf("x".repeat(24))))
    }

    @Test fun blankOrRepeatedOptionsGiveNoButtons() {
        assertTrue(AlertButtons.shortOptions(listOf("Yes", " ")).isEmpty())
        assertTrue(AlertButtons.shortOptions(listOf("Yes", "Yes")).isEmpty())
        assertTrue(AlertButtons.shortOptions(emptyList()).isEmpty())
    }

    @Test fun otherKindsCarryNoButtons() {
        assertTrue(AlertButtons.plan("complete", false, listOf("a")).isEmpty())
        assertTrue(AlertButtons.plan("error", false, emptyList()).isEmpty())
    }
}

class AlertTitlesTest {
    @Test fun aShellCommandPermissionAsksToRunIt() {
        assertTrue(AlertTitles.usesCommandTitle("permission", true))
    }

    @Test fun otherPermissionsAndKindsKeepTheirTitle() {
        assertFalse(AlertTitles.usesCommandTitle("permission", false))
        assertFalse(AlertTitles.usesCommandTitle("question", true))
    }
}
