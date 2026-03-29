package com.pillyliu.pinprofandroid.library

internal fun rulesheetTableWrapperScript(): String = """
    document.querySelectorAll('table').forEach((table) => {
        if (table.parentElement && table.parentElement.classList.contains('table-scroll')) return;
        const wrapper = document.createElement('div');
        wrapper.className = 'table-scroll';
        table.parentNode.insertBefore(wrapper, table);
        wrapper.appendChild(table);
    });
""".trimIndent()
