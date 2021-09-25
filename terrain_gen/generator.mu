//tab_size=4
// Copyright 2021 nickmqb
// SPDX-License-Identifier: Apache-2.0

generateOverworld(rs uint) {
	grid := new createGrid(512, 32, 512)
	Generator.generate(grid, ref rs)
	return grid
}

generateDimStub(rs uint, size int) {
	grid := new createGrid(size, 32, size)
	StubGenerator.generate(grid, ref rs, Blocks.sand)
	return grid
}

to01(t float) {
	return t * .5 + .5
}

blockIsLog(b byte) {
	if Blocks.oak_log <= b && b <= Blocks.oak_log + 5 {
		return true
	}
	if Blocks.birch_log <= b && b <= Blocks.birch_log + 5 {
		return true
	}
	if Blocks.spruce_log <= b && b <= Blocks.spruce_log + 5 {
		return true
	}
	return false
}

logAcross(b byte) {
	return cast(b + 2, byte)
}

logVertical(b byte) {
	return cast(b + 4, byte)
}

logBark(b byte) {
	return cast(b + 5, byte)
}

rotatedLog(b byte, d int) {
	return (d & 1) == 1 ? logAcross(b) : b
}

rotatedBlock(b byte, d int) {
	return cast(b + (d & 3) * 2, byte)
}

vectorToDir(dx int, dz int) {
	if absi(dx) > absi(dz) {
		return dx < 0 ? 3 : 1
	} else {
		return dz < 0 ? 0 : 2
	}
}

vectorToDirMask(dx int, dz int) {
	return (1 << vectorToDir(dx, dz)) | (1 << (vectorToDir(-dz, dx) - 1))
}

get2DIndex(g Grid, x int, z int) {
	x &= g.sizeMask.x	
	z &= g.sizeMask.z
	return z * g.size.x + x
}

Biomes {
	:desert = 0
	:plains = 1
	:forest = 2
	:icePlains = 3
	:taiga = 4

	:numBiomes = 5

	isHot(b int) {
		return (1 << b) & hotMask != 0
	}

	isCold(b int) {
		return (1 << b) & coldMask != 0
	}

	:hotMask int #Mutable
	:coldMask int #Mutable

	static_init_masks() {
		hotMask = (1 << desert)
		coldMask = (1 << icePlains) | (1 << taiga)
	}
}

