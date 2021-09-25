//tab_size=4
// Copyright 2021 nickmqb
// SPDX-License-Identifier: Apache-2.0

Image struct {
	width int
	height int
	data pointer
	array $Array<ByteColor4>

	cons(width int, height int) {
		img := Image { 
			width: width, 
			height: height,
			array: Array<ByteColor4>(width * height),
		}
		img.data = img.array.dataPtr
		return img
	}

	fromDataPtr(width int, height int, dataPtr pointer) {
		return Image {
			width: width,
			height: height,
			data: dataPtr,
			array: Array<ByteColor4> { dataPtr: dataPtr, count: width * height }
		}
	}

	fromColor(width int, height int, color ByteColor4) {
		image := Image(width, height)
		for i := 0; i < image.array.count {
			image.array[i] = color
		}
		return image
	}

	getPixel(img *Image, x int, y int) {
		return img.array[y * img.width + x]
	}

	getIndex(img *Image, x int, y int) {
		return y * img.width + x
	}

	drawImage(target *Image, source *Image, tx int, ty int) {
		assert(0 <= tx && tx + source.width <= target.width)
		assert(0 <= ty && ty + source.height <= target.height)
		tp := transmute(target.data, usize)
		sp := transmute(source.data, usize)
		tstride := checked_cast(target.width * 4, uint)
		sstride := checked_cast(source.width * 4, uint)
		for y := 0; y < source.height {
			from := sp + cast(y, uint) * sstride
			to := tp + cast(ty + y, uint) * tstride + cast(tx, uint) * 4_u
			Memory.memcpy(transmute(to, pointer), transmute(from, pointer), sstride)
		}
	}

	add(img *Image, overlay *Image) {
		result := new Image(img.width, img.height)
		for i := 0; i < img.array.count {
			result.array[i] = ByteColor4.lerp(img.array[i], overlay.array[i], ByteColor4.byteComponentToFloat(overlay.array[i].a))
		}
		return result
	}

	mulColor(img *Image, c ByteColor4) {
		result := new Image(img.width, img.height)
		for i := 0; i < img.array.count {
			result.array[i] = img.array[i].mul(c)
		}
		return result
	}

	cropHeight(img *Image, height int) {
		assert(img.height >= height)
		result := new Image(img.width, height)
		for i := 0; i < result.array.count {
			result.array[i] = img.array[i]
		}
		return result
	}

	subImage(img *Image, px int, py int, width int, height int) {
		result := new Image(width, height)
		i := 0
		for y := 0; y < height {
			for x := 0; x < width {
				result.array[i] = img.getPixel(px + x, py + y)
				i += 1
			}
		}
		return result
	}

	toLinear(img *Image) {
		result := new Image(img.width, img.height)
		for i := 0; i < img.array.count {
			result.array[i] = img.array[i].toLinear()
		}
		return result
	}

	extractOverlay(img *Image, threshold int) {
		for c, i in img.array {
			if c.r > threshold && c.g > threshold && c.b > threshold {
				// OK
			} else {
				img.array[i] = ByteColor4{} // Transparent
			}
		}
		return img
	}
}

ByteColor4 struct {
	r byte
	g byte
	b byte
	a byte

	cons(r byte, g byte, b byte, a byte) {
		return ByteColor4 { r: r, g: g, b: b, a: a }
	}

	rgb(r byte, g byte, b byte) {
		return ByteColor4 { r: r, g: g, b: b, a: 255 }
	}

	rgbaf(r float, g float, b float, a float) {
		return ByteColor4(floatComponentToByte(r), floatComponentToByte(g), floatComponentToByte(b), floatComponentToByte(a))
	}

	mul(a ByteColor4, b ByteColor4) {
		return ByteColor4.rgbaf(
			byteComponentToFloat(a.r) * byteComponentToFloat(b.r),
			byteComponentToFloat(a.g) * byteComponentToFloat(b.g),
			byteComponentToFloat(a.b) * byteComponentToFloat(b.b),
			byteComponentToFloat(a.a) * byteComponentToFloat(b.a))
	}

	mulf(b ByteColor4, f float) {
		return rgbaf(byteComponentToFloat(b.r) * f, byteComponentToFloat(b.g) * f, byteComponentToFloat(b.b) * f, byteComponentToFloat(b.a) * f)
	}

	lerp(a ByteColor4, b ByteColor4, t float) {
		return ByteColor4.rgbaf(
			byteComponentToFloat(a.r) * (1 - t) + byteComponentToFloat(b.r) * t,
			byteComponentToFloat(a.g) * (1 - t) + byteComponentToFloat(b.g) * t,
			byteComponentToFloat(a.b) * (1 - t) + byteComponentToFloat(b.b) * t,
			byteComponentToFloat(a.a) * (1 - t) + byteComponentToFloat(b.a) * t)
	}

	powRgb(b ByteColor4, f float) {
		return rgbaf(::pow(byteComponentToFloat(b.r), f), ::pow(byteComponentToFloat(b.g), f), ::pow(byteComponentToFloat(b.b), f), byteComponentToFloat(b.a))
	}

	toLinear(b ByteColor4) {
		return powRgb(b, 2.2)
	}

	toSRGB(b ByteColor4) {
		return powRgb(b, 1 / 2.2)
	}

	floatComponentToByte(f float) {
		n := cast(f * 255.0 + .5, int)
		if n <= 0 {
			return 0_b
		} else if n >= 255 {
			return 255_b
		}
		return cast(n, byte)
	}

	byteComponentToFloat(b byte) {
		return b / 255.0
	}

	hash(c ByteColor4) {
		return transmute(c, uint)
	}

	equals(a ByteColor4, b ByteColor4) {
		return transmute(a, uint) == transmute(b, uint)
	}
}

