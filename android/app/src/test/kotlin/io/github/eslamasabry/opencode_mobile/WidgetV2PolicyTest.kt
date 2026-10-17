package io.github.eslamasabry.opencode_mobile

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Assert.assertFalse
import org.junit.Test

class WidgetV2PolicyTest {
    @Test fun stoppedServiceOffersSettingsEvenWithAnOldConnectedSnapshot() {
        assertEquals(WidgetV2Policy.Connection.BACKGROUND_SETTINGS,
            WidgetV2Policy.connection(WidgetV2Policy.ConnectionState(2, true, false)))
        assertEquals(WidgetV2Policy.Connection.BACKGROUND_SETTINGS,
            WidgetV2Policy.connection(WidgetV2Policy.ConnectionState(2, false, false)))
        assertEquals(WidgetV2Policy.Connection.BACKGROUND_SETTINGS,
            WidgetV2Policy.connection(WidgetV2Policy.ConnectionState(0, false, false)))
    }
    @Test fun activeServiceStillNeedsACurrentConnectedSnapshotForActions() {
        assertEquals(WidgetV2Policy.Connection.CONNECTED,
            WidgetV2Policy.connection(WidgetV2Policy.ConnectionState(2, true, true)))
        assertEquals(WidgetV2Policy.Connection.OFFLINE,
            WidgetV2Policy.connection(WidgetV2Policy.ConnectionState(2, false, true)))
        assertEquals(WidgetV2Policy.Connection.OFFLINE,
            WidgetV2Policy.connection(WidgetV2Policy.ConnectionState(1, true, true)))
    }
    @Test fun cachedReadyActionConnectsOnlyOnDemandWithoutPretendingToBeLive() {
        assertTrue(WidgetV2Policy.onDemandAvailable(2, true, setOf("stop"), setOf("stop")))
        assertEquals(WidgetV2Policy.Connection.ON_DEMAND,
            WidgetV2Policy.connection(WidgetV2Policy.ConnectionState(2, true, false, onDemandAvailable = true)))
        assertEquals(WidgetV2Policy.Connection.ON_DEMAND,
            WidgetV2Policy.connection(WidgetV2Policy.ConnectionState(2, false, false, onDemandAvailable = true)))
        for (action in listOf("allowOnce", "reject", "stop", "approvePlan", "resume")) {
            assertTrue(WidgetV2Policy.actionEnabled(WidgetV2Policy.Connection.ON_DEMAND,
                action, setOf(action), identityValid = true))
        }
    }
    @Test fun coldActionsNeedKnownSchemaDescriptorCapabilityAndIdentityTogether() {
        assertFalse(WidgetV2Policy.onDemandAvailable(1, true, setOf("stop"), setOf("stop")))
        assertFalse(WidgetV2Policy.onDemandAvailable(2, false, setOf("stop"), setOf("stop")))
        assertFalse(WidgetV2Policy.onDemandAvailable(2, true, emptySet(), setOf("stop")))
        assertFalse(WidgetV2Policy.onDemandAvailable(2, true, setOf("stop"), emptySet()))
        assertFalse(WidgetV2Policy.onDemandAvailable(2, true, setOf("voice"), setOf("voice")))
        assertEquals(WidgetV2Policy.Connection.BACKGROUND_SETTINGS,
            WidgetV2Policy.connection(WidgetV2Policy.ConnectionState(3, true, false, onDemandAvailable = true)))
        assertFalse(WidgetV2Policy.actionEnabled(WidgetV2Policy.Connection.ON_DEMAND,
            "stop", setOf("stop"), identityValid = false))
        assertFalse(WidgetV2Policy.actionEnabled(WidgetV2Policy.Connection.ON_DEMAND,
            "reject", setOf("allowOnce"), identityValid = true))
    }
    @Test fun pendingLeaseKeepsValidatedTapAvailableForRecoveryAfterProcessDeath() {
        val connection = WidgetV2Policy.connection(WidgetV2Policy.ConnectionState(2, true, true,
            onDemandAvailable = true, actionPending = true))
        assertEquals(WidgetV2Policy.Connection.PENDING, connection)
        assertTrue(WidgetV2Policy.actionEnabled(connection, "stop", setOf("stop"), true))
        assertTrue(WidgetV2Policy.actionEnabled(connection, "allowOnce", setOf("allowOnce"), true))
        // Runtime lease and durable ledger reject replay. A different or
        // unsupported target still cannot be enabled by the pending label.
        assertFalse(WidgetV2Policy.actionEnabled(connection, "stop", emptySet(), true))
        assertFalse(WidgetV2Policy.actionEnabled(connection, "stop", setOf("stop"), false))
        assertFalse(WidgetV2Policy.actionEnabled(connection, "voice", setOf("voice"), true))
    }
    @Test fun overlaysRequireLiveConnectionAndSettledLease() {
        assertFalse(WidgetV2Policy.actionEnabled(WidgetV2Policy.Connection.ON_DEMAND,
            "steer", setOf("steer"), true))
        assertFalse(WidgetV2Policy.actionEnabled(WidgetV2Policy.Connection.ON_DEMAND,
            "voice", setOf("voice"), true))
        assertTrue(WidgetV2Policy.actionEnabled(WidgetV2Policy.Connection.CONNECTED,
            "stop", emptySet(), true))
    }
    @Test fun temporaryFailureKeepsSupportedActionsRetryableButHardLimitOffersSettings() {
        assertFalse(WidgetV2Policy.needsBackgroundSettings("rejected", "unavailable"))
        assertTrue(WidgetV2Policy.needsBackgroundSettings("rejected", "unsupported"))
        assertFalse(WidgetV2Policy.needsBackgroundSettings("rejected", "busy"))
        assertFalse(WidgetV2Policy.needsBackgroundSettings("rejected", "staleRequest"))
        assertFalse(WidgetV2Policy.needsBackgroundSettings("uncertain", "unavailable"))
        assertEquals(WidgetV2Policy.Connection.ON_DEMAND,
            WidgetV2Policy.connection(WidgetV2Policy.ConnectionState(2, false, false, onDemandAvailable = true,
                recoveryRequired = WidgetV2Policy.needsBackgroundSettings("rejected", "unavailable"))))
        assertEquals(WidgetV2Policy.Connection.BACKGROUND_SETTINGS,
            WidgetV2Policy.connection(WidgetV2Policy.ConnectionState(2, false, false, onDemandAvailable = false,
                recoveryRequired = WidgetV2Policy.needsBackgroundSettings("rejected", "unavailable"))))
        assertEquals(WidgetV2Policy.Connection.BACKGROUND_SETTINGS,
            WidgetV2Policy.connection(WidgetV2Policy.ConnectionState(
                2, false, false, onDemandAvailable = true, recoveryRequired = true,
            )))
        assertEquals(WidgetV2Policy.Connection.CONNECTED,
            WidgetV2Policy.connection(WidgetV2Policy.ConnectionState(
                2, true, true, onDemandAvailable = true, recoveryRequired = true,
            )))
    }
    @Test fun sizesChangeOnlyAtDocumentedBreakpoints() {
        assertEquals(WidgetV2Policy.Size.COMPACT, WidgetLayoutPolicy.size(119, 180))
        assertEquals(WidgetV2Policy.Size.COMPACT, WidgetLayoutPolicy.size(250, 109))
        assertEquals(WidgetV2Policy.Size.CARD, WidgetLayoutPolicy.size(120, 110))
        assertEquals(WidgetV2Policy.Size.CARD, WidgetLayoutPolicy.size(249, 180))
        assertEquals(WidgetV2Policy.Size.LIST, WidgetLayoutPolicy.size(250, 110))
    }
    @Test fun usageNeverSelectsErrorOrRed() {
        assertEquals("neutral", WidgetLayoutPolicy.usageRole(-1))
        assertEquals("neutral", WidgetLayoutPolicy.usageRole(0))
        assertEquals("attention", WidgetLayoutPolicy.usageRole(20))
        assertEquals("running", WidgetLayoutPolicy.usageRole(21))
    }
    @Test fun wallTimeIsTranslatedToMonotonicTimeAndClamped() {
        assertEquals(900L, WidgetLayoutPolicy.chronometerBase(100, 200, 1000))
        assertEquals(1000L, WidgetLayoutPolicy.chronometerBase(300, 200, 1000))
        assertEquals(0L, WidgetLayoutPolicy.chronometerBase(100, 5000, 1000))
    }
    @Test fun timerFollowsTheTurnWhetherOrNotTheWidgetIsConnected() {
        assertEquals(true, WidgetLayoutPolicy.timerTicks(true, 1000))
        assertEquals(false, WidgetLayoutPolicy.timerTicks(false, 1000))
        assertEquals(false, WidgetLayoutPolicy.timerTicks(true, 0))
    }
    @Test fun teamRowsAreNotShownAsConversationsUnlessWaitingOnTheUser() {
        assertEquals(false, WidgetLayoutPolicy.showRow(true, "", "", false))
        assertEquals(true, WidgetLayoutPolicy.showRow(true, "approvePlan", "", false))
        assertEquals(true, WidgetLayoutPolicy.showRow(true, "", "", true))
        assertEquals(true, WidgetLayoutPolicy.showRow(false, "", "", false))
    }
    @Test fun listNeverExceedsFourRows() {
        assertEquals(1, WidgetLayoutPolicy.rowCount(0))
        assertEquals(2, WidgetLayoutPolicy.rowCount(110))
        assertEquals(4, WidgetLayoutPolicy.rowCount(180))
        assertEquals(4, WidgetLayoutPolicy.rowCount(1000))
    }
    @Test fun acceptedResultImmediatelyRestoresLiveSummaryEvenAfterProcessRestart() {
        assertNull(WidgetV2Policy.actionResultNotice("accepted"))
        assertNull(WidgetV2Policy.actionResultNotice(null))
        assertNull(WidgetV2Policy.actionResultNotice(""))
    }
    @Test fun failedAndUncertainResultsKeepTheirExplanation() {
        assertEquals("rejected", WidgetV2Policy.actionResultNotice("rejected"))
        assertEquals("uncertain", WidgetV2Policy.actionResultNotice("uncertain"))
    }
}
