package io.github.eslamasabry.opencode_mobile

import java.io.File
import javax.xml.parsers.DocumentBuilderFactory
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotEquals
import org.junit.Test
import org.w3c.dom.Element

/** Checks the XML used by RemoteViews without needing a launcher or emulator. */
class WidgetSessionCardLayoutTest {
    @Test fun cardStepCanWrapWithoutTheTimerRowClippingItsSecondLine() {
        val source = sequenceOf(
            File("src/main/res/layout/widget_session_v2_row.xml"),
            File("app/src/main/res/layout/widget_session_v2_row.xml"),
            File("android/app/src/main/res/layout/widget_session_v2_row.xml"),
        ).first { it.isFile }
        val document = DocumentBuilderFactory.newInstance().apply {
            isNamespaceAware = true
        }.newDocumentBuilder().parse(source)
        val texts = document.getElementsByTagName("TextView")
        val step = (0 until texts.length).map { texts.item(it) as Element }.first {
            it.android("id") == "@+id/widget_v2_step"
        }
        assertEquals("2", step.android("maxLines"))
        assertEquals("wrap_content", step.android("layout_height"))
        val timerRow = step.parentNode as Element
        assertEquals("wrap_content", timerRow.android("layout_height"))
        assertNotEquals("18dp", timerRow.android("layout_height"))
    }

    private fun Element.android(name: String): String =
        getAttributeNS("http://schemas.android.com/apk/res/android", name)
}
