//tab_size=4
// Copyright 2021 nickmqb
// SPDX-License-Identifier: Apache-2.0

Compilation struct #RefType {
	unit CodeUnit
	symbols Map<string, SymbolInfo>
	constUsages Map<int, ConstInfo>
}

SymbolInfo struct #RefType {
	type SymbolType
	node Node
	opcode int
}

SymbolType enum {
	reserved
	opcode
	decl
	label
}

Error struct {
	span IntRange
	text string
	
	at(span IntRange, text string) {
		assert(span.from <= span.to)
		return Error { span: span, text: text }
	}

	atIndex(index int, text string) {
		return Error { span: IntRange(index, index), text: text }
	}
}

Node tagged_pointer {
	CodeUnit
	Decl
	Block
	NumberExpr
	ComboStatement
	Token
}

CodeUnit struct #RefType {
	sf SourceFile
	contents List<Node>
	lines List<LineInfo>
}

Decl struct #RefType {
	name string
	allNames List<string>
	valueExpr NumberExpr
	isVar bool
	numReads int
	numWrites int
	localIndex int
}

ConstInfo struct #RefType {
	value int
	pos bool
	neg bool
	numReads int
	localIndex int
}

Block struct #RefType {
	contents List<Node>
}

ComboStatement struct #RefType {
	nodes List<Node>
}

NumberExpr struct #RefType {
	token Token
	value int
}

Token struct #RefType {
	value string
	span IntRange
	type TokenType
	line int
}

TokenType enum {
	identifier
	operator
	openBrace
	closeBrace
	number
	end
}

LineInfo struct {
	span IntRange
	insSpan IntRange
	relevant bool
}

ParseState struct #RefType {
	comp Compilation
	text string
	index int
	token Token
	line int
	lineStart int
	lineRelevant bool
	lines List<LineInfo>
	varIndex int
	unresolvedLabels List<Token>
	labelSet Set<string>
}

