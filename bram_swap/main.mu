//tab_size=4
// Copyright 2021 nickmqb
// SPDX-License-Identifier: Apache-2.0

exit(code int) void #Foreign("exit")

Util {
	writeByteHexTo(b byte, sb StringBuilder) {
		if b < 16 {
			sb.write("0")
		}
		ulong.writeHexTo(b, sb)
	}

	format8(n int) {
		if n < 0 {
			n += 256
		}
		assert(0 <= n && n < 256)
		sb := StringBuilder{}
		writeByteHexTo(cast(n, byte), ref sb)
		return sb.compactToString()
	}

	format16(n int) {
		if n < 0 {
			n += 0x10000
		}
		assert(0 <= n && n <= ushort.maxValue)
		str := toHex(n)
		assert(str.length <= 4)
		return leftpad(str, 4, '0')
	}

	toHex(n int) {
		assert(n >= 0)
		sb := StringBuilder{}
		ulong.writeHexTo(cast(n, ulong), ref sb)
		return sb.compactToString()
	}

	leftpad(s string, n int, ch char) {
		return format("{}{}", string.repeatChar(ch, max(0, n - s.length)), s)
	}
}

toUpper(ch char) {
	if 'a' <= ch && ch <= 'z' {
		return ch - 32
	}
	return ch
}

string {
	split_noEmptyEntries(s string, sep char) {
		result := List<string>{}
		from := 0
		j := 0
		for i := 0; i < s.length {
			if s[i] == sep {
				if from < i {
					result.add(s.slice(from, i))
				}
				from = i + 1
				j += 1
			}
		}
		if from < s.length {
			result.add(s.slice(from, s.length))
		}
		return result		
	}

	trim(s string) {
		from := 0
		while from < s.length {
			ch := s[from]
			if ch == ' ' || ch == '\n' || ch == '\r' || ch == '\t' {
				from += 1
			} else {
				break
			}
		}
		to := s.length - 1
		while to >= from {
			ch := s[to]
			if ch == ' ' || ch == '\n' || ch == '\r' || ch == '\t' {
				to -= 1
			} else {
				break
			}
		}
		return s.slice(from, to + 1)
	}

	toUpper(s string) {
		rb := StringBuilder{}
		rb.reserve(s.length)
		for i := 0; i < s.length {
			rb.writeChar(::toUpper(s[i]))
		}
		return rb.compactToString()
	}

	stripPrefix(s string, prefix string) {
		assert(s.startsWith(prefix))
		return s.slice(prefix.length, s.length)
	}
}

FileData struct #RefType {
	path string
	data string
}

Args struct #RefType {
	input FileData
	outputPath string
	seed uint
	modules List<string>
}

tryReadFile(path string) {
	sb := new StringBuilder{}
	if !File.tryReadToStringBuilder(path, sb) {
		return null
	}
	return new FileData { path: path, data: sb.compactToString() }
}

parseArgs(parser CommandLineArgsParser) {
	args := new Args { modules: new List<string>{} }

	token := parser.readToken()

	while token != "" {
		if token.startsWith("-") {
			if token == "--input" {
				token = parser.readToken()
				file := tryReadFile(token)
				if file != null {
					args.input = file
				} else {
					parser.error(format("Could not read file: {}", token))
				}
			} else if token == "--output" {
				token = parser.readToken()
				args.outputPath = token
			} else if token == "--seed" {
				token = parser.readToken()
				pr := uint.tryParse(token)
				if pr.hasValue && pr.value > 0 {
					args.seed = pr.value
				} else {
					parser.error("Expected: number")
				}
			} else {
				parser.error(format("Invalid flag: {}", token))
			}
		} else {
			args.modules.add(token)
		}
		token = parser.readToken()
	}

	if args.input == null {
		parser.expected("--input [path]")
	}
	if args.outputPath == "" {
		parser.expected("--output [path]")
	}
	if args.seed == 0 {
		parser.expected("--seed [number]")
	}

	return args
}

parseBytes(s string) {
	result := new List<byte>{}
	for i := s.length - 1; i >= 0; i -= 2 {
		first := cast(ulong.tryParseHex(s.slice(i, i + 1)).unwrap(), int)
		second := i > 0 ? cast(ulong.tryParseHex(s.slice(i - 1, i)).unwrap(), int) : 0
		val := first + (second << 4)
		result.add(cast(val, byte))		
	}
	while result.count < 32 {
		result.add(0)
	}
	return new result.slice(0, 32)
}

getRandomBytes(rs *uint) {
	result := new Array<byte>(32)
	for i := 0; i < result.count {
		result[i] = cast(Random.xorshift32(rs), byte)
	}
	return result
}

writeHexData(rb StringBuilder, bytes Array<byte>) {
	for i := 0; i < bytes.count; i += 2 {
		val := bytes[i] + (bytes[i + 1] << 8)
		rb.write(Util.format16(cast(val, int)))
		if i < bytes.count - 2 {
			rb.write(" ")
		}
	}
	rb.write("\n")
}

formatBytes(bytes Array<byte>) {
	rb := StringBuilder{}
	for i := bytes.count - 1; i >= 0; i -= 1 {
		Util.writeByteHexTo(bytes[i], ref rb)
	}
	return rb.compactToString()
}

main() {
	::currentAllocator = Memory.newArenaAllocator(16 * 1024 * 1024)

	argErrors := new List<CommandLineArgsParserError>{}
	parser := new CommandLineArgsParser.from(Environment.getCommandLineArgs(), argErrors)
	args := parseArgs(parser)

	if argErrors.count > 0 {
		info := parser.getCommandLineInfo()
		for argErrors {
			Stderr.writeLine(CommandLineArgsParser.getErrorDesc(it, info))
		}
		exit(1)
	}

	out := new StringBuilder{}
	contents_out := new StringBuilder{}
	random_out := new StringBuilder{}
	replaceCount := 0

	lines := args.input.data.split('\n')
	slice := -1
	assert(args.seed > 0)
	rs := args.seed
	for ln, i in lines {
		orig := ln

		ln = ln.trim()
		if ln.startsWith("module ") {
			name := ln.stripPrefix("module ")
			for m in args.modules {
				if name.startsWith(m) {
					slice = 0
					break
				}
			}
		}
		
		if slice >= 0 && ln.startsWith("endmodule") {
			assert(slice == 16)
			slice = -1
			replaceCount += 1
		}
		
		if slice >= 0 && ln.startsWith(".INIT_") {
			prefix := format(".INIT_{}(256'h", format("{}", Util.toHex(slice)).toUpper())
			assert(ln.startsWith(prefix))
			startIndex := (orig.length - ln.length) + prefix.length
			endIndex := orig.indexOfChar(')')
			bytes := parseBytes(orig.slice(startIndex, endIndex))
			writeHexData(contents_out, bytes)
			random := getRandomBytes(ref rs)
			writeHexData(random_out, random)
			orig = format("{}{}{}", orig.slice(0, startIndex), formatBytes(random), orig.slice(endIndex, orig.length))
			slice += 1
		}

		out.write(orig)
		if i < lines.count - 1 {
			out.write("\n")
		}
	}

	assert(File.tryWriteString(format("{}_random.v", args.outputPath), out.compactToString()))
	assert(File.tryWriteString(format("{}_random.hex", args.outputPath), random_out.compactToString()))
	assert(File.tryWriteString(format("{}_contents.hex", args.outputPath), contents_out.compactToString()))	

	Stdout.writeLine(format("Replaced {} block rams", replaceCount))
}
