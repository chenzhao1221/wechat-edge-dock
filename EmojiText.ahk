; Ordinary Unicode emoji use an explicit font; Chinese retains the existing face.
NotifyGraphemes(text) {
    parts := [], pos := 1
    while RegExMatch(text, '(*UTF16)(*UCP)\X', &match, pos) {
        cluster := match[0], codepoint := Ord(cluster)
        ; AHK's older PCRE Unicode table does not join modern emoji sequences.
        join := parts.Length && (codepoint = 0x200d
            || SubStr(parts[parts.Length], -1) = Chr(0x200d)
            || (codepoint >= 0x1f3fb && codepoint <= 0x1f3ff)
            || (codepoint >= 0xe0020 && codepoint <= 0xe007f)
            || (codepoint >= 0x1f1e6 && codepoint <= 0x1f1ff
                && StrLen(parts[parts.Length]) = 2
                && Ord(parts[parts.Length]) >= 0x1f1e6 && Ord(parts[parts.Length]) <= 0x1f1ff))
        if join
            parts[parts.Length] .= cluster
        else
            parts.Push(cluster)
        pos += StrLen(match[0])
    }
    return parts
}

NotifyTextPrefix(text, maximum := 60) {
    parts := NotifyGraphemes(text), out := ''
    Loop Min(parts.Length, maximum)
        out .= parts[A_Index]
    return out (parts.Length > maximum ? '…' : '')
}

NotifyIsEmoji(text) => RegExMatch(text, '(*UTF16)[\x{1F000}-\x{1FAFF}\x{2300}-\x{23FF}\x{2600}-\x{27BF}\x{FE0F}\x{20E3}]')

; Return false to preserve the original renderer for text without emoji.
NotifyDrawEmojiText(G, text, options, font, width, height) {
    if !NotifyIsEmoji(text)
        return false
    ReadOption(name, fallback) {
        return RegExMatch(options, 'i)(?:^| )' name '(-?[\d.]+)', &m) ? Number(m[1]) : fallback
    }
    x := ReadOption('x', 0), y := ReadOption('y', 0), w := ReadOption('w', width)
    h := ReadOption('h', height - y), size := ReadOption('s', 14)
    color := RegExMatch(options, 'i)(?:^| )c([a-f\d]+)', &m) ? m[1] : 'ff111114'
    weight := InStr(options, 'Bold') ? 'Bold' : 'Normal'
    lines := NotifyEmojiLayout(G, text, font, size, weight, w, h)
    lineH := Ceil(size * 1.6)
    for rowIndex, row in lines {
        dx := x
        for item in row {
            opts := 'x' dx ' y' (y + (rowIndex - 1) * lineH)
                . ' w' (item.w + size) ' h' lineH ' c' color ' r3 s' Round(size)
                . ' NoWrap ' (item.emoji ? 'Normal' : weight)
            Gdip_TextToGraphics(G, item.text, opts, item.emoji ? 'Segoe UI Emoji' : font, width, height)
            dx += item.w
        }
    }
    return true
}

NotifyEmojiLayout(G, text, font, size, weight, w, h) {
    rows := [[]], used := 0, lineH := Ceil(size * 1.6), maxLines := Max(1, Floor(h / lineH))
    style := weight = 'Bold' ? 1 : 0
    fmt := Toast.__format(0x5800) ; NoClip + MeasureTrailingSpaces + NoWrap
    Measure(cluster, emoji) {
        family := emoji ? 'Segoe UI Emoji' : font
        handle := Toast.__font(family, size, emoji ? 0 : style)
        box := Buffer(16, 0)
        NumPut('float', 10000, 'float', 10000, box, 8)
        measured := StrSplit(Gdip_MeasureString(G, cluster, handle, fmt, &box), '|')
        return Max(1, Number(measured[3]))
    }
    parts := NotifyGraphemes(text)
    for index, cluster in parts {
        emoji := !!NotifyIsEmoji(cluster), advance := Measure(cluster, emoji)
        row := rows[rows.Length]
        merge := !emoji && row.Length && !row[row.Length].emoji
        if merge
            advance := Measure(row[row.Length].text cluster, false) - row[row.Length].w
        if used + advance > w && row.Length {
            if rows.Length >= maxLines {
                ellipsisW := Measure('…', false)
                while row.Length && used + ellipsisW > w {
                    last := row[row.Length]
                    clusters := NotifyGraphemes(last.text)
                    if !last.emoji && clusters.Length > 1 {
                        shorter := ''
                        Loop clusters.Length - 1
                            shorter .= clusters[A_Index]
                        previousWidth := last.w
                        last.text := shorter, last.w := Measure(shorter, false)
                        used += last.w - previousWidth
                    } else
                        used -= row.Pop().w
                }
                if ellipsisW <= w
                    row.Push({text: '…', w: ellipsisW, emoji: false})
                return rows
            }
            rows.Push([]), used := 0
            row := rows[rows.Length], merge := false, advance := Measure(cluster, emoji)
        }
        if merge {
            row[row.Length].text .= cluster
            row[row.Length].w += advance
        } else
            row.Push({text: cluster, w: advance, emoji: emoji})
        used += advance
    }
    return rows
}