Parser {
	parse(sf SourceFile) {
		s := new ParseState {
			text: sf.text,
			token: new Token{},
			lines: new List<LineInfo>{},
			unresolvedLabels: new List<Token>{},
			labelSet: new Set.create<string>()
		}
		
		unit := new CodeUnit { sf: sf, contents: new List<Node>{}, lines: s.lines }
		
		s.comp = new Compilation { 
			unit: unit,
			symbols: new Map.create<string, SymbolInfo>(),
			constUsages: new Map.create<int, ConstInfo>(),
		}

		OpcodeInfo.addDefaultSymbols(s.comp.symbols)

		readToken(s)
		while s.token.type != TokenType.end {
			topLevelNode(s, unit)
		}

		for lb in s.unresolvedLabels {
			if !s.labelSet.contains(lb.value) {
				errorAtRange(s, lb.span, "Undefined symbol")
			}
		}

		return s.comp
	}

	topLevelNode(s ParseState, unit CodeUnit) {
		if s.token.type == TokenType.identifier {
			unit.contents.add(decl(s))
		} else if s.token.type == TokenType.openBrace {
			unit.contents.add(block(s))
		} else if s.token.value == "@" {
			unit.contents.add(label(s))
		} else {
			error(s, "Expected: decl")
		}
	}

	decl(s ParseState) {
		if s.comp.symbols.containsKey(s.token.value) {
			error(s, "A symbol with the same name has already been defined")
		}

		decl := new Decl { name: s.token.value, allNames: new List<string>{}, localIndex: -1 }
		si := new SymbolInfo { type: SymbolType.decl, node: decl }
		s.comp.symbols.add(decl.name, si)
		decl.allNames.add(decl.name)

		readToken(s)

		while s.token.value == "," {
			readToken(s)
			if s.token.type != TokenType.identifier {
				error(s, "Expected: identifier")
			}
			if s.comp.symbols.containsKey(s.token.value) {
				error(s, "A symbol with the same name has already been defined")
			}
			s.comp.symbols.add(s.token.value, si)
			decl.allNames.add(s.token.value)
			readToken(s)
		}

		if s.token.value == "var" {
			decl.isVar = true
			readToken(s)
		}

		if s.token.value == ":=" {
			readToken(s)
			decl.valueExpr = numberExpr(s)
		} else if s.varIndex == -1 {
			error(s, "Expected: var or :=")
		}

		return decl
	}

	block(s ParseState) Block {
		bl := new Block { contents: new List<Node>{} }
		readToken(s)
		while s.token.type != TokenType.closeBrace {
			if s.token.type == TokenType.openBrace {
				bl.contents.add(block(s))
			} else if s.token.type == TokenType.identifier {				
				name := s.token.value
				//Stdout.writeLine(format("name: {}", name))
				bl.contents.add(statement(s))
			} else if s.token.type == TokenType.operator {
				if s.token.value == "@" {
					bl.contents.add(label(s))
				} else if s.token.value == "<<" || s.token.value == ">>s" || s.token.value == ">>u" {
					bl.contents.add(shift(s))
				} else {
					bl.contents.add(operatorStatement(s))
				}
			} else if s.token.type == TokenType.number {
				expr := numberExpr(s)
				recordConstUsage(s, expr.value)
				bl.contents.add(expr)
			} else if s.token.type == TokenType.end {
				error(s, "Expected: }")
			}
		}
		readToken(s)
		return bl
	}

	recordConstUsage(s ParseState, val int) {
		neg := val < 0
		val &= 0xffff
		info := s.comp.constUsages.getOrDefault(val)
		if info == null {
			info = new ConstInfo { value: val, localIndex: -1 }
			s.comp.constUsages.add(val, info)
		}
		info.numReads += 1
		info.pos ||= !neg
		info.neg ||= neg
	}

	statement(s ParseState) Node {
		sym := s.comp.symbols.getOrDefault(s.token.value)
		if sym == null {
			error(s, "Undefined symbol")
		}
		if s.token.value == "if" {
			return if_(s)
		} else if s.token.value == "out" || s.token.value == "in" {
			return in_out(s)
		} else if s.token.value == "goto" || s.token.value == "call" {
			st := new ComboStatement { nodes: new List<Node>{} }
			gotoTail(s, st)
			return st
		} else if s.token.value == "ret" {
			// OK
		} else if sym.type == SymbolType.reserved {
			error(s, "Invalid use of reserved symbol")
		} else if sym.type == SymbolType.label {
			error(s, "Expected: call or goto")
		} else if sym.type == SymbolType.decl {
			decl := sym.node.as(Decl)
			if decl.isVar {
				decl.numReads += 1
			} else {
				recordConstUsage(s, decl.valueExpr.value)
			}
		}

		result := s.token
		readToken(s)
		return result
	}

	if_(s ParseState) {
		st := new ComboStatement { nodes: new List<Node>{} }
		st.nodes.add(s.token)
		readToken(s)
		if s.token.value == "z" || s.token.value == "nz" {
			// OK
		} else {
			error(s, "Expected: z or nz")
		}
		st.nodes.add(s.token)
		readToken(s)
		if s.token.type == TokenType.openBrace {
			st.nodes.add(block(s))
			if s.token.value == "else" {
				st.nodes.add(s.token)
				readToken(s)
				if s.token.type == TokenType.openBrace {
					st.nodes.add(block(s))
				} else {
					error(s, "Expected: {")
				}
			}
		} else if s.token.value == "goto" {
			gotoTail(s, st)
		} else {
			error(s, "Expected: goto or {")				
		}
		return st
	}

	in_out(s ParseState) {
		st := new ComboStatement { nodes: new List<Node>{} }
		st.nodes.add(s.token)
		to := s.token.span.to			
		readToken(s)
		if s.token.span.from != to {
			error(s, "Token must not have leading whitespace")
		}
		if s.token.value != ":" {
			error(s, "Expected: :")
		}
		st.nodes.add(s.token)
		to = s.token.span.to
		readToken(s)
		if s.token.span.from != to {
			error(s, "Token must not have leading whitespace")
		}
		port := numberExpr(s)
		if !(0 <= port.value && port.value < 256) {
			error(s, "Invalid port")
		}
		st.nodes.add(port)
		return st
	}

	shift(s ParseState) {
		st := new ComboStatement { nodes: new List<Node>{} }
		first := s.token
		st.nodes.add(s.token)
		to := s.token.span.to			
		readToken(s)
		if s.token.span.from != to {
			error(s, "Token must not have leading whitespace")
		}
		if s.token.value != ":" {
			error(s, "Expected: :")
		}
		st.nodes.add(s.token)
		to = s.token.span.to
		readToken(s)
		if s.token.span.from != to {
			error(s, "Token must not have leading whitespace")
		}
		amount := numberExpr(s)
		maxAmount := first.value == ">>s" ? 12 : 15
		if !(0 < amount.value && amount.value <= maxAmount) {
			error(s, "Invalid shift amount")
		}
		if first.value == "<<" {
			recordConstUsage(s, 1 << amount.value)
		} else if first.value == ">>s" {
			recordConstUsage(s, 1 << (12 - amount.value))
		} else if first.value == ">>u" {
			recordConstUsage(s, 1 << (16 - amount.value))
		} else {
			abandon()
		}
		st.nodes.add(amount)
		return st
	}

	gotoTail(s ParseState, st ComboStatement) {
		st.nodes.add(s.token)
		readToken(s)
		targetSym := s.comp.symbols.getOrDefault(s.token.value)
		if s.token.type != TokenType.identifier {
			error(s, "Expected: label")
		} else if s.token.value.startsWith("@") {
			error(s, "Expected: label (must not use @ prefix)")
		} else if targetSym == null {
			s.unresolvedLabels.add(s.token)
		} else if s.token.value == "begin" || s.token.value == "outer_begin" {
			// OK
		} else if targetSym.type == SymbolType.label {
			// OK
		} else {
			error(s, "Expected: label")
		}
		st.nodes.add(s.token)
		readToken(s)
	}

	operatorStatement(s ParseState) Node {
		if s.token.value == "=>" {
			st := new ComboStatement { nodes: new List<Node>{} }
			st.nodes.add(s.token)
			to := s.token.span.to
			readToken(s)
			if s.token.span.from != to {
				error(s, "Token must not have leading whitespace")
			}
			sym := s.comp.symbols.getOrDefault(s.token.value)
			if s.token.type != TokenType.identifier {
				error(s, "Expected: var")
			} else if sym == null {
				error(s, "Undefined symbol")
			} else if sym.type == SymbolType.decl && sym.node.as(Decl).isVar {
				// OK
			} else {
				error(s, "Expected: var")
			}
			sym.node.as(Decl).numWrites += 1
			st.nodes.add(s.token)
			readToken(s)
			return st
		}
		if s.comp.symbols.containsKey(s.token.value) {
			// OK
		} else {
			error(s, "Invalid operator")
		}
		result := s.token
		readToken(s)
		return result
	}

	label(s ParseState) {
		st := new ComboStatement { nodes: new List<Node>{} }
		st.nodes.add(s.token)
		to := s.token.span.to
		readToken(s)
		if s.token.span.from != to {
			error(s, "Token must not have leading whitespace")
		}
		if s.token.type != TokenType.identifier {
			error(s, "Expected: label")
		}
		if s.comp.symbols.tryAdd(s.token.value, new SymbolInfo { type: SymbolType.label, node: s.token }) {
			// OK
		} else {
			error(s, "A symbol with the same name has already been defined")
		}
		st.nodes.add(s.token)
		s.labelSet.add(s.token.value)
		readToken(s)
		return st
	}

	numberExpr(s ParseState) {
		if s.token.type != TokenType.number {
			error(s, "Expected: number")
		}
		str := s.token.value
		pr := str.startsWith("0x") ? long.tryParseHex(str.slice(2, str.length)) : long.tryParse(str)
		if !pr.hasValue {
			error(s, "Expected: number")
		}
		val := pr.value
		if val < short.minValue || val > ushort.maxValue {
			error(s, "Value does not fit into 16 bits")
		}
		token := s.token
		readToken(s)
		return new NumberExpr { token: token, value: cast(val, int) }		
	}

	readToken(s ParseState) {
		ch := s.text[s.index]

		while true {
			while ch == ' ' || ch == '\t' || ch == '\r' {
				s.index += 1
				ch = s.text[s.index]
			}
			if ch == '\n' {
				s.lines.add(LineInfo { span: IntRange(s.lineStart, s.index), relevant: s.lineRelevant })
				s.index += 1
				s.lineStart = s.index
				s.lineRelevant = false
				s.line += 1
				ch = s.text[s.index]
			} else if ch == '/' && s.text[s.index + 1] == '/' {
				s.index += 2                
				ch = s.text[s.index]
				while ch != '\n' && ch != '\0' {
					s.index += 1
					ch = s.text[s.index]
				}
			} else {
				break
			}
		}

		if ch == '\0' {
			finishToken(s, TokenType.end, s.index)
			return
		}

		from := s.index
		if isIdentifierFirstChar(ch) {
			s.index += 1
			ch = s.text[s.index]
			while isIdentifierChar(ch) {
				s.index += 1
				ch = s.text[s.index]
			}
			finishToken(s, TokenType.identifier, from)
			return
		}

		if ch == '{' {
			s.lineRelevant = true
			s.index += 1
			finishToken(s, TokenType.openBrace, from)
			return
		}
		if ch == '}' {
			s.lineRelevant = true
			s.index += 1
			finishToken(s, TokenType.closeBrace, from)
			return
		}

		if isDigit(ch) || (ch == '-' && isDigit(s.text[s.index + 1])) {
			s.index += 1
			ch = s.text[s.index]
			while isIdentifierChar(ch) {
				s.index += 1
				ch = s.text[s.index]
			}
			finishToken(s, TokenType.number, from)
			return
		}

		if isOperatorFirstChar(ch) {
			s.lineRelevant ||= ch == '@'
			s.index += 1
			ch = s.text[s.index]
			while isOperatorChar(ch) {
				s.index += 1
				ch = s.text[s.index]
			}
			if ch == 's' || ch == 'u' {
				nextCh := s.text[s.index + 1]
				if isWhitespace(nextCh) || nextCh == '\0' || nextCh == ':' {
					s.index += 1
				}
			}
			finishToken(s, TokenType.operator, from)
			return
		}
		
		errorAtRange(s, IntRange(from, from + 1), format("Invalid token (ch: {})", transmute(ch, int)))
	}

	finishToken(s ParseState, type TokenType, from int) {
		//Stdout.writeLine(format("%{}%", s.text.slice(from, s.index)))
		s.token = new Token { type: type, value: s.text.slice(from, s.index), span: IntRange(from, s.index), line: s.line }
	}

	error(s ParseState, text string) {
		errorAtRange(s, s.token.span, text)
	}

	errorAtRange(s ParseState, span IntRange, text string) {
		Stdout.writeLine(ErrorHelper.getErrorDesc(s.comp.unit.sf.path, s.comp.unit.sf.text, span, text))
		exit(1)
	}

	isDigit(ch char) {
		return '0' <= ch && ch <= '9'
	}

	isWhitespace(ch char) {
		return ch == ' ' || ch == '\t' || ch == '\n' || ch == '\r'
	}

	isIdentifierFirstChar(ch char) {
		return (ch >= 'A' && ch <= 'Z') || (ch >= 'a' && ch <= 'z') || ch == '_'
	}

	isIdentifierChar(ch char) {
		return (ch >= 'A' && ch <= 'Z') || (ch >= 'a' && ch <= 'z') || (ch >= '0' && ch <= '9') || ch == '_'
	}

	isOperatorFirstChar(ch char) {
		return isOperatorChar(ch) || ch == ':'
	}

	isOperatorChar(ch char) {
		return ch == '=' || ch == '^' || ch == '+' || ch == '-' || ch == '&' || ch == '|' || ch == '<' || ch == '>' || ch == '~' || ch == '!' || ch == '.' || ch == '@' || ch == ','
	}
}
