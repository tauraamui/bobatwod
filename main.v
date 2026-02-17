module main

import os
import time
import math
import tauraamui.bobatea as tea

// =========================
// Data Types
// =========================

struct Point {
mut:
	x f64
	y f64
	z f64
}

struct Mesh {
mut:
	vertices []Point
	faces    [][]int
}

struct GameModel {
mut:
	mesh Mesh

	window_width  int
	window_height int

	delta_z f64 = 3.0
	angle   f64

	frame_label f64
	frame_count int
	last_fps_update time.Time = time.now()
}

// =========================
// OBJ LOADER
// =========================

fn load_obj(path string) !Mesh {
	mut vertices := []Point{}
	mut faces := [][]int{}

	lines := os.read_lines(path)!

	for line in lines {
		if line.len == 0 { continue }

		if line.starts_with('v ') {
			parts := line.split_by_space()
			if parts.len < 4 { continue }

			vertices << Point{
				x: parts[1].f64()
				y: parts[2].f64()
				z: parts[3].f64()
			}
		}

		if line.starts_with('f ') {
			parts := line.split_by_space()[1..]
			mut face := []int{}

			for p in parts {
				vertex_index := p.split('/')[0].int() - 1
				face << vertex_index
			}

			if face.len >= 3 {
				faces << face
			}
		}
	}

	mut mesh := Mesh{
		vertices: vertices
		faces: faces
	}

	mesh.normalize()

	return mesh
}

// =========================
// Mesh Normalization
// =========================

fn (mut m Mesh) normalize() {
	if m.vertices.len == 0 { return }

	mut min_x := m.vertices[0].x
	mut max_x := m.vertices[0].x
	mut min_y := m.vertices[0].y
	mut max_y := m.vertices[0].y
	mut min_z := m.vertices[0].z
	mut max_z := m.vertices[0].z

	for v in m.vertices {
		if v.x < min_x { min_x = v.x }
		if v.x > max_x { max_x = v.x }
		if v.y < min_y { min_y = v.y }
		if v.y > max_y { max_y = v.y }
		if v.z < min_z { min_z = v.z }
		if v.z > max_z { max_z = v.z }
	}

	center_x := (min_x + max_x) / 2
	center_y := (min_y + max_y) / 2
	center_z := (min_z + max_z) / 2

	size_x := max_x - min_x
	size_y := max_y - min_y
	size_z := max_z - min_z

	max_dim := math.max(size_x, math.max(size_y, size_z))

	for i in 0 .. m.vertices.len {
		m.vertices[i].x = (m.vertices[i].x - center_x) / max_dim * 2
		m.vertices[i].y = (m.vertices[i].y - center_y) / max_dim * 2
		m.vertices[i].z = (m.vertices[i].z - center_z) / max_dim * 2
	}
}

// =========================
// Transformations
// =========================

fn translate_z(p Point, delta_z f64) Point {
	return Point{
		x: p.x
		y: p.y
		z: p.z + delta_z
	}
}

fn rotate_xz(p Point, angle f64) Point {
	c := math.cos(angle)
	s := math.sin(angle)

	return Point{
		x: (p.x * c) - (p.z * s)
		y: p.y
		z: (p.x * s) + (p.z * c)
	}
}

fn project(p Point) Point {
	return Point{
		x: p.x / p.z
		y: p.y / p.z
	}
}

fn screen(width int, height int, p Point) Point {
	w := f64(width)
	h := f64(height)

	return Point{
		x: (p.x + 1) / 2 * w
		y: (1 - (p.y + 1) / 2) * h
	}
}

// =========================
// Drawing Helpers
// =========================

fn line(mut ctx tea.Context, p1 Point, p2 Point) {
	ctx.draw_line(int(p1.x), int(p1.y), int(p2.x), int(p2.y), false)
}

// =========================
// BubbleTea Methods
// =========================

fn (mut m GameModel) init() ?tea.Cmd {
	return tea.emit_resize
}

fn (mut m GameModel) update(msg tea.Msg) (tea.Model, ?tea.Cmd) {
	match msg {
		tea.KeyMsg {
			if msg.string() == 'escape' || msg.string() == 'q' {
				return m.clone(), tea.quit
			}
		}
		tea.ResizedMsg {
			m.window_width = msg.window_width
			m.window_height = msg.window_height
		}
		else {}
	}
	return m.clone(), none
}

fn (mut m GameModel) view(mut ctx tea.Context) {
	m.angle += math.pi * 0.01

	ctx.set_bg_color(tea.Color{30, 30, 30})
	ctx.draw_rect(0, 0, m.window_width, m.window_height)
	ctx.reset_bg_color()

	ctx.set_color(tea.Color{g: 200})
	ctx.set_stroke('▄')
	defer { ctx.set_stroke(` `.str()) }

	for f in m.mesh.faces {
		for i in 0 .. f.len {
			a := m.mesh.vertices[f[i]]
			b := m.mesh.vertices[f[(i + 1) % f.len]]

			line(
				mut ctx,
				screen(
					m.window_width,
					m.window_height,
					project(translate_z(rotate_xz(a, m.angle), m.delta_z))
				),
				screen(
					m.window_width,
					m.window_height,
					project(translate_z(rotate_xz(b, m.angle), m.delta_z))
				)
			)
		}
	}

	ctx.reset_color()

	// FPS counter
	if time.now() - m.last_fps_update >= (1 * time.second) {
		m.frame_label = 1000.0 / f64(m.frame_count)
		m.frame_count = 0
		m.last_fps_update = time.now()
	}
	m.frame_count += 1

	ctx.set_color(tea.Color.ansi(255))
	ctx.draw_text(1, 1, "ms/frame: ${m.frame_label:.2f}")
}

fn (m GameModel) clone() tea.Model {
	return GameModel{
		...m
	}
}

// =========================
// Entry
// =========================

fn main() {
	mut mesh := load_obj('model.obj') or {
		panic(err)
	}

	mut game_model := GameModel{
		mesh: mesh
	}

	mut app := tea.new_program(mut game_model)
	app.run() or { panic('something went wrong! ${err}') }
}
