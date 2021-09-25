//tab_size=4
// Copyright 2021 nickmqb
// SPDX-License-Identifier: Apache-2.0

GenerateState struct #RefType {
	comp Compilation
	out StringBuilder
	ins List<byte>
	labelAddr Map<string, int>
	toPatch Map<string, List<UnresolvedGoto>>
	jumpTargets Map<int, JumpTarget>
	jumpTargetsList List<JumpTarget>
	lastStackOp StackOpInfo
	blockFirstAddr int
	outerBlockFirstAddr int
	numLocals int
	maxLocalIndex int
}

GenerateResult struct {
	code string
	ins List<byte>
}

UnresolvedGoto struct {
	addr int
	type GotoType
	refToken Token
}

GotoType enum {
	goto
	bz
	bnz
	call
}

JumpTarget struct #RefType {
	addr int
	name string
	tableIndex int
}

StackOpInfo struct {
	opcode int
	index int
}

Generator {
	generate(comp Compilation) {
		s := new GenerateState {
			comp: comp,
			out: new StringBuilder{},
			ins: new List<byte>{},
			labelAddr: new Map.create<string, int>(),
			toPatch: new Map.create<string, List<UnresolvedGoto>>(),
			jumpTargets: new Map.create<int, JumpTarget>(),
			jumpTargetsList: new List<JumpTarget>{},
		}
		u := comp.unit

		for ln, i in u.lines {
			u.lines[i].insSpan = IntRange(int.maxValue, int.minValue)
		}

		locals := LocalsAllocator.allocate(s)

		unit(s, u)

		assert(s.toPatch.count == 0)

		s.out.write("LOCALS $4096 := zx [\n")

		{
			i := 0
			while i < s.maxLocalIndex {
				lc := locals[i]
				if lc.reg != null {
					initReg(s, lc.reg)
					i += 1
				} else if lc.const != null {
					initConst(s, lc.const)
					i += 1
				} else {
					first := i
					while i < s.maxLocalIndex && locals[i].reg == null && locals[i].const == null {
						i += 1
					}
					writeZeroes(s, (i - first) * 4)
				}
			}
			if s.maxLocalIndex == 0 {
				writeZeroes(s, 4)
			}
		}

		s.out.write("]\n\n")

		Stdout.writeLine(format("Total number of locals: {}", s.numLocals))

		s.out.write(format("// {} bytes ({}%)\n\n", s.ins.count, s.ins.count * 100.0 / 5120))

		s.out.write(format("CODE ${} := [\n", s.ins.count * 8))

		maxInsPerLine := 0
		for ln in u.lines {
			if ln.insSpan.to > ln.insSpan.from {
				maxInsPerLine = max(maxInsPerLine, ln.insSpan.to - ln.insSpan.from)
			}
		}

		sep := false
		lastAddr := 0
		for ln in u.lines {
			containsIns := ln.insSpan.to > ln.insSpan.from
			if containsIns || ln.relevant {
				if sep {
					s.out.write("\t\n")
					sep = false
				}
				if containsIns {
					assert(lastAddr == ln.insSpan.from)
					writeLine(s, ref s.ins.slice(ln.insSpan.from, ln.insSpan.to), maxInsPerLine, ln.insSpan.from, u.sf.text.slice(ln.span.from, ln.span.to))
					lastAddr = ln.insSpan.to
				} else {
					writeLine(s, ref s.ins.slice(0, 0), maxInsPerLine, lastAddr, u.sf.text.slice(ln.span.from, ln.span.to))
				}
			} else {
				sep = lastAddr > 0
			}
		}

		s.out.write("]\n\n")

		s.out.write("JUMP_TABLE $4096 := zx [\n")

		for t, i in s.jumpTargetsList {
			assert(t.tableIndex == i)
			initTarget(s, t)
		}
		if s.jumpTargetsList.count == 0 {
			writeZeroes(s, 4)
		}

		s.out.write("]\n")

		return GenerateResult { code: s.out.compactToString(), ins: s.ins }
	}

	writeZeroes(s GenerateState, n int) {
		while n > 0 {
			s.out.write("\t")
			s.out.write(string.repeatChar('0', min(n, 64)))
			s.out.write("\n")
			n -= 64
		}
	}

	unit(s GenerateState, unit CodeUnit) {
		for it in unit.contents {
			match it {
				Decl: {}
				Block: block(s, it)
				ComboStatement: {
					assert(it.nodes[0].as(Token).value == "@")
					label(s, it)
				}
			}
		}
	}

	initReg(s GenerateState, decl Decl) {
		names := string.join(", ", ref decl.allNames.slice(0, decl.allNames.count))

		s.out.write(format("\t{} // (0x{}, count = {}, {}", Util.format16le(decl.valueExpr != null ? decl.valueExpr.value : 0), Util.toHex(decl.localIndex), decl.numReads + decl.numWrites, names))
		if decl.valueExpr != null && decl.valueExpr.value != 0 {
			s.out.write(format(", value = {}", decl.valueExpr.value))
		}
		s.out.write(")\n")
	}

	initConst(s GenerateState, ci ConstInfo) {
		s.out.write("\t")
		s.out.write(format("{} // (0x{}, count = {}, hex_value = 0x{}", Util.format16le(ci.value), Util.toHex(ci.localIndex), ci.numReads, Util.toHex(ci.value)))
		if ci.pos {
			s.out.write(format(", value = {}", ci.value))
		}
		if ci.neg {
			s.out.write(format(", value = {}", ci.value - 0x10000))
		}
		s.out.write(")\n")
	}

	initTarget(s GenerateState, target JumpTarget) {
		s.out.write("\t")
		s.out.write(format("{} // (0x{}", Util.format16le(target.addr), Util.toHex(target.tableIndex)))
		if target.name != "" {
			s.out.write(format(", @{}", target.name))
		}
		s.out.write(")\n")
	}

	block(s GenerateState, bl Block) {
		prevOuter := s.outerBlockFirstAddr		
		s.outerBlockFirstAddr = s.blockFirstAddr
		s.blockFirstAddr = s.ins.count
		begin := s.ins.count
		for it in bl.contents {
			match it {
				Token: token(s, it)
				NumberExpr: numberExpr(s, it)
				ComboStatement: combo(s, it)
				Block: block(s, it)
			}
		}
		s.blockFirstAddr = s.outerBlockFirstAddr
		s.outerBlockFirstAddr = prevOuter
	}

	token(s GenerateState, token Token) {
		addr := s.ins.count
		assert(token.type == TokenType.identifier || token.type == TokenType.operator)

		sym := s.comp.symbols.get(token.value)
		if sym.type == SymbolType.opcode {
			op(s, sym)
		} else if sym.type == SymbolType.decl {
			get(s, sym.node.as(Decl).localIndex)
		} else if sym.type == SymbolType.reserved {
			if token.value == "ret" {
				ret(s)
			} else {
				abandon()
			}
		} else {
			abandon()
		}
		updateLineInfo(s, token, addr, s.ins.count)
	}

	op(s GenerateState, sym SymbolInfo) {
		// Must have at least one cycle between certain stack instructions
		if sym.opcode == OpcodeInfo.pop || sym.opcode == OpcodeInfo.ret {
			if s.lastStackOp.index == s.ins.count - 1 {
				if s.lastStackOp.opcode == OpcodeInfo.push {
					s.ins[s.lastStackOp.index] = cast(OpcodeInfo.push_slow, byte)
				} else if s.lastStackOp.opcode == OpcodeInfo.pop {
					s.ins[s.lastStackOp.index] = cast(OpcodeInfo.pop_slow, byte)
				}
			}
		}
		s.lastStackOp = StackOpInfo { opcode: sym.opcode, index: s.ins.count }
		emit(s, sym.opcode)
	}

	ret(s GenerateState) {
		op(s, s.comp.symbols.get("ret"))
	}

	numberExpr(s GenerateState, num NumberExpr) {
		begin := s.ins.count
		const(s, num.value)
		updateLineInfo(s, num.token, begin, s.ins.count)
	}

	const(s GenerateState, value int) {
		value &= 0xffff
		info := s.comp.constUsages.get(value)
		get(s, info.localIndex)
	}

	combo(s GenerateState, st ComboStatement) {
		begin := s.ins.count
		first := st.nodes[0].as(Token)
		if first.value == "if" {
			if_(s, st)
			return
		} else if first.value == "in" || first.value == "out" {
			in_out(s, st)
		} else if first.value == "<<" || first.value == ">>s" || first.value == ">>u" {
			shift(s, st)
		} else if first.value == "goto" {
			goto(s, st)
		} else if first.value == "call" {
			call(s, st)
		} else if first.value == "=>" {
			put(s, st)
		} else if first.value == "@" {
			label(s, st)
			return
		} else {
			abandon()
		}		
		updateLineInfo(s, first, begin, s.ins.count)
	}

	if_(s GenerateState, st ComboStatement) {
		ifStart := s.ins.count
		ifKeyword := st.nodes[0].as(Token)
		flag := st.nodes[1].as(Token)
		assert(flag.value == "z" || flag.value == "nz")
		isNz := flag.value == "nz"
		action := st.nodes[2]
		if action.is(Block) {			
			emit(s, 0)
			emit(s, 0)
			updateLineInfo(s, ifKeyword, ifStart, s.ins.count)
			block(s, action.as(Block))
			type := isNz ? GotoType.bz : GotoType.bnz // Invert condition
			if st.nodes.count > 3 {
				elseKeyword := st.nodes[3].as(Token)
				elseStart := s.ins.count
				emit(s, 0)
				emit(s, 0)
				patch(s, ifStart, s.ins.count, type, "", ifKeyword)
				updateLineInfo(s, elseKeyword, elseStart, s.ins.count)
				block(s, st.nodes[4].as(Block))
				patch(s, elseStart, s.ins.count, GotoType.goto, "", elseKeyword)
			} else {
				patch(s, ifStart, s.ins.count, type, "", ifKeyword)
			}
		} else if action.is(Token) {
			assert(action.as(Token).value == "goto")
			gotoLabel(s, st.nodes[3].as(Token).value, isNz ? GotoType.bnz : GotoType.bz, ifKeyword)
			updateLineInfo(s, ifKeyword, ifStart, s.ins.count)
		}
	}

	in_out(s GenerateState, st ComboStatement) {
		first := st.nodes[0].as(Token)
		port := st.nodes[2].as(NumberExpr)		
		if first.value == "in" {
			emit(s, OpcodeInfo.in_)
		} else if first.value == "out" {
			emit(s, OpcodeInfo.out)
		} else {
			abandon()
		}
		emit(s, port.value)
	}

	shift(s GenerateState, st ComboStatement) {
		first := st.nodes[0].as(Token)
		amount := st.nodes[2].as(NumberExpr)		
		if first.value == "<<" {
			const(s, 1 << amount.value)
			emit(s, OpcodeInfo.mul)
		} else if first.value == ">>s" {
			const(s, 1 << (12 - amount.value))
			emit(s, OpcodeInfo.mul12s)
		} else if first.value == ">>u" {
			const(s, 1 << (16 - amount.value))
			emit(s, OpcodeInfo.mul16)
		} else {
			abandon()
		}
	}

	goto(s GenerateState, st ComboStatement) {
		keyword := st.nodes[0].as(Token)
		gotoLabel(s, st.nodes[1].as(Token).value, GotoType.goto, keyword)
	}

	call(s GenerateState, st ComboStatement) {
		keyword := st.nodes[0].as(Token)
		gotoLabel(s, st.nodes[1].as(Token).value, GotoType.call, keyword)
	}

	label(s GenerateState, st ComboStatement) {
		addr := s.ins.count
		name := st.nodes[1].as(Token)
		s.labelAddr.add(name.value, addr)
		tp := s.toPatch.getOrDefault(name.value)
		if tp != null {
			for ug in tp {
				patch(s, ug.addr, addr, ug.type, name.value, ug.refToken)
			}
			s.toPatch.remove(name.value)
		}		
		updateLineInfo(s, st.nodes[0].as(Token), addr, s.ins.count)
	}

	gotoLabel(s GenerateState, target string, type GotoType, refToken Token) {
		addr := s.ins.count
		targetAddr := target == "begin" ? Maybe.from(s.blockFirstAddr) : (target == "outer_begin" ? Maybe.from(s.outerBlockFirstAddr) : s.labelAddr.maybeGet(target))
		emit(s, 0)
		emit(s, 0)
		if targetAddr.hasValue {
			patch(s, addr, targetAddr.value, type, (target != "begin" && target != "outer_begin") ? target : "", refToken)
		} else {
			tp := s.toPatch.getOrDefault(target)
			if tp == null {
				tp = new List<UnresolvedGoto>{}
				s.toPatch.add(target, tp)				
			}
			tp.add(UnresolvedGoto { addr: addr, type: type, refToken: refToken })
		}
	}

	patch(s GenerateState, addr int, targetAddr int, type GotoType, targetName string, refToken Token) {
		rel := targetAddr - (addr + 2)
		if type == GotoType.goto {
			if -(0x400) <= rel && rel < 0x400 {
				rel = rel >= 0 ? rel : (rel + 0x800)
				assert(0 <= rel && rel < 0x800)
				s.ins[addr] = checked_cast(OpcodeInfo.goto | (rel >> 8), byte)
				s.ins[addr + 1] = checked_cast(rel & 0xff, byte)
			} else {
				jump(s, addr, targetAddr, OpcodeInfo.jump, targetName)
			}
		} else if type == GotoType.bz || type == GotoType.bnz {
			nzMask := type == GotoType.bnz ? 0x4 : 0
			if -(0x200) <= rel && rel < 0x200 {
				rel = rel >= 0 ? rel : (rel + 0x400)
				assert(0 <= rel && rel < 0x400)
				s.ins[addr] = checked_cast(OpcodeInfo.bzbnz | nzMask | (rel >> 8), byte)
				s.ins[addr + 1] = checked_cast(rel & 0xff, byte)
			} else {
				errorAtRange(s.comp, refToken.span, "Conditional goto target address is too far away")
			}
		} else if type == GotoType.call {
			jump(s, addr, targetAddr, OpcodeInfo.call, targetName)
		} else {
			abandon()
		}
	}

	jump(s GenerateState, addr int, targetAddr int, opcode int, targetName string) {
		target := s.jumpTargets.getOrDefault(targetAddr)
		if target == null {
			if s.jumpTargetsList.count >= 192 {
				error(s.comp, format("Too many jump targets ({})", s.jumpTargetsList.count))
			}
			target = new JumpTarget { addr: targetAddr, name: targetName, tableIndex: s.jumpTargetsList.count }
			s.jumpTargets.add(targetAddr, target)
			s.jumpTargetsList.add(target)
		}
		s.ins[addr] = checked_cast(opcode, byte)
		s.ins[addr + 1] = checked_cast(target.tableIndex & 0xff, byte)
	}

	get(s GenerateState, localIndex int) {
		if localIndex < 128 {
			emit(s, localIndex)
		} else {
			emit(s, OpcodeInfo.get_ex)
			emit(s, localIndex)
		}
	}

	put(s GenerateState, st ComboStatement) {
		id := st.nodes[1].as(Token)
		sym := s.comp.symbols.get(id.value)
		assert(sym.type == SymbolType.decl)
		decl := sym.node.as(Decl)
		localIndex := decl.localIndex
		if localIndex < 64 {
			emit(s, 0x80 | localIndex)
		} else {
			emit(s, OpcodeInfo.put_ex)
			emit(s, localIndex)
		}
	}

	emit(s GenerateState, val int) {
		s.ins.add(checked_cast(val, byte))
	}

	updateLineInfo(s GenerateState, token Token, fromAddr int, toAddr int) {
		sp := ref s.comp.unit.lines[token.line].insSpan
		sp.from = min(sp.from, fromAddr)
		sp.to = max(sp.to, toAddr)
	}

	writeLine(s GenerateState, bytes Array<byte>, padBytes int, addr int, lineText string) {
		s.out.write("\t")
		for b in bytes {
			Util.writeByteHexTo(b, s.out)
		}
		for i := bytes.count; i < padBytes {
			s.out.write("  ")
		}
		s.out.write("    // ")
		s.out.write(Util.format16(addr))
		s.out.write("  ")
		s.out.write(lineText.replace("\t", "    "))
		s.out.write("\n")
	}

	errorAtRange(comp Compilation, span IntRange, text string) {
		Stderr.writeLine(ErrorHelper.getErrorDesc(comp.unit.sf.path, comp.unit.sf.text, span, text))
		exit(1)
	}

	error(comp Compilation, text string) {
		Stderr.writeLine(text)
		exit(1)
	}
}

