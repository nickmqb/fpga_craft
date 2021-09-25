//tab_size=4
// Copyright 2021 nickmqb
// SPDX-License-Identifier: Apache-2.0

time(t *uint) uint #Foreign("time")

randomInt(rs *uint, from int, to int) {
	n := cast(Random.xorshift32(rs) % cast(to - from, uint), int)
	return n + from
}

randomFloat(rs *uint, from float, to float) {
	i := Random.xorshift32(rs)
	return from + (i / cast(uint.maxValue, float)) * (to - from)
}

randomUnitVector3(rs *uint) {
	angle := randomFloat(rs, 0, pi * 2)
	z := randomFloat(rs, -1, 1)
	f := sqrt(1 - z * z)
	return Vector3(cos(angle) * f, sin(angle) * f, z)
}

shuffle(data Array<T>, rs *uint) {
	for i := 0; i < data.count - 1 {
		j := randomInt(rs, 0, data.count - i) + i
		h := data[j]
		data[j] = data[i]
		data[i] = h
	}
}

smoothStep(t float) {
	return ((6 * t - 15) * t + 10) * t * t * t
}

easeS01(t float, f float) {
	x := t * 2 - 1
	sign := 1
	if x < 0 {
		x = -x
		sign = -1
	}
	return ((1 - pow(2, -f * x)) / (1 - pow(2, -f)) * sign) * .5 + .5
}

stretch(t float, f float) {
	return clamp(t / (f * .86), -1, 1)
}

sampleNoise(map GradientNoiseMap2D, x int, y int, size float, freq int) {
	step := freq / size
	return map.sample((x + .5) * step, (y + .5) * step, freq - 1, freq - 1)
}

sampleNoise01(map GradientNoiseMap2D, x int, y int, size float, freq int) {
	step := freq / size
	return map.sample((x + .5) * step, (y + .5) * step, freq - 1, freq - 1) * .5 + .5
}

sampleNoise3D(map GradientNoiseMap3D, x int, y int, z int, size float, freq int) {
	step := freq / size
	return map.sample((x + .5) * step, (y + .5) * step, (z + .5) * step, freq - 1, freq - 1, freq - 1)
}

sampleNoise3D_01(map GradientNoiseMap3D, x int, y int, z int, size float, freq int) {
	step := freq / size
	return map.sample((x + .5) * step, (y + .5) * step, (z + .5) * step, freq - 1, freq - 1, freq - 1) * .5 + .5
}

GradientNoiseMap2D struct #RefType {
	gradients Array<Vector2>
	hashTable Array<int>

	cons(rs *uint) {
		result := GradientNoiseMap2D {
			gradients: new Array<Vector2>(256),
			hashTable: new Array<int>(512)
		}
		for i := 0; i < 256 {
			result.gradients[i] = Vector2(cos(i / 256.0 * 2.0 * pi), sin(i / 256.0 * 2.0 * pi))
		}
		for i := 0; i < 256 {
			result.hashTable[i] = i
		}
		shuffle(ref result.hashTable.slice(0, 256), rs)
		for i := 0; i < 256 {
			result.hashTable[i + 256] = result.hashTable[i]
		}
		return result
	}

	sample(map GradientNoiseMap2D, x float, y float, xMask int, yMask int) {
		ix0 := cast(floor(x), int) & xMask
		iy0 := cast(floor(y), int) & yMask
		ix1 := (cast(floor(x), int) + 1) & xMask
		iy1 := (cast(floor(y), int) + 1) & yMask
		fx := frac(x)
		fy := frac(y)
		h00 := map.hashTable[map.hashTable[iy0] + ix0]
		h01 := map.hashTable[map.hashTable[iy0] + ix1]
		h10 := map.hashTable[map.hashTable[iy1] + ix0]
		h11 := map.hashTable[map.hashTable[iy1] + ix1]
		u := smoothStep(fx)
		v := smoothStep(fy)
		a := map.gradients[h00].dot(Vector2(fx, fy)) * (1 - u) + map.gradients[h01].dot(Vector2(fx - 1, fy)) * u
		b := map.gradients[h10].dot(Vector2(fx, fy - 1)) * (1 - u) + map.gradients[h11].dot(Vector2(fx - 1, fy - 1)) * u
		return a * (1 - v) + b * v
	}
}

