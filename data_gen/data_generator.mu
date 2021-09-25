//tab_size=4
// Copyright 2021 nickmqb
// SPDX-License-Identifier: Apache-2.0

copyImagePixelsToByteArray(dest Array<byte>, offset int, img Array<byte>) {
	// Write image upside down so that u,v coordinates are aligned with world coordinate system
	i := 0
	for y := 15; y >= 0; y -= 1 {
		for x := 0; x < 16 {
			pixel := img[y * 16 + x]
			index := offset + (i / 2) * 2 + 1
			if (i & 1) == 0 {
				dest[index] = pixel
			} else {
				dest[index] = cast(dest[index] | (pixel << 4), byte)
			}
			i += 1
		}
	}
}

buildTrigLookup() {
	trig := new Array<short>(256)
	for i := 0; i < trig.count {
		trig[i] = cast(sin(i / 512.0 * pi) * 4096 + .5, short)
	}	
	return trig
}

buildVisibilityLookup() {
	vis := new Array<byte>(256)
	for i := 0; i < 128 {
		angle := i / 64.0 * pi
		dx := sin(angle)
		dz := -cos(angle)
		scale := abs(dx) > abs(dz) ? (1 / abs(dx)) : (1 / abs(dz))
		scale *= 6.5
		dx *= scale
		dz *= scale
		vis[i * 2] = cast(floor(dx), byte)
		vis[i * 2 + 1] = cast(floor(dz), byte)
	}	
	return vis
}

convertChar(ch char) {
	chars := "`\x01\x02\x03\x04%&'()*+,-./0123456789:;<=>? ABCDEFGHIJKLMNOPQRSTUVWXYZ[$]^_"
	index := chars.indexOfChar(ch)
	if index < 0 {
		Stderr.writeLine(format("{} is not a valid char", ch))
		abandon()
	}
	return index
}

toHex(n int) {
	assert(n >= 0)
	sb := StringBuilder{}
	ulong.writeHexTo(cast(n, ulong), ref sb)
	return sb.compactToString()
}

addString(table Array<byte>, defs StringBuilder, index *int, key string, s string) {
	defs.write(format("STE_{} := 0x{}\n", key, toHex(0x1300 + index^)))
	for i := 0; i < s.length {
		table[index^] = cast(convertChar(s[i]), byte)
		index^ += 1
	}
	table[index^] = 0
	index^ += 1
}

addColor(table Array<byte>, index *int, b byte, g byte, r byte) {
	table[index^] = cast((g << 4) | r, byte)
	table[index^ + 1] = b
	index^ += 2
}

buildStringTable(defs StringBuilder) {
	defs.write("// String table\n\n")
	table := new Array<byte>(256)
	// Sky color values are placed in string table
	index := 0
	addColor(table, ref index, 15, 12, 8) //fc8
	addColor(table, ref index, 12, 10, 6) //ca6
	addColor(table, ref index, 11, 8, 7) //b87
	addColor(table, ref index, 9, 7, 7) 
	addColor(table, ref index, 8, 6, 6)
	addColor(table, ref index, 7, 5, 5)
	addColor(table, ref index, 6, 5, 5)
	addColor(table, ref index, 5, 4, 4)
	addColor(table, ref index, 3, 3, 4)
	addColor(table, ref index, 2, 2, 3)
	addColor(table, ref index, 1, 1, 2)
	addColor(table, ref index, 0, 0, 0)
	assert(index == 24)
	addString(table, defs, ref index, "GAME_MENU", "- GAME MENU -")
	addString(table, defs, ref index, "INVENTORY", "- INVENTORY -")
	addString(table, defs, ref index, "DEBUG_INFO", "DEBUG INFO")
	addString(table, defs, ref index, "FPGA_CRAFT", "FPGA_CRAFT")
	addString(table, defs, ref index, "NOCLIP", "NOCLIP")
	addString(table, defs, ref index, "TIME", "TIME [--]")
	addString(table, defs, ref index, "SAVE", "SAVE (-- CHUNKS)")
	addString(table, defs, ref index, "RETURN_TO_GAME", "RETURN TO GAME")
	addString(table, defs, ref index, "ON", " [ON]")
	addString(table, defs, ref index, "OFF", " [OFF]")
	addString(table, defs, ref index, "COORDS", "X:---- Y:---- Z:---- F:")
	addString(table, defs, ref index, "FACING_DIR", "N``NW`W``SW`S``SE`E``NE")
	addString(table, defs, ref index, "ITEM_SELECT_TOP", "\x01  \x02")
	addString(table, defs, ref index, "ITEM_SELECT_BOTTOM", "\x03  \x04")
	assert(index <= 254) // Last 2 bytes cannot be used (used for flash status reg)
	defs.write("\n")
	return table
}

