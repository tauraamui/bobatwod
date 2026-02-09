module main

import tauraamui.bobatea as tea

struct GameModel {
mut:
	app_send ?fn (tea.Msg)
	window_width int
	window_height int
	position Point
	z_height f64
}

fn (mut m GameModel) init() ?tea.Cmd {
	return tea.emit_resize
}

fn (mut m GameModel) update(msg tea.Msg) (tea.Model, ?tea.Cmd) {
	match msg {
		tea.KeyMsg {
			match msg.k_type {
				.special {
					if msg.string() == 'escape' {
						return m.clone(), tea.quit
					}
					match msg.string() {
						'escape' {
							return m.clone(), tea.quit
						}
						'enter' {
							m.z_height += .001
						}
						else {}
					}
				}
				.runes {
					if msg.string() == 'q' {
						return m.clone(), tea.quit
					}
					if msg.string() == 'x' {
						m.position = Point{ x: m.position.x + 1, y: m.position.y }
						return m.clone(), none
					}
				}
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

fn (m GameModel) view(mut ctx tea.Context) {
	ctx.set_bg_color(tea.Color{ 30, 30, 30 })
	ctx.draw_rect(0, 0, m.window_width, m.window_height)
	ctx.reset_bg_color()

	ctx.set_bg_color(tea.Color.ansi(255))
	point(mut ctx, screen(ctx.window_width(), ctx.window_height(), project(Point{x: .0, y: .0, z: 1})))
	ctx.reset_bg_color()
}

fn (m GameModel) clone() tea.Model {
	return GameModel{
		...m
	}
}

struct Point{
	x f64
	y f64
	z f64
}

fn point(mut ctx tea.Context, p Point) {
	ctx.draw_rect(int(p.x), int(p.y), 1, 1)
}

fn screen(width int, height int, p Point) Point {
	w := f64(width)
	h := f64(height)
	return Point{
		x: (p.x + 1) / 2 * w
		y: (1 - (p.y + 1) / 2) * h
	}
}

fn project(p Point) Point {
	return Point{
		x: p.x / p.z
		y: p.y / p.z
	}
}

fn main() {
	mut game_model := GameModel{}
	mut app := tea.new_program(mut game_model)
	game_model.app_send = app.send
	app.run() or { panic('something went wrong! ${err}') }
}

