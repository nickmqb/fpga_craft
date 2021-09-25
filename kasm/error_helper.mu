//tab_size=4
// Copyright 2021 nickmqb
// SPDX-License-Identifier: Apache-2.0

LocationInfo struct {
	line int
	span IntRange
	columnSpan IntRange
	lineText string	
}

ErrorHelper {
	// TODO PERF: This is O(N), so it's not ideal to call this from within a loop.
	spanToLocationInfo(source string, span IntRange) {
		assert(span.from <= span.to)
		from := span.from
		lines := 0
		lineStart := 0
		i := 0
		while i < from {
			ch := source[i]
			if ch == '\n' {
				lines += 1
				lineStart = i + 1
			}
			i += 1
		}
		i = from
		lineEnd := 0
		while true {
			ch := source[i]
			if ch == '\n' || ch == '\r' || ch == '\0' {
				lineEnd = i
				break
			}
			i += 1
		}
		to := min(span.to, lineEnd)
		return LocationInfo { 
			line: lines + 1,
			span: IntRange(from, to),
			columnSpan: IntRange(from - lineStart, to - lineStart),
			lineText: source.slice(lineStart, lineEnd)
		}
	}
	
	getNumColumns(s string, tabSize int) {
		cols := 0
		for i := 0; i < s.length {
			if s[i] == '\t' {
				cols += tabSize
			} else {
				cols += 1
			}
		}
		return cols
	}

	getErrorDesc(path string, source string, span IntRange, text string) {
		li := spanToLocationInfo(source, span)
		indent := getNumColumns(li.lineText.slice(0, li.columnSpan.from), 4)
		width := getNumColumns(li.lineText.slice(li.columnSpan.from, li.columnSpan.to), 4)
		pathInfo := path != "" ? format("\n-> {}:{}", path, li.line) : ""
		return format("{}{}\n{}\n{}{}",
			text,
			pathInfo,
			li.lineText.replace("\t", "    "),
			string.repeatChar(' ', indent),
			string.repeatChar('~', max(1, width)))
			
	}
}
