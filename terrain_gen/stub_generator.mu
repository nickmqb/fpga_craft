//tab_size=4
// Copyright 2021 nickmqb
// SPDX-License-Identifier: Apache-2.0

StubGenerator {
	generate(g Grid, rs *uint, block byte) {
		terrainA := new GradientNoiseMap2D(rs)
		terrainB := new GradientNoiseMap2D(rs)

		for x := 0; x < g.size.x {
			for z := 0; z < g.size.z {
				g.cells[getCellIndexWrappedXZ(g, x, 0, z)] = Blocks.bedrock
				
				h := 10.0
				h += sampleNoise(terrainA, x, z, g.size.x, 8) * 2
				h += sampleNoise(terrainB, x, z, g.size.x, 16) * 1

				hi := cast(h, int)
				
				for y := 1; y < hi {
					g.cells[getCellIndexWrappedXZ(g, x, y, z)] = block
				}				
			}
		}
	}
}
