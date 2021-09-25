//tab_size=4
// Copyright 2021 nickmqb
// SPDX-License-Identifier: Apache-2.0

generateLightLookup(sb StringBuilder) {
	data := new Array<ushort>(256)

	map := new Array<float>(16)
	map[15] = 1
	map[14] = 1
	map[13] = .8
	map[12] = .7
	map[11] = .62
	map[10] = .55
	map[9] = .49
	map[8] = .42
	map[7] = .36
	map[6] = .30
	map[5] = .25
	map[4] = .20
	map[3] = .155
	map[2] = .115
	map[1] = .08 
	map[0] = .05

	for i := 0; i < 256 {
		color := (i / 16) / 15.0
		lightLevel := i % 16
		val := color * map[lightLevel]
		data[i] = cast(clampi(cast(val * 240.0 + 8, int), 0, 255), byte)
	}

	dither := getDitherLookup()
	for i := 0; i < dither.count {
		data[i] = cast(data[i] | (cast(dither[i], byte) << 8), ushort)
	}	

	// Darken
	for i := 0; i < 32 {
		side := i & 3
		mine := (i >> 2) & 3
		underwater := (i >> 4) & 1
		sideVal := side == 0 ? 0 : (side == 1 ? -1 : -3)
		mineVal := mine == 0 ? 0 : (mine == 1 ? -1 : -5)
		underwaterVal := underwater == 0 ? 0 : -9
		val := max(sideVal + mineVal + underwaterVal, -15)
		data[i + 32] = cast(data[i + 32] | (cast(val, byte) << 8), ushort)
	}

	// Water/light
	for comp := 0; comp < 3 {
		for type := 0; type < 4 {
			for i := 0; i < 16 {
				mixBlue := 0
				if type == 1 {
					mixBlue = 1
				} else if type == 2 {
					mixBlue = i / 2
				} else if type == 3 {
					mixBlue = i
				}
				val := 0
				if comp == 0 {
					val = clampi(12 + 12 * mixBlue / 15, 0, 124)
				} else if comp == 1 {
					val = clampi(16 + 48 * mixBlue / 15, 0, 124)
				} else {
					val = clampi(20 + 108 * mixBlue / 15, 0, 124)
				}
				index := 64 + comp * 64 + type * 16 + i
				data[index] = cast(data[index] | (cast(val, byte) << 8), ushort)
			}
		}
	}

	sb.write("LIGHT_LOOKUP $4096 := [\n")
	writeArray(data, sb)
	sb.write("]\n\n")
}

:ditherSize = 4

getDitherLookup() {
	table := new Array<int>(16)
	ditherFill(table, 0, 0, ditherSize, 0, 1)
	for i := 0; i < table.count {
		table[i] = clampi(table[i] - 8, -7, 7)
	}	
	//for x in table {
	//	Stdout.write(format("{} ", x))
	//}
	//Stdout.writeLine("")
	return table
}

ditherFill(table Array<int>, px int, py int, size int, first int, jump int) {
	if size == 1 {
		table[py * ditherSize + px] = cast(first, short)
		return
	}
	hsize := size / 2
	ditherFill(table, px, py, hsize, first, jump * 4)
	ditherFill(table, px + hsize, py + hsize, hsize, first + jump, jump * 4)
	ditherFill(table, px, py + hsize, hsize, first + jump * 2, jump * 4)
	ditherFill(table, px + hsize, py, hsize, first + jump * 3, jump * 4)
}
