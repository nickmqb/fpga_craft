//tab_size=4
// Copyright 2021 nickmqb
// SPDX-License-Identifier: Apache-2.0

// Syntax:
// "x.png": Load texture
// "a.png|b.png": Overlay b on top of a
// "a.png,FF80FF": Multiply all pixels with specified hex color
Ids {
	:bedrock = "bedrock.png"
	:birch_leaves = "birch_leaves.png,ABCC79"
	:birch_log = "birch_log.png"
	:birch_log_top = "birch_log_top.png"
	:birch_planks = "birch_planks.png"
	:bookshelf = "bookshelf.png"
	:bricks = "bricks.png"
	:cactus_side = "cactus_side.png"
	:cactus_top = "cactus_top.png"
	:coal_ore = "coal_ore.png"
	:cobblestone = "cobblestone.png"
	:cracked_animated = "custom_cracked.png"
	:diamond_block = "diamond_block.png"
	:diamond_ore = "diamond_ore.png"
	:dirt = "dirt.png"
	:door_bottom = "spruce_door_bottom.png"
	:door_top = "spruce_door_top.png"
	:furnace_front = "furnace_front.png"
	:furnace_side = "furnace_side.png"
	:furnace_top = "furnace_top.png"
	:gold_block = "gold_block.png"
	:gold_ore = "gold_ore.png"
	:grass_side = "grass_block_side.png|grass_block_side_overlay.png,6DC952"
	:grass_top = "grass_block_top.png,6DC952"
	:gravel = "gravel.png"
	:ice = "ice.png"
	:iron_block = "iron_block.png"
	:iron_ore = "iron_ore.png"
	:lamp = "glowstone.png"
	:lava_animated = "lava_still.png"
	:oak_leaves = "oak_leaves.png,63AA3B"
	:oak_log = "oak_log.png"
	:oak_log_top = "oak_log_top.png"
	:oak_planks = "oak_planks.png"
	:obsidian = "obsidian.png"
	:portal_2_animated = "nether_portal.png"
	:portal_3 = "custom_portal_3.png"
	:rocket = "custom_rocket.png"
	:sand = "sand.png"
	:sandstone_bottom = "sandstone_bottom.png"
	:sandstone = "sandstone.png"
	:sandstone_top = "sandstone_top.png"
	:snow = "snow.png"
	:snow_side = "grass_block_snow.png"
	:spruce_leaves = "spruce_leaves.png,54915A"
	:spruce_leaves_snow_side = "spruce_leaves.png,54915A|grass_block_snow.png,EXTRACT"
	:spruce_log = "spruce_log.png"
	:spruce_log_top = "spruce_log_top.png"
	:spruce_planks = "spruce_planks.png"
	:stone = "stone.png"
	:stone_bricks = "stone_bricks.png"
	:water_bucket = "custom_water_bucket.png"
}

generate() {
	// Note: if a block uses >2 textures, they must all be in the same group of 16 (i.e. their ids may only differ in the last 4 bits)
	map := new Map.create<string, int>()

	map.add(Ids.oak_planks, 0)
	map.add(Ids.bookshelf, 1)
	map.add(Ids.furnace_front, 2)
	map.add(Ids.furnace_side, 3)
	map.add(Ids.furnace_top, 4)
	map.add(Ids.sandstone, 5)
	map.add(Ids.sandstone_bottom, 6)
	map.add(Ids.sandstone_top, 7)

	map.add(Ids.dirt, 16)
	map.add(Ids.grass_top, 17)
	map.add(Ids.grass_side, 18)
	map.add(Ids.snow, 19)
	map.add(Ids.snow_side, 20)
	map.add(Ids.spruce_leaves, 21)
	map.add(Ids.spruce_leaves_snow_side, 22)
	map.add(Ids.birch_log, 23)
	map.add(Ids.birch_log_top, 24)
	map.add(Ids.oak_log, 25)
	map.add(Ids.oak_log_top, 26)
	map.add(Ids.spruce_log, 27)
	map.add(Ids.spruce_log_top, 28)
	
	map.add(Ids.lava_animated, 124)
	map.add(Ids.portal_2_animated, 125)
	map.add(Ids.cracked_animated, 126)
	map.add(Ids.water_bucket, 127)

	ig := BlockInfoGenerator.generate(map)

	textures := new Array<string>(128)
	for e in map {
		textures[e.value] = e.key
	}
	
	generateCode(textures, ig)
	generateTextMapping(ig)

	numTextures := 0
	for tx in textures {
		if tx != "" {
			numTextures += 1
		}
	}

	Stdout.writeLine(format("{}/128 textures; {}/256 block info entries", numTextures, ig.names.count))
}