loadPng(filename cstring) {
	x := 0
	y := 0
	channels := 0
	data := stbi_load(filename, ref x, ref y, ref channels, 4)
	if data == null {
		Stderr.writeLine(format("Could not read: {}", filename))
		abandon()
	}
	return Image.fromDataPtr(x, y,pointer_cast(data, pointer))
}

loadTexture_checked(filename cstring) {
	img := new loadPng(filename)
	if img.width != 16 || img.height < 16 {
		Stderr.writeLine(format("Invalid image size: {}, expected 16x16", filename))
		abandon()
	}
	if img.height > 16 {
		img = img.cropHeight(16)
	}
	img = removeTransparentPixels(img)
	return img
}

loadAnimatedTexture_checked(filename cstring) {
	img := new loadPng(filename)
	if img.width != 16 || img.height < 16 || img.height > 512 || (img.height % 16) != 0 {
		Stderr.writeLine(format("Invalid image size: {}, expected 16x(16..512)", filename))
		abandon()
	}
	return img
}

hexToColor(s string) {
	assert(s.length == 6)
	return ByteColor4.rgb(
		cast(ulong.tryParseHex(s.slice(0, 2)).unwrap(), byte),
		cast(ulong.tryParseHex(s.slice(2, 4)).unwrap(), byte),
		cast(ulong.tryParseHex(s.slice(4, 6)).unwrap(), byte))
}

quantizeByteComponent(x byte) {
	q := cast(x / 255.0 * 15.0 + .5, int)
	return ByteColor4.floatComponentToByte(q / 15.0)
}

quantizeByteComponentAsU4(x byte) {
	return clampi(cast(x / 255.0 * 15.0 + .5, int), 0, 15)
}

quantizeColor(c ByteColor4) {
	return ByteColor4(quantizeByteComponent(c.r), quantizeByteComponent(c.g), quantizeByteComponent(c.b), quantizeByteComponent(c.a))
}

quantizeColorUsingPalette(c ByteColor4, palette Array<ByteColor4>, index *int) {
	best := -1
	bestDist := int.maxValue
	for pc, i in palette {
		dr := pc.r - c.r
		dg := pc.g - c.g
		db := pc.b - c.b
		dist := dr * dr + dg * dg + db * db
		if dist < bestDist {
			best = i
			bestDist = dist
		}
	}
	index^ = best
	return palette[best]
}

quantizeImage(img *Image) {
	result := new Image(img.width, img.height)
	for c, i in img.array {
		result.array[i] = quantizeColor(c)
	}
	return result
}

removeTransparentPixels(img *Image) {
	result := new Image(img.width, img.height)
	for c, i in img.array {
		result.array[i] = c.a < 32 ? ByteColor4 { a: c.a } : c
	}
	return result
}

rotateImageClockwise(img *Image) {
	result := new Image(img.height, img.width)
	for y := 0; y < img.height {
		for x := 0; x < img.width {
			c := img.getPixel(x, y)
			result.array[img.getIndex(img.height - 1 - y, x)] = c
		}
	}
	return result
}

invCompareByteColor4Count(a MapEntry<ByteColor4, int>, b MapEntry<ByteColor4, int>) {
	return b.value.compare(a.value)
}

reduceImageColors(img *Image, maxEntries int) {
	count := new Map.create<ByteColor4, int>()
	for c in img.array {
		c = quantizeColor(c)
		pair := count.maybeGet(c)
		count.addOrUpdate(c, pair.value + 1)
	}
	entries := new List<MapEntry<ByteColor4, int>>{}
	for e in count {
		entries.add(e)
	}
	entries.stableSort(invCompareByteColor4Count)

	palette := new Array<ByteColor4>(min(entries.count, maxEntries))
	for i := 0; i < palette.count {
		palette[i] = entries[i].key
	}

	result := new Image(img.width, img.height)
	bytes := new Array<byte>(img.width * img.height)
	index := 0
	for c, i in img.array {
		result.array[i] = quantizeColorUsingPalette(c, palette, ref index)
		bytes[i] = cast(index, byte)
	}
	
	return ReduceImageColorsResult { image: result, palette: palette, bytes: bytes }
}

ReduceImageColorsResult struct {
	image *Image
	palette Array<ByteColor4>
	bytes Array<byte>
}

repeatImageTiles(img *Image, targetHeight int) {
	assert(img.height % 16 == 0)
	copies := (targetHeight + img.height - 1) / img.height
	result := new Image(img.width, copies * img.height)
	num := img.height / 16
	for i := 0; i < num {
		for j := 0; j < copies {
			result.drawImage(img.subImage(0, i * 16, img.width, 16), 0, (i * copies + j) * 16)
		}
	}
	return result
}
