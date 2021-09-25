//tab_size=4
// Copyright 2021 nickmqb
// SPDX-License-Identifier: Apache-2.0

IntVector2 {
	:delta_8 Array<IntVector2> #Mutable

	static_init_delta_8() {
		delta_8 = new Array<IntVector2>(8)
		delta_8[0] = IntVector2(1, 0)
		delta_8[1] = IntVector2(1, 1)
		delta_8[2] = IntVector2(0, 1)
		delta_8[3] = IntVector2(-1, 1)
		delta_8[4] = IntVector2(-1, 0)
		delta_8[5] = IntVector2(-1, -1)
		delta_8[6] = IntVector2(0, -1)
		delta_8[7] = IntVector2(1, -1)
	}
}

IntVector3 {
	:delta Array<IntVector3> #Mutable

	static_init_delta() {
		delta = new Array<IntVector3>(6)
		delta[0] = IntVector3(-1, 0, 0)
		delta[1] = IntVector3(1, 0, 0)
		delta[2] = IntVector3(0, 0, -1)
		delta[3] = IntVector3(0, 0, 1)
		delta[4] = IntVector3(0, -1, 0)
		delta[5] = IntVector3(0, 1, 0)
	}
}

Grid struct #RefType {
	size IntVector3
	sizeMask IntVector3
	cells Array<byte>
}

Grid2D<T> struct #RefType {
	offset IntVector2
	size IntVector2
	cells Array<T>

	create<T>(size IntVector2, offset IntVector2) {
		return Grid2D<T> {
			size: size,
			offset: offset,
			cells: new Array<T>(size.x * size.y)
		}
	}

	getIndex(g Grid2D<T>, x int, y int) {
		x -= g.offset.x
		y -= g.offset.y		
		return g.size.x * y + x
	}
}

// Note: dimensions must be power of 2
createGrid(x int, y int, z int) {
	return Grid {
		size: IntVector3(x, y, z),
		sizeMask: IntVector3(x - 1, y - 1, z - 1),
		cells: new Array<byte>(x * y * z),
	}
}

getCellIndex(g Grid, x int, y int, z int) {
	if x < 0 || x >= g.size.x || y < 0 || y >= g.size.y || z < 0 || z >= g.size.z {
		return -1
	}
	return x * g.size.y + y + g.size.y * g.size.x * z
}

getCellIndexWrappedXZ(g Grid, x int, y int, z int) {
	if y < 0 || y >= g.size.y {
		return -1
	}
	x &= g.sizeMask.x	
	z &= g.sizeMask.z
	return x * g.size.y + y + g.size.y * g.size.x * z
}

readGrid(bytes Array<byte>) {
	mapSize := 0
	if bytes.count == 8 * 1024 * 1024 {
		mapSize = 512
	} else if bytes.count == 2 * 1024 * 1024 {
		mapSize = 256
	} else if bytes.count == 512 * 1024 {
		mapSize = 128
	} else {
		Stderr.writeLine("Invalid map size")
		abandon()
	}
	grid := new createGrid(mapSize, 32, mapSize)
	for z := 0; z < mapSize {
		for x := 0; x < mapSize {
			for y := 0; y < 32 {
				ci := getCellIndexWrappedXZ(grid, x, y, z)
				localIndex := (x & 1) | ((z & 1) << 1) | (y << 2)
				index := localIndex | ((((x >> 1) & 0x7) | ((z & 0x7e) << 2) | ((x & 0xf0) << 5) | ((z & 0x80) << 6) | ((x & 0x100) << 6) | ((z & 0x100) << 7)) << 7)
				grid.cells[ci] = bytes[index]
			}
		}
	}
	return grid
}

writeGrid(g Grid, path string) {
	mapBytes := new Array<byte>(32 * g.size.x * g.size.z)
	mapBytesSim := new Array<byte>(32 * 1024)
	for z := 0; z < g.size.z {
		for x := 0; x < g.size.x {
			for y := 0; y < 32 {
				ci := getCellIndexWrappedXZ(g, x, y, z)
				localIndex := (x & 1) | ((z & 1) << 1) | (y << 2)
				index := localIndex | ((((x >> 1) & 0x7) | ((z & 0x7e) << 2) | ((x & 0xf0) << 5) | ((z & 0x80) << 6) | ((x & 0x100) << 6) | ((z & 0x100) << 7)) << 7)
				mapBytes[index] = g.cells[ci]
				simIndex := localIndex | (((x & 0x1e) >> 1) << 7) | (((z & 0x1e) >> 1) << 11)
			}
		}
	}

	writeBinaryFile(mapBytes, path)
}

writeGridSim(grid Grid, px int, pz int) {
	// Map
	mapSize := 512
	mapBytesSim := new Array<byte>(32 * 1024)

	// Sim map, based on current coords
	px = min(max(px, 0), mapSize - 31)
	pz = min(max(pz, 0), mapSize - 31)
	for z := 0; z < 32 {
		for x := 0; x < 32 {
			for y := 0; y < 32 {
				ci := getCellIndexWrappedXZ(grid, px + x, y, pz + z)
				localIndex := (x & 1) | ((z & 1) << 1) | (y << 2)
				simIndex := localIndex | (((x & 0x1e) >> 1) << 7) | (((z & 0x1e) >> 1) << 11)
				mapBytesSim[simIndex] = grid.cells[ci]
			}
		}
	}

	sb := new StringBuilder{}

	sb.write("MAP $262144 := [\n")
	writeArray(mapBytesSim, sb)
	sb.write("]\n\n")

	assert(File.tryWriteString("../hw/src/map_sim.w", sb.compactToString()))
}