buildDefaultLightMap() {
	light := new Array<byte>(32 * 32 * 32 / 2)
	for i := 0; i < light.count {
		light[i] = 0xff
	}
	return light
}

InventorySlot struct {
	block byte
	quantity byte

	cons(block byte, quantity byte) {
		return InventorySlot { block: block, quantity: quantity }
	}
}

buildInventory() {
	items := new List<InventorySlot>{}

	// Hotbar
	items.add(InventorySlot(Blocks.cobblestone, 0x40))
	items.add(InventorySlot(Blocks.rocket, 0x40))
	items.add(InventorySlot(Blocks.grass, 0x40))
	items.add(InventorySlot(Blocks.oak_planks, 0x40))
	items.add(InventorySlot(Blocks.bricks, 0x40))
	items.add(InventorySlot(Blocks.lamp, 0x40))
	items.add(InventorySlot(Blocks.door_bottom, 0x40))
	items.add(InventorySlot(Blocks.obsidian, 0x40))
	items.add(InventorySlot(Blocks.lava, 0x40))

	// Items
	items.add(InventorySlot(Blocks.bedrock, 64))
	items.add(InventorySlot(Blocks.birch_leaves, 64))
	items.add(InventorySlot(Blocks.birch_log, 64))
	items.add(InventorySlot(Blocks.birch_planks, 64))
	items.add(InventorySlot(Blocks.bookshelf, 64))
	items.add(InventorySlot(Blocks.bricks, 64))
	items.add(InventorySlot(Blocks.cactus, 64))
	items.add(InventorySlot(Blocks.coal_ore, 64))
	items.add(InventorySlot(Blocks.cobblestone, 64))
	items.add(InventorySlot(Blocks.diamond_block, 64))
	items.add(InventorySlot(Blocks.diamond_ore, 64))
	items.add(InventorySlot(Blocks.dirt, 64))
	items.add(InventorySlot(Blocks.door_bottom, 64))
	items.add(InventorySlot(Blocks.furnace, 64))
	items.add(InventorySlot(Blocks.gold_block, 64))
	items.add(InventorySlot(Blocks.gold_ore, 64))
	items.add(InventorySlot(Blocks.grass, 64))
	items.add(InventorySlot(Blocks.grass_snow, 64))
	items.add(InventorySlot(Blocks.gravel, 64))
	items.add(InventorySlot(Blocks.ice, 64))
	items.add(InventorySlot(Blocks.iron_block, 64))
	items.add(InventorySlot(Blocks.iron_ore, 64))
	items.add(InventorySlot(Blocks.lamp, 64))
	items.add(InventorySlot(Blocks.lava, 64))
	items.add(InventorySlot(Blocks.oak_leaves, 64))
	items.add(InventorySlot(Blocks.oak_log, 64))
	items.add(InventorySlot(Blocks.oak_planks, 64))
	items.add(InventorySlot(Blocks.obsidian, 64))
	items.add(InventorySlot(Blocks.rocket, 64))
	items.add(InventorySlot(Blocks.sand, 64))
	items.add(InventorySlot(Blocks.sandstone, 64))
	items.add(InventorySlot(Blocks.snow, 64))
	items.add(InventorySlot(Blocks.spruce_leaves, 64))
	items.add(InventorySlot(Blocks.spruce_leaves_snow, 64))
	items.add(InventorySlot(Blocks.spruce_log, 64))
	items.add(InventorySlot(Blocks.spruce_planks, 64))
	items.add(InventorySlot(Blocks.stone, 64))
	items.add(InventorySlot(Blocks.stone_bricks, 64))
	items.add(InventorySlot(Blocks.water, 64))

	if items.count > 9 + 108 {
		Stderr.writeLine("Too many items in inventory")
		abandon()
	}

	return new items.slice(0, items.count)
}

encodeMapOffset(dx int, dy int, dz int) {
	result := 0
	result |= (dx & 1)
	result |= ((dz & 1) << 1)
	result |= ((dy & 31) << 2)
	result |= ((dx & 30) << 6)
	result |= ((dz & 30) << 10)
	//result |= (1 << 15)
	return cast(result, ushort)
}

