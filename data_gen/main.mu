//tab_size=4
// Copyright 2021 nickmqb
// SPDX-License-Identifier: Apache-2.0

main() {
	::currentAllocator = Memory.newArenaAllocator(checked_cast(uint.maxValue, ssize))

	images := loadImages()
	blockInfos := initBlockInfos()
	blockTextureInfos := getBlockTextureInfos(blockInfos)
	
	generateData(images, blockInfos, blockTextureInfos)
}
