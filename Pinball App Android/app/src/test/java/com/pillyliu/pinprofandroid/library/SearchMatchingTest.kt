package com.pillyliu.pinprofandroid.library

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class SearchMatchingTest {

    @Test
    fun matchesSearchQuery_matchesAcrossSeparateTokens() {
        assertTrue(matchesSearchQuery("foo premium", listOf("Foo Fighters", "Premium")))
        assertTrue(matchesSearchQuery("james pro", listOf("James Bond 007", "Pro")))
        assertTrue(matchesSearchQuery("godzilla 70th", listOf("Godzilla", "70th Anniversary")))
    }

    @Test
    fun matchesSearchQuery_foldsDiacritics() {
        assertTrue(matchesSearchQuery("jersey jack", listOf("Jérsey Jäck Pinball")))
    }

    @Test
    fun matchesSearchQuery_requiresAllQueryTokens() {
        assertFalse(matchesSearchQuery("bond 60th", listOf("James Bond 007", "Premium")))
    }
}