buildAdjacencyInfo() {
	values := new Array<ushort>(6)
	values[0] = encodeMapOffset(1, 0, 0)
	values[1] = encodeMapOffset(-1, 0, 0)
	values[2] = encodeMapOffset(0, 0, 1)
	values[3] = encodeMapOffset(0, 0, -1)
	values[4] = encodeMapOffset(0, 1, 0)
	values[5] = encodeMapOffset(0, -1, 0)
	return values
}

buildPortalLookup() {
	values := new Array<ushort>(64)
	pattern_xza := "12030303121212121212121212120303"
	pattern_xzb := "11111111111111110022002200221111"
	pattern_y   := "00112233441122331111222233330044"
	for d := 0; d < 2 {
		for i := 0; i < 32 {
			xza := pattern_xza[i] - '0' - 1
			xzb := pattern_xzb[i] - '0' - 1
			y := pattern_y[i] - '0'
			values[d * 32 + i] = d == 0 ? encodeMapOffset(xza, y, xzb) : encodeMapOffset(xzb, y, xza)
		}
	}
	return values
}

convertArray<T, U>(array Array<T>) {
	if sizeof(T) > sizeof(U) {
		assert(sizeof(T) % sizeof(U) == 0)
		return new Array<U> { dataPtr: array.dataPtr, count: CheckedMath.mulPositiveInt(array.count, sizeof(T) / sizeof(U)) }
	} else {
		assert(sizeof(U) % sizeof(T) == 0)
		return new Array<U> { dataPtr: array.dataPtr, count: CheckedMath.mulPositiveInt(array.count, sizeof(U) / sizeof(T)) }
	}
}

assertWithMessage(cond bool, message string) {
	if cond {
		return
	}
	Stderr.writeLine(message)
	abandon()
}