Local struct {
	reg Decl
	const ConstInfo
	numUsages int
}

LocalsAllocator {
	localByNumUsagesDesc(a Local, b Local) {
		return int.compare(b.numUsages, a.numUsages)
	}

	allocate(s GenerateState) {	
		comp := s.comp

		locals := new List<Local>{}

		for e in comp.symbols {
			sym := e.value
			if sym.type == SymbolType.decl {
				decl := sym.node.as(Decl)				
				if decl.isVar {
					numUsages := decl.numReads + decl.numWrites
					if numUsages > 0 {
						locals.add(Local { reg: decl, numUsages: numUsages })
					}
				}
			}
		}
		for e in comp.constUsages {
			locals.add(Local { const: e.value, numUsages: e.value.numReads })
		}

		if locals.count >= 256 {
			Generator.error(comp, format("Too many locals ({})", locals.count))
		}

		locals.stableSort(localByNumUsagesDesc)
		s.numLocals = locals.count

		slots := new Array<Local>(256)

		a := 0
		b := 64
		c := 128

		for lc in locals {
			slot := 0
			if lc.reg != null && a < 64 {
				slot = a
				a += 1
			} else if b < 128 {
				slot = b
				b += 1
			} else {
				slot = c
				c += 1
			}
			if lc.reg != null {			
				lc.reg.localIndex = slot
			} else {
				lc.const.localIndex = slot
			}
			slots[slot] = lc
		}

		s.maxLocalIndex = c > 128 ? c : (b > 64 ? b : a)

		for e in comp.symbols {
			sym := e.value
			if sym.type == SymbolType.decl {
				decl := sym.node.as(Decl)				
				if !decl.isVar {
					val := decl.valueExpr.value & 0xffff
					info := comp.constUsages.getOrDefault(val)
					if info != null {
						decl.localIndex = info.localIndex
					}
				}
			}
		}

		return slots
	}
}