TextureInfo struct #RefType {
	name string
	mulColor string
	overlay TextureInfo
}

parseTextureInfo(s string) TextureInfo {
	result := new TextureInfo{}
	sep := s.indexOf("|")
	if sep >= 0 {
		result.overlay = parseTextureInfo(s.slice(sep + 1, s.length))
		s = s.slice(0, sep)
	}
	sep = s.indexOf(",")
	if sep >= 0 {
		result.mulColor = s.slice(sep + 1, s.length)
		s = s.slice(0, sep)
	}
	result.name = s
	return result
}

writeLine(sb StringBuilder, s string) {
	sb.write(s)
	sb.write("\n")
}

writeTextureLoad(sb StringBuilder, ti TextureInfo) {
	sb.write("(loadTexture_checked(\"../textures/")
	sb.write(ti.name)
	sb.write("\")")
	if ti.mulColor != "" {
		if ti.mulColor == "EXTRACT" {
			sb.write(".extractOverlay(160)")
		} else {
			sb.write(format(".mulColor(hexToColor(\"{}\"))", ti.mulColor))
		}
	}
	sb.write(")")
	if ti.overlay != null {
		sb.write(".add")
		writeTextureLoad(sb, ti.overlay)		
	}
}

generateCode(textures Array<string>, ig BlockInfoGenerator) {
	sb := new StringBuilder{}
	
	writeLine(sb, "// Auto generated, don't modify directly\n")

	writeLine(sb, "setTextures(textures Array<*Image>) {")
	for i := 0; i < 128 {
		ts := textures[i]
		if ts == Ids.cracked_animated || ts == Ids.lava_animated || ts == Ids.portal_2_animated {
			ti := parseTextureInfo(ts)
			sb.write(format("\ttextures[{}] = loadAnimatedTexture_checked(\"../textures/", i))
			sb.write(ti.name)
			sb.write("\")\n")
		} else if ts != ""{
			ti := parseTextureInfo(ts)
			sb.write(format("\ttextures[{}] = ", i))
			writeTextureLoad(sb, ti)
			sb.write("\n")
		} else {
			writeLine(sb, format("\ttextures[{}] = new Image(16, 16)", i))
		}
	}
	writeLine(sb, "}\n")

	writeLine(sb, "Blocks {")

	lastName := ""
	for name, i in ig.names {
		if name != lastName {			
			if name != "none" {
				sb.write(format("\t:{} = {}_b // 0x", name, i))
				cast(i, ulong).writeHexTo(sb)
				sb.write("\n")
			}
			lastName = name
		}
	}
	writeLine(sb, "}\n")	

	writeLine(sb, "setBlockInfos(infos Array<BlockInfo>) {")
	for inf, i in ig.infos {
		writeLine(sb, format("\tinfos[{}] = BlockInfo { textureBits: {}, infoBits: {} }", i, inf.textureBits, inf.infoBits))
	}
	writeLine(sb, "}")

	assert(File.tryWriteString("../data_gen/generated_block_info.mu", sb.compactToString()))
}

generateTextMapping(ig BlockInfoGenerator) {
	sb := new StringBuilder{}

	lastName := ""
	for name, i in ig.names {
		if name != lastName {			
			if name != "none" {
				writeLine(sb, format("{} {}", i, name))
			}
			lastName = name
		}
	}

	assert(File.tryWriteString("block_info.txt", sb.compactToString()))
}

