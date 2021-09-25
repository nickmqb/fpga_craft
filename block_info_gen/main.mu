//tab_size=4
// Copyright 2021 nickmqb
// SPDX-License-Identifier: Apache-2.0

BlockInfo struct {
	textureBits int
	infoBits int // Bits: 0-6: texture; 7: truncate_last_2_bits_on_pickup; 8: rotate; 9: rotate3; 10: truncate_last_4_bits_on_pickup; 11: is_gravity_block; 12: is_door
}

main() {
	::currentAllocator = Memory.newArenaAllocator(16 * 1024 * 1024)
	generate()
}
