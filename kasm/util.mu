//tab_size=4
// Copyright 2021 nickmqb
// SPDX-License-Identifier: Apache-2.0

Util {
	writeByteHexTo(b byte, sb StringBuilder) {
		if b < 16 {
			sb.write("0")
		}
		ulong.writeHexTo(b, sb)
	}

	format8(n int) {
		assert(-(0x80) <= n && n < 0x100)
		n &= 0xff
		sb := StringBuilder{}
		writeByteHexTo(cast(n, byte), ref sb)
		return sb.compactToString()
	}

	format16(n int) {
		assert(-(0x8000) <= n && n < 0x10000)
		n &= 0xffff
		str := toHex(n)
		assert(str.length <= 4)
		return leftpad(str, 4, '0')
	}

	format16le(n int) {
		assert(-(0x8000) <= n && n < 0x10000)
		n &= 0xffff
		sb := StringBuilder{}
		writeByteHexTo(cast(n & 0xff, byte), ref sb)
		writeByteHexTo(cast(n >> 8, byte), ref sb)
		return sb.compactToString()
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