BlockInfoGenerator struct #RefType {
	infos List<BlockInfo>
	names List<string>
	textureLookup Map<string, int>
	usedTextures Array<bool>

	generate(textureLookup Map<string, int>) {	
		g := new BlockInfoGenerator {
			infos: new List<BlockInfo>{},
			names: new List<string>{},
			textureLookup: textureLookup,
			usedTextures: new Array<bool>(128),
		}
		for p in textureLookup {
			g.usedTextures[p.value] = true
		}

		// 0-1: transparent; 0-7: walkable
		simple(g, "air", Ids.diamond_block)
		simple(g, "water", Ids.water_bucket)
		simple(g, "lava", Ids.lava_animated)
		simple(g, "portal_3", Ids.portal_3)
		simple(g, "portal_2", Ids.portal_2_animated) // x dir
		simple(g, "portal_2", Ids.portal_2_animated) // z dir
		simple(g, "none", Ids.diamond_block)
		simple(g, "none", Ids.diamond_block)
		simpleRepeated(g, "none", Ids.diamond_block, 8)

		// 16-31: light emitters
		simple(g, "lamp", Ids.lamp)
		simpleRepeated(g, "none", Ids.diamond_block, 15)

		assert(g.infos.count == 32)
		rotatedGeneric4(g, "bookshelf", Ids.oak_planks, Ids.oak_planks, Ids.bookshelf, Ids.oak_planks)
		rotatedGeneric4(g, "furnace", Ids.furnace_top, Ids.furnace_top, Ids.furnace_front, Ids.furnace_side)

		rotated3(g, "birch_log", Ids.birch_log_top, Ids.birch_log)
		simple(g, "birch_log", Ids.birch_log)
		topBottomSide(g, "grass_snow", Ids.snow, Ids.dirt, Ids.snow_side)

		rotated3(g, "oak_log", Ids.oak_log_top, Ids.oak_log)
		simple(g, "oak_log", Ids.oak_log)
		topBottomSide(g, "grass", Ids.grass_top, Ids.dirt, Ids.grass_side)

		rotated3(g, "spruce_log", Ids.spruce_log_top, Ids.spruce_log)
		simple(g, "spruce_log", Ids.spruce_log)
		topBottomSide(g, "spruce_leaves_snow", Ids.snow, Ids.spruce_leaves, Ids.spruce_leaves_snow_side)

		assert(g.infos.count % 2 == 0)
		topSide(g, "door_bottom", Ids.spruce_planks, Ids.door_bottom)
		topSide(g, "door_top", Ids.spruce_planks, Ids.door_top)
		addInfoBits(g, 1 << 12, 2)
		simple(g, "cobblestone", Ids.cobblestone)
		simple(g, "obsidian", Ids.obsidian)
		simple(g, "rocket", Ids.rocket)
		simple(g, "bedrock", Ids.bedrock)

		topBottomSide(g, "sandstone", Ids.sandstone_top, Ids.sandstone_bottom, Ids.sandstone)

		simple(g, "birch_leaves", Ids.birch_leaves)
		simple(g, "birch_planks", Ids.birch_planks)
		simple(g, "bricks", Ids.bricks)
		topSide(g, "cactus", Ids.cactus_top, Ids.cactus_side)
		simple(g, "coal_ore", Ids.coal_ore)
		simple(g, "diamond_block", Ids.diamond_block)
		simple(g, "diamond_ore", Ids.diamond_ore)
		simple(g, "dirt", Ids.dirt)
		simple(g, "gold_block", Ids.gold_block)
		simple(g, "gold_ore", Ids.gold_ore)
		simple(g, "gravel", Ids.gravel)
		addInfoBits(g, 1 << 11, 1)
		simple(g, "ice", Ids.ice)
		simple(g, "iron_block", Ids.iron_block)
		simple(g, "iron_ore", Ids.iron_ore)
		simple(g, "oak_leaves", Ids.oak_leaves)
		simple(g, "oak_planks", Ids.oak_planks)
		simple(g, "sand", Ids.sand)
		addInfoBits(g, 1 << 11, 1)
		simple(g, "snow", Ids.snow)
		simple(g, "spruce_leaves", Ids.spruce_leaves)
		simple(g, "spruce_planks", Ids.spruce_planks)
		simple(g, "stone", Ids.stone)
		simple(g, "stone_bricks", Ids.stone_bricks)

		return g
	}

	simple(g BlockInfoGenerator, name string, tex string) {
		topSide(g, name, tex, tex)
	}

	simpleRepeated(g BlockInfoGenerator, name string, tex string, n int) {
		for i := 0; i < n {
			simple(g, name, tex)
		}
	}

	topSide(g BlockInfoGenerator, name string, top string, side string) {
		g.alloc(top)
		g.alloc(side)
		iside := g.textureLookup.get(side)
		g.infos.add(BlockInfo { textureBits: (g.textureLookup.get(top) << 7) | iside, infoBits: iside })
		g.names.add(name)
	}

	topBottomSide(g BlockInfoGenerator, name string, top string, bottom string, side string) {
		generic(g, name, top, bottom, side, side, side, side)
	}

	rotated3(g BlockInfoGenerator, name string, top string, side string) {
		assert(g.infos.count % 8 == 0)
		generic(g, name, side, side, top, side, top, side)
		generic(g, name, side, side, side, top, side, top)
		setRotate3(g)
		topSide(g, name, top, side)
	}

	rotatedGeneric4(g BlockInfoGenerator, name string, top string, bottom string, front string, side string) {
		assert(g.infos.count % 8 == 0)
		generic(g, name, top, bottom, front, side, side, side)
		generic(g, name, top, bottom, side, front, side, side)
		generic(g, name, top, bottom, side, side, front, side)
		generic(g, name, top, bottom, side, side, side, front)
		setRotate4(g)
	}

	rotatedGeneric4_alt(g BlockInfoGenerator, name string, top string, bottom string, side string, back string) {
		assert(g.infos.count % 8 == 0)
		generic(g, name, top, bottom, side, side, back, side)
		generic(g, name, top, bottom, side, side, side, back)
		generic(g, name, top, bottom, back, side, side, side)
		generic(g, name, top, bottom, side, back, side, side)
		setRotate4(g)
	}

	rotatedGeneric4_opp(g BlockInfoGenerator, name string, top string, bottom string, front string, side string) {
		assert(g.infos.count % 8 == 0)
		generic(g, name, top, bottom, front, side, front, side)
		generic(g, name, top, bottom, side, front, side, front)
		generic(g, name, top, bottom, front, side, front, side)
		generic(g, name, top, bottom, side, front, side, front)
		setRotate4(g)
	}

	rotatedGeneric4_corner(g BlockInfoGenerator, name string, top string, bottom string, front string, side string, other string) {
		assert(g.infos.count % 8 == 0)
		generic(g, name, top, bottom, front, side, other, other)
		generic(g, name, top, bottom, other, front, side, other)
		generic(g, name, top, bottom, other, other, front, side)
		generic(g, name, top, bottom, side, other, other, front)
		setRotate4(g)
	}

	setRotate3(g BlockInfoGenerator) {
		for i := -4; i < 0 {
			if i & 1 == 0 {
				g.infos[g.infos.count + i].textureBits |= (1 << 15) // Rotate texture
			}
			g.infos[g.infos.count + i].infoBits |= (1 << 9) | (1 << 8)
		}
	}

	setRotate4(g BlockInfoGenerator) {
		for i := -8; i < 0 {
			g.infos[g.infos.count + i].infoBits |= (1 << 8)
		}
	}

	addInfoBits(g BlockInfoGenerator, infoBits int, n int) {
		for i := -n; i < 0 {
			g.infos[g.infos.count + i].infoBits |= infoBits
		}
	}

	generic(g BlockInfoGenerator, name string, top string, bottom string, z0 string, x1 string, z1 string, x0 string) {
		g.alloc(top)
		g.alloc(bottom)
		g.alloc(z0)
		g.alloc(x1)
		g.alloc(z1)
		g.alloc(x0)
		assert(g.infos.count % 2 == 0)
		itop := g.textureLookup.get(top)
		iz0 := g.textureLookup.get(z0)
		g.infos.add(BlockInfo { textureBits: ((1 << 14) | (itop << 7) | g.textureLookup.get(z0)), infoBits: iz0 })
		g.names.add(name)
		ibottom := g.textureLookup.get(bottom)
		ix1 := g.textureLookup.get(x1)
		iz1 := g.textureLookup.get(z1)
		ix0 := g.textureLookup.get(x0)
		assert(itop & ~0xf == ibottom & ~0xf)
		assert(itop & ~0xf == ix1 & ~0xf)
		assert(itop & ~0xf == iz1 & ~0xf)
		assert(itop & ~0xf == ix0 & ~0xf)
		g.infos.add(BlockInfo { textureBits: ((ix0 & 0xf) << 12) | ((iz1 & 0xf) << 8) | ((ix1 & 0xf) << 4) | (ibottom & 0xf), infoBits: iz0 | (1 << 7) })
		g.names.add(name)
	}

	alloc(g BlockInfoGenerator, name string) {
		if g.textureLookup.containsKey(name) {
			return
		}
		for u, i in g.usedTextures {
			if !u {
				g.textureLookup.add(name, i)
				g.usedTextures[i] = true
				return
			}
		}
		Stderr.writeLine("No more available textures")
		abandon()
	}
}
