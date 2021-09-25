// Copyright 2021 nickmqb
// SPDX-License-Identifier: Apache-2.0

#version 330 core

uniform sampler2DArray sampler;

in vec3 fs_tex;
in float fs_light;
in float fs_discard;

out vec4 color;

void main() {
	if (fs_discard > 0) {
		discard;
	}
	color = vec4(texture(sampler, fs_tex).rgba * fs_light);
}
