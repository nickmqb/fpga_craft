//tab_size=4
// Copyright 2021 nickmqb
// SPDX-License-Identifier: Apache-2.0

OpcodeInfo {
	:mul = 0xdc
	:mul16 = 0xdd
	:mul12s = 0xdf

	:push = 0xce
	:pop = 0xcf
	:push_slow = 0xee
	:pop_slow = 0xef
	:in_ = 0xe2
	:out = 0xe3
	:get_ex = 0xe4
	:put_ex = 0xe5
	:jump = 0xe8
	:call = 0xe9
	:ret = 0xea

	:goto = 0xf0
	:bzbnz = 0xf8

	addDefaultSymbols(symbols Map<string, SymbolInfo>) {
		symbols.add("var", new SymbolInfo { type: SymbolType.reserved })
		symbols.add("if", new SymbolInfo { type: SymbolType.reserved })
		symbols.add("else", new SymbolInfo { type: SymbolType.reserved })
		symbols.add("z", new SymbolInfo { type: SymbolType.reserved })
		symbols.add("nz", new SymbolInfo { type: SymbolType.reserved })
		symbols.add("begin", new SymbolInfo { type: SymbolType.reserved })
		symbols.add("outer_begin", new SymbolInfo { type: SymbolType.reserved })
		symbols.add("in", new SymbolInfo { type: SymbolType.reserved })
		symbols.add("out", new SymbolInfo { type: SymbolType.reserved })
		symbols.add("goto", new SymbolInfo { type: SymbolType.reserved })
		symbols.add("u", new SymbolInfo { type: SymbolType.reserved }) // To avoid confusion between compare and put
		symbols.add("s", new SymbolInfo { type: SymbolType.reserved }) // To avoid confusion between compare and put
		symbols.add("call", new SymbolInfo { type: SymbolType.reserved })
		symbols.add("<<", new SymbolInfo { type: SymbolType.reserved })
		symbols.add(">>s", new SymbolInfo { type: SymbolType.reserved })
		symbols.add(">>u", new SymbolInfo { type: SymbolType.reserved })
		
		symbols.add("+", new SymbolInfo { type: SymbolType.opcode, opcode: 0xc0 })
		symbols.add("dec", new SymbolInfo { type: SymbolType.opcode, opcode: 0xc1 })
		symbols.add("dup", new SymbolInfo { type: SymbolType.opcode, opcode: 0xc2 })
		symbols.add("inc", new SymbolInfo { type: SymbolType.opcode, opcode: 0xc3 })
		symbols.add("swap", new SymbolInfo { type: SymbolType.opcode, opcode: 0xc4 })
		symbols.add("sub", new SymbolInfo { type: SymbolType.opcode, opcode: 0xc5 })
		symbols.add("~", new SymbolInfo { type: SymbolType.opcode, opcode: 0xc6 })
		symbols.add("neg", new SymbolInfo { type: SymbolType.opcode, opcode: 0xc7 })
		symbols.add("&", new SymbolInfo { type: SymbolType.opcode, opcode: 0xc8 })
		symbols.add("|", new SymbolInfo { type: SymbolType.opcode, opcode: 0xc9 })
		symbols.add("^", new SymbolInfo { type: SymbolType.opcode, opcode: 0xca })
		symbols.add("&~", new SymbolInfo { type: SymbolType.opcode, opcode: 0xcb })
		symbols.add(">=u", new SymbolInfo { type: SymbolType.opcode, opcode: 0xd0 })
		symbols.add("<u", new SymbolInfo { type: SymbolType.opcode, opcode: 0xd1 })
		symbols.add("<s", new SymbolInfo { type: SymbolType.opcode, opcode: 0xd2 })
		symbols.add(">=s", new SymbolInfo { type: SymbolType.opcode, opcode: 0xd3 })
		symbols.add(">u", new SymbolInfo { type: SymbolType.opcode, opcode: 0xd4 })
		symbols.add("<=u", new SymbolInfo { type: SymbolType.opcode, opcode: 0xd5 })
		symbols.add("<=s", new SymbolInfo { type: SymbolType.opcode, opcode: 0xd6 })
		symbols.add(">s", new SymbolInfo { type: SymbolType.opcode, opcode: 0xd7 })
		symbols.add("not", new SymbolInfo { type: SymbolType.opcode, opcode: 0xd8 })
		symbols.add("to_bool", new SymbolInfo { type: SymbolType.opcode, opcode: 0xd9 })
		symbols.add("==", new SymbolInfo { type: SymbolType.opcode, opcode: 0xda })
		symbols.add("!=", new SymbolInfo { type: SymbolType.opcode, opcode: 0xdb })
		symbols.add("mul", new SymbolInfo { type: SymbolType.opcode, opcode: 0xdc })
		symbols.add("mul16", new SymbolInfo { type: SymbolType.opcode, opcode: 0xdd })
		symbols.add("mul8s", new SymbolInfo { type: SymbolType.opcode, opcode: 0xde })
		symbols.add("mul12s", new SymbolInfo { type: SymbolType.opcode, opcode: 0xdf })

		symbols.add("load", new SymbolInfo { type: SymbolType.opcode, opcode: 0xe0 })
		symbols.add("loadb", new SymbolInfo { type: SymbolType.opcode, opcode: 0xe1 })
		symbols.add("store", new SymbolInfo { type: SymbolType.opcode, opcode: 0xcc })
		symbols.add("storeb", new SymbolInfo { type: SymbolType.opcode, opcode: 0xcd })
		symbols.add("push", new SymbolInfo { type: SymbolType.opcode, opcode: 0xce })
		symbols.add("pop", new SymbolInfo { type: SymbolType.opcode, opcode: 0xcf })
		symbols.add("ret", new SymbolInfo { type: SymbolType.opcode, opcode: 0xea })
		symbols.add("add_offset", new SymbolInfo { type: SymbolType.opcode, opcode: 0xec })
	}
}

main() {
	::currentAllocator = Memory.newArenaAllocator(16 * 1024 * 1024)

	argErrors := new List<CommandLineArgsParserError>{}
	parser := new CommandLineArgsParser.from(Environment.getCommandLineArgs(), argErrors)
	args := parseArgs(parser, false)

	if argErrors.count > 0 {
		info := parser.getCommandLineInfo()
		for argErrors {
			Stderr.writeLine(CommandLineArgsParser.getErrorDesc(it, info))
		}
		exit(1)
	}

	comp := Parser.parse(args.source)
	out := Generator.generate(comp)

	if !File.tryWriteString(args.outputPath, out.code) {
		Stderr.writeLine(format("Could not write to output file: {}", args.outputPath))
		exit(1)		
	}

	Stderr.writeLine(format("{} bytes used ({}%)", out.ins.count, out.ins.count * 100.0 / 5120))
	Stderr.writeLine(format("Generated output: {}", args.outputPath))	
}
