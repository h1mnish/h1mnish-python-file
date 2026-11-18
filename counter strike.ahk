#Requires AutoHotkey v2.0
#SingleInstance Force

global SourceFile := "C:\help\counter strike.txt"
global GhostCode := ""
global GhostIndex := 1
global GhostActive := false

!q::
{
    global SourceFile, GhostCode, GhostIndex, GhostActive

    if !FileExist(SourceFile) {
        return
    }

    ; Purana ghost mode agar chal raha ho toh band karein
    GhostActive := false
    KeyWait("Alt")

    pastedText := ""
    ; {RShift} ko end key ke roop me add kiya gaya hai
    ih := InputHook("L100 T15", "{Enter}{Esc}{RShift}")
    
    ih.KeyOpt("^v", "SN")

    ih.OnKeyDown := (hook, vk, sc) => (
        (vk = 0x56 && GetKeyState("Control", "P")) ? (pastedText .= Trim(A_Clipboard)) : ""
    )

    ih.Start()
    ih.Wait()

    cleanInput := RegExReplace(ih.Input, "[\x00-\x1F]", "")
    queryText := Trim(cleanInput . pastedText)
    foundEndKey := ih.EndKey

    if (queryText = "" || (foundEndKey != "Enter" && foundEndKey != "RShift"))
        return

    try {
        sourceText := FileRead(SourceFile, "UTF-8")
        code := ExtractQuestionCode(sourceText, queryText)

        if (code != "") {
            if (foundEndKey = "Enter") {
                ; Normal Copy Mode
                A_Clipboard := code
                ClipWait(2)
            } 
            else if (foundEndKey = "RShift") {
                ; Ghost Typing Mode Chalu
                GhostCode := StrReplace(code, "`r`n", "`n") ; Newlines ko clean karein
                GhostIndex := 1
                GhostActive := true
            }
        }
    }
    catch as err {
    }
}

; Ghost Typing Mode active hone par hi a-z keys ko intercept karein
#HotIf GhostActive
a::
b::
c::
d::
e::
f::
g::
h::
i::
j::
k::
l::
m::
n::
o::
p::
q::
r::
s::
t::
u::
v::
w::
x::
y::
z::
{
    global GhostCode, GhostIndex, GhostActive

    if (GhostIndex <= StrLen(GhostCode)) {
        char := SubStr(GhostCode, GhostIndex, 1)
        
        ; Agar Enter/Newline aaye toh Enter bhejein, warna raw character bhejein
        if (char = "`n") {
            Send("{Enter}")
        } else {
            SendText(char)
        }
        
        GhostIndex++
        
        ; Poora code type hone par mode automatically band ho jayega
        if (GhostIndex > StrLen(GhostCode)) {
            GhostActive := false
            GhostCode := ""
            GhostIndex := 1
        }
    } else {
        GhostActive := false
    }
}

; Mid-typing me exit lene ke liye Esc ya F12 dabayein
Esc::
F12::
{
    global GhostActive, GhostCode, GhostIndex
    GhostActive := false
    GhostCode := ""
    GhostIndex := 1
}
#HotIf


ExtractQuestionCode(sourceText, query)
{
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