GradientNoiseMap3D struct #RefType {
	gradients Array<Vector3>
	hashTable Array<int>

	cons(rs *uint) {
		result := GradientNoiseMap3D {
			gradients: new Array<Vector3>(16),
			hashTable: new Array<int>(512)
		}
		result.gradients[0] = Vector3(1, 1, 0)
		result.gradients[1] = Vector3(-1, 1, 0)
		result.gradients[2] = Vector3(1, -1, 0)
		result.gradients[3] = Vector3(-1, -1, 0)
		result.gradients[4] = Vector3(1, 0, 1)
		result.gradients[5] = Vector3(-1, 0, 1)
		result.gradients[6] = Vector3(1, 0, -1)
		result.gradients[7] = Vector3(-1, 0, -1)
		result.gradients[8] = Vector3(0, 1, 1)
		result.gradients[9] = Vector3(0, -1, 1)
		result.gradients[10] = Vector3(0, 1, -1)
		result.gradients[11] = Vector3(0, -1, -1)
		result.gradients[12] = Vector3(1, 1, 0)
		result.gradients[13] = Vector3(-1, 1, 0)
		result.gradients[14] = Vector3(0, -1, 1)
		result.gradients[15] = Vector3(0, -1, -1)
		for i := 0; i < 256 {
			result.hashTable[i] = i
		}
		shuffle(ref result.hashTable.slice(0, 256), rs)
		for i := 0; i < 256 {
			result.hashTable[i + 256] = result.hashTable[i]
		}
		return result
	}

	sample(map GradientNoiseMap3D, x float, y float, z float, xMask int, yMask int, zMask int) {
		ix0 := cast(floor(x), int) & xMask
		iy0 := cast(floor(y), int) & yMask
		iz0 := cast(floor(z), int) & zMask
		ix1 := (cast(floor(x), int) + 1) & xMask
		iy1 := (cast(floor(y), int) + 1) & yMask
		iz1 := (cast(floor(z), int) + 1) & zMask
		fx := frac(x)
		fy := frac(y)
		fz := frac(z)
		h000 := map.hashTable[map.hashTable[map.hashTable[iz0] + iy0] + ix0] & 0xf
		h001 := map.hashTable[map.hashTable[map.hashTable[iz0] + iy0] + ix1] & 0xf
		h010 := map.hashTable[map.hashTable[map.hashTable[iz0] + iy1] + ix0] & 0xf
		h011 := map.hashTable[map.hashTable[map.hashTable[iz0] + iy1] + ix1] & 0xf
		h100 := map.hashTable[map.hashTable[map.hashTable[iz1] + iy0] + ix0] & 0xf
		h101 := map.hashTable[map.hashTable[map.hashTable[iz1] + iy0] + ix1] & 0xf
		h110 := map.hashTable[map.hashTable[map.hashTable[iz1] + iy1] + ix0] & 0xf
		h111 := map.hashTable[map.hashTable[map.hashTable[iz1] + iy1] + ix1] & 0xf
		u := smoothStep(fx)
		v := smoothStep(fy)
		w := smoothStep(fz)
		a := map.gradients[h000].dot(Vector3(fx, fy, fz)) * (1 - u) + map.gradients[h001].dot(Vector3(fx - 1, fy, fz)) * u
		b := map.gradients[h010].dot(Vector3(fx, fy - 1, fz)) * (1 - u) + map.gradients[h011].dot(Vector3(fx - 1, fy - 1, fz)) * u
		c := map.gradients[h100].dot(Vector3(fx, fy, fz - 1)) * (1 - u) + map.gradients[h101].dot(Vector3(fx - 1, fy, fz - 1)) * u
		d := map.gradients[h110].dot(Vector3(fx, fy - 1, fz - 1)) * (1 - u) + map.gradients[h111].dot(Vector3(fx - 1, fy - 1, fz - 1)) * u
		e := a * (1 - v) + b * v
		f := c * (1 - v) + d * v
		return e * (1 - w) + f * w
	}
}