Generator {
	generate(g Grid, rs *uint) {
		terrainA := new GradientNoiseMap2D(rs)
		terrainB := new GradientNoiseMap2D(rs)
		noise := new GradientNoiseMap2D(rs)
		noise2 := new GradientNoiseMap2D(rs)
		noise3 := new GradientNoiseMap2D(rs)
		noise4 := new GradientNoiseMap2D(rs)
		noise5 := new GradientNoiseMap2D(rs)
		biomeOfsX := new GradientNoiseMap2D(rs)
		biomeOfsZ := new GradientNoiseMap2D(rs)
		iceNoise := new GradientNoiseMap2D(rs)
		topLayer := new GradientNoiseMap2D(rs)
		topLayer2 := new GradientNoiseMap2D(rs)

		biomeMap := new Array<BiomeCell>(g.size.x * g.size.z)
		vg := VoronoiGrid2D.fromNumPoints(128, 128, 16, rs)
		for i := 0; i < 2 {
			//vg = VoronoiGrid2D.fromPoints(128, 128, vg.getCentroids())
		}

		biomes := allocateBiomes(vg, rs)

		biomeCells := new Array<List<IntVector2>>(Biomes.numBiomes)
		biomeCells_border := new Array<List<IntVector2>>(Biomes.numBiomes)
		biomeCells_nonBorder := new Array<List<IntVector2>>(Biomes.numBiomes)
		for i := 0; i < biomeCells.count {
			biomeCells[i] = new List<IntVector2>{}
			biomeCells_border[i] = new List<IntVector2>{}
			biomeCells_nonBorder[i] = new List<IntVector2>{}
		}

		for x := 0; x < g.size.x {
			for z := 0; z < g.size.z {
				bpx := cast(x / 4.0 + sampleNoise(biomeOfsX, x, z, 512, 16) * 10, int) & 0x7f
				bpz := cast(z / 4.0 + sampleNoise(biomeOfsZ, x, z, 512, 16) * 10, int) & 0x7f
				vci := bpz * vg.size.x + bpx
				biome := biomes[vg.tiles[vci].closest1.id - 1]
				biomeMap[get2DIndex(g, x, z)] = BiomeCell { biome: biome, mask: 1 << biome }
				biomeCells[biome].add(IntVector2(x, z))
			}
		}

		for x := 0; x < g.size.x {
			for z := 0; z < g.size.z {
				biome := biomeMap[get2DIndex(g, x, z)].biome
				mask := 0
				for dx := -7; dx <= 7 {
					for dz := -7; dz <= 7 {
						dist := dx * dx + dz * dz
						if dist < 50 {
							mask |= biomeMap[get2DIndex(g, x + dx, z + dz)].mask
						}
					}
				}
				isBorder := false
				if Biomes.isCold(biome) {
					if (mask & ~Biomes.coldMask) != 0 {
						isBorder = true
					}
				} else if biome != Biomes.desert {
					if (mask & Biomes.coldMask) != 0 {
						isBorder = true
					}
				}
				biomeMap[get2DIndex(g, x, z)].isBorder = isBorder
				if isBorder {
					biomeCells_border[biome].add(IntVector2(x, z))
				} else {
					biomeCells_nonBorder[biome].add(IntVector2(x, z))
				}
			}
		}

		for x := 0; x < g.size.x {
			for z := 0; z < g.size.z {
				valA := sampleNoise(terrainA, x, z, 512, 8)
				valA += sampleNoise(terrainA, x, z, 512, 16) * .5
				valA = to01(stretch(valA, 1.5))

				valB := sampleNoise(terrainB, x, z, 512, 8)
				valB += sampleNoise(terrainB, x, z, 512, 16) * .5
				valB = to01(stretch(valB, 1.5))
				
				mountains := domain(valB, .50, .6)
				ocean := min(domain(valA, .45, .35), domain(valB, .65, .55))

				val := 12.0
				val += sampleNoise(noise, x, z, 512, 16) * 4
				val += sampleNoise(noise2, x, z, 512, 32) * 2
				val += sampleNoise(noise3, x, z, 512, 64)

				if mountains > 0 {
					val += mountains * easeS01(sampleNoise01(noise4, x, z, 512, 8), 150) * 10
					val += mountains * easeS01(sampleNoise01(noise5, x, z, 512, 16), 150) * 6
				}
				if ocean > 0 {
					val -= ocean * 5
				}

				bpx := cast(x / 4.0 + sampleNoise(biomeOfsX, x, z, 512, 16) * 10, int) & 0x7f
				bpz := cast(z / 4.0 + sampleNoise(biomeOfsZ, x, z, 512, 16) * 10, int) & 0x7f
				vci := bpz * vg.size.x + bpx

				biomeInfo := biomeMap[get2DIndex(g, x, z)]
				biome := biomeInfo.biome
				isBorder := biomeInfo.isBorder
				//biome = 0 // DEBUG

				h := clampi(cast(val, int), 2, 32)

				ci := getCellIndex(g, x, 0, z)
				g.cells[ci] = Blocks.bedrock
				for y := 1; y < h {
					g.cells[ci + y] = Blocks.stone
				}

				ci = getCellIndex(g, x, h - 1, z)
				block := 0_b				
				if biome == Biomes.desert {
					block = Blocks.sand
				} else if biome == Biomes.plains || biome == Biomes.forest {
					block = Blocks.grass
				} else if biome == Biomes.icePlains || biome == Biomes.taiga {
					block = Blocks.grass_snow
				} else {
					abandon()
				}
				if h < 10 {
					g.cells[ci] = Blocks.sand
					for y := h; y < 10 {
						g.cells[getCellIndex(g, x, y, z)] = Blocks.water
					}
					if biome == 4 || biome == 5 {
						if domain(val, 5, 10) + sampleNoise(iceNoise, x, z, 512, 8) > .6 {
							g.cells[getCellIndex(g, x, 9, z)] = Blocks.ice
						}
					}
				} else {
					if block == Blocks.grass_snow {
						// OK
					} else {
						rand := sampleNoise(noise4, x, z, 512, 64)
						if domain(val, 13, 10) + rand * .7 > .8 {
							block = Blocks.sand
						}
					}
					g.cells[ci] = block
					if sampleNoise(topLayer, x, z, 512, 64) > 0 {
						g.cells[ci - 1] = block == Blocks.sand ? Blocks.sand : Blocks.dirt
					}
				}
			}
		}

		generateOres(g, rs)
		generateCaves(g, 1400, rs)
		removeTemporaryBlocks(g)
		fixWaterLeaks(g, biomeMap)
		generateLavaLakes(g, rs)
		generateLavaPoolsOnSurface(g, rs)
		heightMap := buildHeightMap(g)

		//caveDebug(g)
		//oreDebug(g)
		generateObjects(g, biomeCells, biomeCells_border, biomeCells_nonBorder, rs)
		removeTemporaryBlocks(g)
	}

	buildHeightMap(g Grid) {
		result := new Array<int>(g.size.x * g.size.z)
		for z := 0; z < g.size.z {
			for x := 0; x < g.size.x {
				result[get2DIndex(g, x, z)] = getTop(g, x, z)
			}
		}
		return result
	}

	oreDebug(g Grid) {
		ci := 0
		count := 0
		for z := 0; z < g.size.z {
			for x := 0; x < g.size.x {
				for y := 0; y < 32 {
					if g.cells[ci] == Blocks.stone {
						g.cells[ci] = 0
						count += 1
					}
					ci += 1
				}
			}
		}
		//Stdout.writeLine(format("{}", count))
	}

	generateCaves(g Grid, num int, rs *uint) {
		for i := 0; i < num {
			px := randomInt(rs, 0, g.size.x)
			py := randomInt(rs, 3, 20)
			pz := randomInt(rs, 0, g.size.z)
			tunnels := randomInt(rs, 2, 4)
			underground := randomInt(rs, 0, 10) == 0 ? false : true
			for j := 0; j < tunnels {
				carveTunnel(g, randomInt(rs, 20, 180), px, py, pz, underground, rs)
			}
		}
	}

	randomTunnelDir(rs *uint) {
		angle := randomFloat(rs, 0, pi * 2)
		y := randomFloat(rs, -.4, .4)
		f := sqrt(1 - y * y)
		return Vector3(cos(angle) * f, y, sin(angle) * f)
	}

	carveTunnel(g Grid, steps int, px int, py int, pz int, underground bool, rs *uint) {
		p := Vector3(px, py, pz)
		dir := randomTunnelDir(rs)
		// TODO: We accidentally built cave gen using buggy Quaternion code, results are cool though.
		// So, keeping for now, though ideally this would be replaced by a call to the bugfree implementation with different args.
		rotation := Quaternion.rotationAxis_buggy(randomUnitVector3(rs), .05)
		r := randomFloat(rs, 1.4, 2.5)		
		for i := 0; i < steps {
			if !carveTunnelSection(g, Vector3(p.x, p.y > 0 ? max(1, p.y) : p.y, p.z), r * r, underground) {
				return
			}
			p = p.add(dir)
			dir = rotation.toMatrix().mulv3(dir)
			if randomInt(rs, 0, 10) == 0 || p.y < 2 {
				Quaternion.rotationAxis_buggy(randomUnitVector3(rs), .05 * (2 - p.y))
			}
		}
	}

	carveTunnelSection(g Grid, p Vector3, rsq float, underground bool) {
		px := cast(p.x, int)
		py := cast(p.y, int)
		pz := cast(p.z, int)
		fromX := px - 3
		toX := px + 3
		fromY := py - 3
		toY := py + 3
		fromZ := pz - 3
		toZ := pz + 3

		for x := fromX; x <= toX {
			for z := fromZ; z <= toZ {
				for y := toY; y >= fromY; y -= 1 {
					if y < 0 || y >= 31 {
						continue
					}
					dx := p.x - x + .5
					dy := p.y - y + .5
					dz := p.z - z + .5
					distsq := dx * dx + dy * dy + dz * dz
					if distsq < rsq && y > 0 {
						ci := getCellIndexWrappedXZ(g, x, y, z)
						above := g.cells[ci + 1]
						if (underground && above == 0) || above == Blocks.water {
							return false
						}
						break
					}					
				}
			}
		}

		for x := fromX; x <= toX {
			for z := fromZ; z <= toZ {
				for y := fromY; y <= toY {
					if y < 0 || y >= 31 {
						continue
					}
					dx := p.x - x + .5
					dy := p.y - y + .5
					dz := p.z - z + .5
					distsq := dx * dx + dy * dy + dz * dz
					if distsq < rsq && y > 0 {
						ci := getCellIndexWrappedXZ(g, x, y, z)
						if g.cells[ci] != Blocks.water {
							g.cells[ci] = Blocks.diamond_block
							if y == 1 {
								g.cells[ci + 1] = Blocks.diamond_block
							}
						}
					}					
				}
			}
		}

		return true
	}

	removeTemporaryBlocks(g Grid) {
		ci := 0
		for x := 0; x < g.size.x {
			for z := 0; z < g.size.z {
				for y := 0; y < 32 {
					if g.cells[ci] == Blocks.diamond_block {
						g.cells[ci] = 0
					}
					ci += 1
				}
			}
		}
	}

	fixWaterLeaks(g Grid, biomeMap Array<BiomeCell>) {
		for x := 0; x < g.size.x {
			for z := 0; z < g.size.z {
				for y := 0; y < 32 {
					ci := getCellIndexWrappedXZ(g, x, y, z)
					if g.cells[ci] == Blocks.water {
						for d := 0; d < 5 {
							delta := IntVector3.delta[d]
							next := getCellIndexWrappedXZ(g, x + delta.x, y + delta.y, z + delta.z)
							if g.cells[next] == 0 {
								biome := biomeMap[get2DIndex(g, x + delta.x, z + delta.z)].biome
								g.cells[next] = Biomes.isCold(biome) ? Blocks.ice : Blocks.sandstone
							}
						}
					}
					if g.cells[ci] == Blocks.sand && g.cells[ci - 1] == 0 {
						g.cells[ci] = Blocks.sandstone
					}
				}
			}
		}
	}

	generateLavaLakes(g Grid, rs *uint) {
		pools := new List<List<IntVector3>>{}
		for x := 0; x < g.size.x {
			for z := 0; z < g.size.z {
				ci := getCellIndexWrappedXZ(g, x, 1, z)
				if g.cells[ci] == 0 {
					cells := new List<IntVector3>{}
					floodFill(g, x, 1, z, Blocks.gold_block, 4, int.maxValue, cells)
					pools.add(cells)
				}
			}
		}
		shuffle(ref pools.slice(0, pools.count), rs)
		num := 0
		for p in pools {
			num += p.count
		}
		num /= 2
		for p in pools {
			block := cast(num > 0 ? Blocks.lava : 0, byte)
			for c in p {
				g.cells[getCellIndexWrappedXZ(g, c.x, c.y, c.z)] = block
			}
			num -= p.count
		}
	}

	generateLavaPoolsOnSurface(g Grid, rs *uint) {
		pools := new List<List<IntVector3>>{}
		for x := 0; x < g.size.x {
			for z := 0; z < g.size.z {
				ci := getCellIndexWrappedXZ(g, x, 9, z)
				if g.cells[ci] == 0 {
					cells := new List<IntVector3>{}
					ok := floodFill(g, x, 9, z, Blocks.gold_block, 5, 70, cells)
					if ok {
						pools.add(cells)
					} else {
						for c in cells {
							g.cells[getCellIndexWrappedXZ(g, c.x, c.y, c.z)] = Blocks.diamond_block
						}
					}
				}
			}
		}
		shuffle(ref pools.slice(0, pools.count), rs)
		numPools := pools.count / 2
		for i := 0; i < numPools {
			p := pools[i]
			for c in p {
				g.cells[getCellIndexWrappedXZ(g, c.x, c.y, c.z)] = Blocks.lava
			}
		}
		ci := 0
		for x := 0; x < g.size.x {
			for z := 0; z < g.size.z {
				for y := 0; y < 32 {
					if g.cells[ci] == Blocks.diamond_block || g.cells[ci] == Blocks.gold_block {
						g.cells[ci] = 0
					}
					ci += 1
				}
			}
		}
	}

	floodFill(g Grid, px int, py int, pz int, block byte, maxDir int, maxCount int, out List<IntVector3>) bool {
		ci := getCellIndexWrappedXZ(g, px, py, pz)
		b := g.cells[ci]
		if b == Blocks.diamond_block || b == Blocks.ice {
			return false
		}
		if g.cells[ci] != 0 {
			return true
		}
		if maxCount == 0 {
			return false
		}
		g.cells[ci] = block
		out.add(IntVector3(px, py, pz))
		for d := 0; d < maxDir {
			delta := IntVector3.delta[d]
			if !floodFill(g, px + delta.x, py + delta.y, pz + delta.z, block, maxDir, maxCount - 1, out) {
				return false
			}
		}
		return true
	}

	generateOres(g Grid, rs *uint) {		
		genOreRepeated(g, 1, 26, Blocks.coal_ore, randomInt(rs, 4, 15), .5, 18000, rs)
		genOreRepeated(g, 1, 16, Blocks.iron_ore, randomInt(rs, 4, 9), 2, 9000, rs)
		genOreRepeated(g, 1, 9, Blocks.gold_ore, randomInt(rs, 4, 9), 2, 1000, rs)
		genOreRepeated(g, 1, 6, Blocks.diamond_ore, randomInt(rs, 4, 9), 2, 3000, rs)
	}

	genOreRepeated(g Grid, minY int, maxY int, block byte, size int, f_bias float, count int, rs *uint) {
		for i := 0; i < count {
			genOre(g, minY, maxY, block, size, f_bias, rs)
		}
	}

	genOre(g Grid, minY int, maxY int, block byte, size int, f_bias float, rs *uint) {
		start := IntVector3(randomInt(rs, 0, g.size.x), randomInt(rs, minY, maxY), randomInt(rs, 0, g.size.z))
		ci := getCellIndexWrappedXZ(g, start.x, start.y, start.z)
		if g.cells[ci] == Blocks.stone {
			g.cells[ci] = block
		}
		cells := new List<IntVector3>{}
		cells.add(start)
		tries := size * 2
		count := 1
		for i := 0; i < tries {
			if count >= size {
				break
			}
			f := pow(randomFloat(rs, 0, 1), f_bias)
			index := clampi(cast(f * cells.count, int), 0, cells.count - 1)
			p := cells[index]
			delta := IntVector3.delta[randomInt(rs, 0, 6)]
			next := p.add(delta)
			nextCi := getCellIndexWrappedXZ(g, next.x, next.y, next.z)
			if nextCi >= 0 {
				b := g.cells[nextCi]
				if b != block {
					if b == Blocks.stone || b == Blocks.coal_ore || b == Blocks.diamond_ore || b == Blocks.gold_ore || b == Blocks.iron_ore {
						g.cells[nextCi] = block
					}
					cells.add(next)
					count += 1
				}
			}
		}
	}

	caveDebug(g Grid) {
		for x := 0; x < g.size.x {
			for z := 0; z < g.size.z {
				isUnderground := false
				for y := 31; y >= 0; y -= 1 {
					ci := getCellIndexWrappedXZ(g, x, y, z)
					b := g.cells[ci]
					if b != 0 {
						isUnderground = true
					}
					if b == 0 && isUnderground {
						g.cells[ci] = Blocks.diamond_block
					} else {
						g.cells[ci] = 0
					}
					if y == 0 {
						g.cells[ci] = Blocks.bedrock
					}
				}
			}
		}
	}

	generateObjects(g Grid, biomeCells Array<List<IntVector2>>, biomeCells_border Array<List<IntVector2>>, biomeCells_nonBorder Array<List<IntVector2>>, rs *uint) {
		generateCacti(g, biomeCells[Biomes.desert], biomeCells[Biomes.desert].count / 100, rs)

		generateForest(g, biomeCells_nonBorder[Biomes.plains], biomeCells_nonBorder[Biomes.plains].count / 160, rs)
		generateForest(g, biomeCells_nonBorder[Biomes.forest], biomeCells_nonBorder[Biomes.forest].count / 30, rs)
		generateTaiga(g, biomeCells_border[Biomes.plains], biomeCells_border[Biomes.plains].count / 160, rs)
		generateTaiga(g, biomeCells_border[Biomes.forest], biomeCells_border[Biomes.forest].count / 30, rs)

		generateTaiga(g, biomeCells[Biomes.icePlains], biomeCells[Biomes.icePlains].count / 160, rs)
		generateTaiga(g, biomeCells[Biomes.taiga], biomeCells[Biomes.taiga].count / 30, rs)

		addSnowToSpruceLeaves(g, biomeCells[Biomes.icePlains])
		addSnowToSpruceLeaves(g, biomeCells[Biomes.taiga])
	}

	generateCacti(g Grid, biomeCells List<IntVector2>, num int, rs *uint) {
		for i := 0; i < num {
			p := biomeCells[randomInt(rs, 0, biomeCells.count)]
			genCactus(g, p.x, p.y, rs)			
		}
	}

	genCactus(g Grid, px int, pz int, rs *uint) {
		py := getTop(g, px, pz)
		ci := getCellIndexWrappedXZ(g, px, py, pz)
		if g.cells[ci] != Blocks.sand {
			return
		}
		if py > 28 {
			return
		}
		top := py + randomInt(rs, 1, 4)
		for y := py + 1; y <= top {
			nci := getCellIndexWrappedXZ(g, px, y, pz)
			if g.cells[nci] == 0 {
				if (g.cells[getCellIndexWrappedXZ(g, px + 1, y, pz)] != Blocks.cactus &&
					g.cells[getCellIndexWrappedXZ(g, px - 1, y, pz)] != Blocks.cactus &&
					g.cells[getCellIndexWrappedXZ(g, px, y, pz + 1)] != Blocks.cactus &&
					g.cells[getCellIndexWrappedXZ(g, px, y, pz - 1)] != Blocks.cactus) {
					g.cells[nci] = Blocks.cactus
				} else {
					break
				}
			}
		}
	}

	generateForest(g Grid, biomeCells List<IntVector2>, numTrees int, rs *uint) {
		for i := 0; i < numTrees {
			p := biomeCells[randomInt(rs, 0, biomeCells.count)]
			py := canPlantTree(g, p.x, p.y, Blocks.grass)
			if py >= 0 {
				if randomInt(rs, 0, 4) == 0 {
					genBirchTree(g, p.x, py, p.y, rs)
				} else {
					genOakTree(g, p.x, py, p.y, rs)
				}
			}
		}
	}

	generateTaiga(g Grid, biomeCells List<IntVector2>, numTrees int, rs *uint) {		
		for i := 0; i < numTrees {
			p := biomeCells[randomInt(rs, 0, biomeCells.count)]
			py := canPlantTree(g, p.x, p.y, Blocks.grass_snow)
			if py < 0 {
				py = canPlantTree(g, p.x, p.y, Blocks.grass)
			}
			if py >= 0 {
				genSpruceTree(g, p.x, py, p.y, rs)
			}
		}
	}

	getTop(g Grid, px int, pz int) {
		ci := getCellIndexWrappedXZ(g, px, 31, pz)
		for y := 31; y >= 0; y -= 1 {			
			if g.cells[ci] != 0 {
				return y
			}
			ci -= 1
		}
		return 0
	}

	canPlantTree(g Grid, px int, pz int, soil byte) {
		py := 0
		while py < 32 {
			ci := getCellIndexWrappedXZ(g, px, py, pz)
			block := g.cells[ci]
			if block == soil {
				break
			}
			py += 1
		}
		if py > 25 {
			return -1
		}
		py += 1
		if g.cells[getCellIndexWrappedXZ(g, px, py, pz)] != 0 {
			return -1
		}
		for d := 0; d < 4 {
			delta := IntVector3.delta[d]
			ci := getCellIndexWrappedXZ(g, px + delta.x, py, pz + delta.z)
			if blockIsLog(g.cells[ci]) {
				return -1
			}
		}
		return py
	}

	genOakTree(g Grid, px int, py int, pz int, rs *uint) {
		to := py + randomInt(rs, 3, 5)
		for ; py < to; py += 1 {
			g.cells[getCellIndexWrappedXZ(g, px, py, pz)] = logVertical(Blocks.oak_log)
		}
		size := randomInt(rs, 0, 2)
		py -= 1
		fromX := px - 2
		toX := px + 2
		fromY := py - 1
		toY := py + 1
		fromZ := pz - 2
		toZ := pz + 2
		for y := fromY; y <= toY {
			stepY := y - fromY
			maxDistFrom := 0
			maxDistTo := 0
			if stepY == 0 {
				maxDistFrom = 4
				maxDistTo = 6 + size
			} else if stepY == 1 {
				maxDistFrom = 4
				maxDistTo = 6 + size
			} else {
				maxDistFrom = 1
				maxDistTo = 5 + size
			}

			for x := fromX; x <= toX {
				for z := fromZ; z <= toZ {
					dist := (px - x) * (px - x) + (pz - z) * (pz - z)
					if dist < randomInt(rs, maxDistFrom, maxDistTo) {
						ci := getCellIndexWrappedXZ(g, x, y, z)
						if g.cells[ci] == 0 {
							g.cells[ci] = Blocks.oak_leaves
						}
					}
				}
			}
		}
	}

	genBirchTree(g Grid, px int, py int, pz int, rs *uint) {
		to := py + randomInt(rs, 3, 5)
		for ; py < to; py += 1 {
			g.cells[getCellIndexWrappedXZ(g, px, py, pz)] = logVertical(Blocks.birch_log)
		}
		size := randomInt(rs, 0, 3)
		py -= 1
		fromX := px - 2
		toX := px + 2
		fromY := py - 1
		toY := py + 1
		fromZ := pz - 2
		toZ := pz + 2
		for y := fromY; y <= toY {
			stepY := y - fromY
			maxDistFrom := 0
			maxDistTo := 0
			if stepY == 0 {
				maxDistFrom = 2
				maxDistTo = 5 + size * 2
			} else if stepY == 1 {
				maxDistFrom = 2
				maxDistTo = 5 + size * 2
			} else {
				maxDistFrom = 1
				maxDistTo = 5 + size
			}

			for x := fromX; x <= toX {
				for z := fromZ; z <= toZ {
					dist := (px - x) * (px - x) + (pz - z) * (pz - z)
					if dist < randomInt(rs, maxDistFrom, maxDistTo) {
						ci := getCellIndexWrappedXZ(g, x, y, z)
						if g.cells[ci] == 0 {
							g.cells[ci] = Blocks.birch_leaves
						}
					}
				}
			}
		}
	}

	genSpruceTree(g Grid, px int, py int, pz int, rs *uint) {
		from := py
		to := py + randomInt(rs, 4, 6)
		for ; py < to; py += 1 {
			g.cells[getCellIndexWrappedXZ(g, px, py, pz)] = logVertical(Blocks.spruce_log)
		}
		g.cells[getCellIndexWrappedXZ(g, px, to, pz)] = Blocks.spruce_leaves
		for d := 0; d < 4 {
			delta := IntVector3.delta[d]
			g.cells[getCellIndexWrappedXZ(g, px + delta.x, to - 1, pz + delta.z)] = Blocks.spruce_leaves
		}

		fromX := px - 2
		toX := px + 2
		fromZ := pz - 2
		toZ := pz + 2
		fromY := from + 1 + randomInt(rs, 0, 3) / 2
		maxDist := 0
		for y := fromY; y < to - 1 {
			stepY := y - fromY
			if stepY == 0 {
				maxDist = randomInt(rs, 5, 8)
			} else if stepY == 1 || stepY == 3 {
				maxDist = -1
			} else if stepY == 2 {
				maxDist = randomInt(rs, 2, 6)
			}
			for x := fromX; x <= toX {
				for z := fromZ; z <= toZ {
					dist := (px - x) * (px - x) + (pz - z) * (pz - z)
					if dist < (maxDist >= 0 ? maxDist : randomInt(rs, 0, 2)) {
						ci := getCellIndexWrappedXZ(g, x, y, z)
						if g.cells[ci] == 0 {
							g.cells[ci] = Blocks.spruce_leaves
						}
					}
				}
			}
		}
	}

	addSnowToSpruceLeaves(g Grid, cells List<IntVector2>) {
		for c in cells {
			y := getTop(g, c.x, c.y)
			ci := getCellIndexWrappedXZ(g, c.x, y, c.y)
			if g.cells[ci] == Blocks.spruce_leaves {
				g.cells[ci] = Blocks.spruce_leaves_snow
			}
		}
	}

	allocateBiomes(vg VoronoiGrid2D, rs *uint) {
		biomes := new Array<int>(16)
		startingCell := vg.tiles[0].closest1.id - 1
		biomes[startingCell] = Biomes.plains
		
		sizes := new Array<int>(16)
		for t in vg.tiles {
			sizes[t.closest1.id - 1] += 1
		}

		areas := new List<AreaInfo>{}
		for sz, i in sizes {
			if i != startingCell {
				areas.add(AreaInfo { cell: i, size: sz })
			}
		}
		areas.stableSort(AreaInfo.size_cmpFn_desc)

		index := 0

		todo := new List<int>{}
		todo.add(Biomes.plains)
		todo.add(Biomes.plains)
		todo.add(Biomes.forest)
		todo.add(Biomes.taiga)
		todo.add(Biomes.icePlains)
		todo.add(Biomes.plains)
		todo.add(Biomes.plains)
		todo.add(Biomes.taiga)
		todo.add(Biomes.desert)
		todo.add(Biomes.icePlains)
		todo.add(Biomes.forest)
		todo.add(Biomes.plains)
		todo.add(Biomes.desert)
		todo.add(Biomes.plains)
		todo.add(Biomes.desert)

		shuffle(ref todo.slice(0, todo.count), rs)
		for b in todo {
			biomes[areas[index].cell] = b
			index += 1
		}

		assert(index == areas.count)
		return biomes
	}
}

BiomeCell struct {
	biome int
	mask int
	isBorder bool
}

AreaInfo struct {
	cell int
	size int

	size_cmpFn_desc(a AreaInfo, b AreaInfo) {
		return int.compare(b.size, a.size)
	}
}
