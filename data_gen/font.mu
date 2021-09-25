//tab_size=4
// Copyright 2021 nickmqb
// SPDX-License-Identifier: Apache-2.0

generateFontData(sb StringBuilder) {
	img := new loadPng("font.png")

	data := new Array<byte>(512)

	for i := 0; i < 64 {
		for y := 0; y < 8 {
			val := 0
			for x := 0; x < 8 {
				isSet := img.getPixel((i % 16) * 8 + x, (i / 16) * 8 + y).r > 128
				val >>= 1
				val |= isSet ? 0x80 : 0
			}
			data[i * 8 + y] = cast(val, byte)
		}
	}

	sb.write("FONT_GLYPH_DATA $4096 := [\n")
	writeArray(data, sb)
	sb.write("]\n\n")
}
