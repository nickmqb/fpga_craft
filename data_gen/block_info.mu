//tab_size=4
// Copyright 2021 nickmqb
// SPDX-License-Identifier: Apache-2.0

BlockInfo struct {
	textureBits int
	infoBits int
}

BlockTextureInfo struct {
	sideX0 int
	sideX1 int
	sideZ0 int
	sideZ1 int
	bottom int
	top int
	rotateSide bool
	rotateTop bool

	cons(sideX0 int, sideX1 int, sideZ0 int, sideZ1 int, bottom int, top int) {
		return BlockTextureInfo {
			sideX0: sideX0,
			sideX1: sideX1,
			sideZ0: sideZ0,
			sideZ1: sideZ1,
			bottom: bottom,
			top: top,
		}
	}

	simple(id int) {
		return BlockTextureInfo(id, id, id, id, id, id)
	}

	sideTop(side int, bottomTop int) {
		return BlockTextureInfo(side, side, side, side, bottomTop, bottomTop)
	}

	sideBottomTop(side int, bottom int, top int) {
		return BlockTextureInfo(side, side, side, side, bottom, top)
	}
}

loadImages() {
	textures := new Array<*Image>(128)

	setTextures(textures)

	return textures
}

initBlockInfos() {
	infos := new Array<BlockInfo>(256)
	setBlockInfos(infos)
	return infos
}

getBlockTextureInfos(infos Array<BlockInfo>) {
	result := new Array<BlockTextureInfo>(256)

	for i := 0; i < 256 {
		val := infos[i].textureBits
		result[i].top = (val >> 7) & 0x7f
		result[i].sideZ0 = val & 0x7f
		result[i].rotateSide = (val >> 15) != 0
		result[i].rotateTop = (val >> 15) != 0 && (i & 2) == 2
		if ((val >> 14) & 0x1) != 0 {
			assert(i % 2 == 0)			
			nextVal := infos[i + 1].textureBits
			offset := result[i].top & ~0xf
			result[i].bottom = offset | (nextVal & 0xf)
			result[i].sideX1 = offset | ((nextVal >> 4) & 0xf)
			result[i].sideZ1 = offset | ((nextVal >> 8) & 0xf)
			result[i].sideX0 = offset | ((nextVal >> 12) & 0xf)
			i += 1
		} else {
			result[i].bottom = result[i].top
			result[i].sideX1 = result[i].sideZ0
			result[i].sideZ1 = result[i].sideZ0
			result[i].sideX0 = result[i].sideZ0
		}
	}

	result[1].top = 126 // Use texture 126 for water rendering on PC

	return result
}
