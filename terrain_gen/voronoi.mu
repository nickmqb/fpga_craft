//tab_size=4
// Copyright 2021 nickmqb
// SPDX-License-Identifier: Apache-2.0

VoronoiGrid2D struct #RefType {
	size IntVector2
	tiles Array<VoronoiTile>
	points Array<IntVector2>

	fromNumPoints(width int, height int, numPoints int, rs *uint) {
		points := new Array<IntVector2>(numPoints + 1)
		for i := 0; i < numPoints {
			points[i + 1] = IntVector2(randomInt(rs, 0, width), randomInt(rs, 0, height))
		}
		return fromPoints(width, height, points)
	}

	fromPoints(width int, height int, points Array<IntVector2>) {
		vg := new VoronoiGrid2D {
			size: IntVector2(width, height),
			tiles: new Array<VoronoiTile>(width * height),
			points: points,
		}
		for y := 0; y < height {
			for x := 0; x < width {
				ci := y * width + x
				f1 := 0.0
				f2 := 0.0
				f3 := 0.0
				closest1 := getClosest(vg, x, y, 0, 0)
				closest2 := getClosest(vg, x, y, closest1.id, 0)
				closest3 := getClosest(vg, x, y, closest1.id, closest2.id)
				vg.tiles[ci] = VoronoiTile { closest1: closest1, closest2: closest2, closest3: closest3 }
			}
		}
		return vg
	}

	getCentroids(vg VoronoiGrid2D) {
		centroids := new Array<IntVector2>(vg.points.count)
		cellCount := new Array<int>(vg.points.count)
		for y := 0; y < vg.size.y {
			for x := 0; x < vg.size.x {
				ci := y * vg.size.x + x
				id := vg.tiles[ci].closest1.id
				centroids[id] = IntVector2.add(centroids[id], IntVector2(x, y))
				cellCount[id] += 1
			}
		}
		for i := 1; i < vg.points.count {
			count := cellCount[i]
			centroids[i] = count > 0 ? IntVector2(centroids[i].x / count, centroids[i].y / count) : vg.points[i]
		}
		return centroids
	}

	getClosest(vg VoronoiGrid2D, x int, y int, exceptA int, exceptB int) {
		best := 0
		bestDistSq := int.maxValue
		hsx := vg.size.x / 2
		hsy := vg.size.y / 2
		for i := 1; i < vg.points.count {
			if i == exceptA || i == exceptB {
				continue
			}
			p := vg.points[i]
			dx := p.x - x
			if dx < -hsx {
				dx += vg.size.x
			}
			if dx >= hsx {
				dx -= vg.size.x
			}
			dy := p.y - y
			if dy < -hsy {
				dy += vg.size.y
			}
			if dy >= hsy {
				dy -= vg.size.y
			}
			distSq := dx * dx + dy * dy
			if distSq < bestDistSq {
				best = i
				bestDistSq = distSq
			}
		}
		assert(best > 0)
		return VoronoiNeighborInfo { id: best, dist: sqrt(bestDistSq) }
	}
}

VoronoiTile struct {
	closest1 VoronoiNeighborInfo
	closest2 VoronoiNeighborInfo
	closest3 VoronoiNeighborInfo
}

VoronoiNeighborInfo struct {
	id int
	dist float
}
