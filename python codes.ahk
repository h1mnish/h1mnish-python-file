#Requires AutoHotkey v2.0
#SingleInstance Force

global SourceFile := "C:\help\python codes.txt"

!q::
{
    global SourceFile

    if !FileExist(SourceFile) {
        return
    }

    ; L50: max 50 characters tak type kar sakte ho, T10: 10 seconds timeout
    ih := InputHook("L50 T10", "{Enter}{Esc}")
    ih.Start()
    ih.Wait()

    queryText := Trim(ih.Input)
    foundEndKey := ih.EndKey

    if (foundEndKey != "Enter" || queryText = "")
        return

    try {
        sourceText := FileRead(SourceFile, "UTF-8")
        code := ExtractQuestionCode(sourceText, queryText)

        if (code != "") {
            A_Clipboard := code
            ClipWait(2)
        }
    }
    catch as err {
    }
}

ExtractQuestionCode(sourceText, query)
{
    ; Heading ke saath uska poora title bhi capture kar rahe hain
    headingPattern := "m)^[ \t]*(?:#{1,6}[ \t]*)?(?:\*\*)?Q(\d+)\.[ \t]*([^\r\n]*)"

    headings := []
    position := 1

    while RegExMatch(sourceText, headingPattern, &match, position) {
        headings.Push({
            number: Integer(match[1]),
            title: Trim(match[2], " *`t"),
            start: match.Pos,
            length: match.Len
        })

        position := match.Pos + match.Len
    }

    selectedIndex := 0
    isNumberSearch := RegExMatch(query, "^\d{1,3}$")

    if (isNumberSearch) {
        targetNum := Integer(query)
        for index, heading in headings {
            if (heading.number = targetNum) {
                selectedIndex := index
                break
            }
        }
    } else {
        ; Keyword search (Case-insensitive)
        for index, heading in headings {
            if InStr(heading.title, query, false) {
                selectedIndex := index
                break
            }
        }
    }

    if !selectedIndex
        return ""

    selected := headings[selectedIndex]
    sectionStart := selected.start + selected.length
    sectionEnd := (selectedIndex < headings.Length) ? headings[selectedIndex + 1].start : StrLen(sourceText) + 1

    section := SubStr(
        sourceText,
        sectionStart,
        sectionEnd - sectionStart
    )

    fence := Chr(96) Chr(96) Chr(96)
    codePattern := "s)" fence "[^\r\n]*\R(.*?)\R" fence

    codeBlocks := []
    position := 1
    previousEnd := 1

    while RegExMatch(section, codePattern, &codeMatch, position) {
        precedingText := SubStr(
            section,
            previousEnd,
            codeMatch.Pos - previousEnd
        )

        isTest := RegExMatch(
            precedingText,
            "is)\*\*Test:\*\*[ \t\r\n]*$|Test:[ \t\r\n]*$"
        )

        if !isTest {
            code := Trim(codeMatch[1], "`r`n")
            (Trim(code) != "") && codeBlocks.Push(code)
        }

        previousEnd := codeMatch.Pos + codeMatch.Len
        position := previousEnd
    }

    if (codeBlocks.Length = 0)
        return ""

    result := ""
    for index, block in codeBlocks {
        (index > 1) && (result .= "`r`n`r`n")
        result .= block
    }

    return result
}