generateData(textures Array<*Image>, blockInfos Array<BlockInfo>, blockTextureInfos Array<BlockTextureInfo>) {
	textureBytes := new Array<byte>(64 * 1024)

	ramBytes := new Array<byte>(32 * 1024)

	palBytes := ramBytes.slice(0, 4 * 1024)

	pe := 0
	pal := cast(null, Array<ByteColor4>)

	lava := blockTextureInfos[Blocks.lava].top
	portal2 := blockTextureInfos[Blocks.portal_2].top
	destroy := 126

	for t, i in textures {
		if i == destroy {
			num := 10
			t = repeatImageTiles(t, num * 16)
			rr := reduceImageColors(t, 3)
			pal = rr.palette
			for j := 0; j <= 9 {				
				sub := ref rr.bytes.slice(j * 256, (j + 1) * 256)
				copyImagePixelsToByteArray(textureBytes, (128 + j) * 256, sub)
				if j == 0 {
					copyImagePixelsToByteArray(textureBytes, destroy * 256, sub)
				}
			}
		} else if i == lava {
			num := 20
			t = repeatImageTiles(t, num * 16)
			rr := reduceImageColors(t, 16)
			pal = rr.palette
			for j := 0; j < num {
				sub := ref rr.bytes.slice(j * 256, (j + 1) * 256)
				copyImagePixelsToByteArray(textureBytes, (160 + j) * 256, sub)
				if j == 0 {
					copyImagePixelsToByteArray(textureBytes, lava * 256, sub)
				}
			}
		} else if i == portal2 {
			num := 32
			t = repeatImageTiles(t, num * 16)
			rr := reduceImageColors(t, 16)
			pal = rr.palette
			for j := 0; j < num {
				sub := ref rr.bytes.slice(j * 256, (j + 1) * 256)
				copyImagePixelsToByteArray(textureBytes, (192 + j) * 256, sub)
				if j == 0 {
					copyImagePixelsToByteArray(textureBytes, portal2 * 256, sub)
				}
			}
		} else {
			rr := reduceImageColors(t, 16)
			pal = rr.palette
			copyImagePixelsToByteArray(textureBytes, i * 256, rr.bytes)
		}

		forceDither := 
			i == blockTextureInfos[Blocks.stone].top ||
			i == blockTextureInfos[Blocks.coal_ore].top ||
			i == blockTextureInfos[Blocks.iron_ore].top ||
			i == blockTextureInfos[Blocks.gold_ore].top ||
			i == blockTextureInfos[Blocks.diamond_ore].top ||
			i == blockTextureInfos[Blocks.stone_bricks].top ||
			i == blockTextureInfos[Blocks.gravel].top
		for p, j in pal {
			palBytes[i * 32 + j * 2] = cast((quantizeByteComponentAsU4(p.g) << 4) | quantizeByteComponentAsU4(p.r), byte)
			palBytes[i * 32 + j * 2 + 1] = cast(quantizeByteComponentAsU4(p.b) | (forceDither ? 16 : 0), byte)
		}
	}

	// String table
	kasmConstants := new StringBuilder{}
	kasmConstants.write("// Note: kasm does not support multiple files, so these constants must be manually copy-pasted into firmware.ka\n\n")
	Stdout.writeLine("Note: if any constants from constants.txt have changed, these must be must be manually copy-pasted into firmware.ka")
	stringBytes := buildStringTable(kasmConstants)
	stringBytes.copySlice(0, stringBytes.count, ramBytes, 0x1300)

	// Trig
	trigBytes := convertArray<short, byte>(buildTrigLookup())
	trigBytes.copySlice(0, trigBytes.count, ramBytes, 0x1400)

	// Block info
	blockTextureInfos16 := new Array<ushort>(256)
	for bi, i in blockInfos {
		blockTextureInfos16[i] = cast(bi.textureBits, ushort)
	}
	blockTextureInfoBytes := convertArray<ushort, byte>(blockTextureInfos16)

	blockInfos16 := new Array<ushort>(256)
	for bi, i in blockInfos {
		blockInfos16[i] = cast(bi.infoBits, ushort)
	}
	blockInfoBytes := convertArray<ushort, byte>(blockInfos16)
	blockInfoBytes.copySlice(0, blockInfoBytes.count, ramBytes, 0x1600)

	kasmConstants.write("// Block info\n\n")
	kasmConstants.write(format("DOOR_BLOCK := {}\n", Blocks.door_bottom))
	kasmConstants.write(format("COBBLESTONE_BLOCK := {}\n", Blocks.cobblestone))
	kasmConstants.write(format("OBSIDIAN_BLOCK := {}\n", Blocks.obsidian))
	kasmConstants.write(format("ROCKET := {}\n", Blocks.rocket))
	kasmConstants.write("\n")

	// Visibility
	visBytes := buildVisibilityLookup()
	visBytes.copySlice(0, visBytes.count, ramBytes, 0x1800)

	// Inventory
	inventory := buildInventory()
	inventoryBytes := convertArray<InventorySlot, byte>(inventory)
	inventoryBytes.copySlice(0, inventoryBytes.count, ramBytes, 0x1a00)

	// Adjacency
	adj := buildAdjacencyInfo()
	adjBytes := convertArray<ushort, byte>(adj)
	adjBytes.copySlice(0, adjBytes.count, ramBytes, 0x1c00)

	// Portal
	portal := buildPortalLookup()
	portalBytes := convertArray<ushort, byte>(portal)
	portalBytes.copySlice(0, portalBytes.count, ramBytes, 0x1d00)

	// Light
	//lightBytes := buildLightMap()
	lightBytes := buildDefaultLightMap()
	lightBytes.copySlice(0, lightBytes.count, ramBytes, 0x4000)

	sb := new StringBuilder{}

	sb.write("RAM_A $262144 := [\n")
	writeArray(ramBytes, sb)
	sb.write("]\n\n")

	sb.write("TEXTURES $262144 := [\n")
	writeArray(ref textureBytes.slice(0, 32 * 1024), sb)
	sb.write("]\n\n")

	sb.write("MAP $262144 := [\n")
	writeArray(new Array<byte>(32 * 1024), sb)
	sb.write("]\n\n")

	assert(File.tryWriteString("../hw/src/data_sim.w", sb.compactToString()))

	assert(File.tryWriteString("../hw/src/constants.txt", kasmConstants.compactToString()))

	sb.clear()
	sb.write("BLOCK_TEXTURE_INFO $4096 := [\n")
	writeArray(blockTextureInfoBytes, sb)
	sb.write("]\n\n")

	generateFontData(sb)
	generateLightLookup(sb)

	assert(File.tryWriteString("../hw/src/static_data.w", sb.compactToString()))

	writeBinaryFile(ramBytes, "../ram_a.bin")
	writeBinaryFile(textureBytes, "../textures.bin") // Includes animated textures
}

